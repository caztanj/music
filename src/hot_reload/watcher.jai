file_watcher_initialize :: (watcher: *File_Watcher, file_path: string, callback: File_Changed_Callback, user_data: *void = null, polling_interval_in_milliseconds: int = 25, debounce_delay_in_milliseconds: int = 75) -> bool {
    watcher.file_path = file_path;
    watcher.callback = callback;
    watcher.user_data = user_data;
    watcher.polling_interval_in_milliseconds = polling_interval_in_milliseconds;
    watcher.debounce_delay_in_milliseconds = debounce_delay_in_milliseconds;
    watcher.is_running = false;

    modification_time, file_size, file_exists := get_file_modification_time_and_size(file_path);
    watcher.last_known_modification_time = modification_time;
    watcher.last_known_file_size = file_size;
    watcher.last_known_file_exists = file_exists;

    return true;
}

file_watcher_start :: (watcher: *File_Watcher) -> bool {
    if watcher.is_running {
        return true;
    }

    watcher.is_running = true;
    thread_init(*watcher.watcher_thread, file_watcher_thread_procedure);
    watcher.watcher_thread.data = watcher;
    thread_start(*watcher.watcher_thread);

    return true;
}

file_watcher_stop :: (watcher: *File_Watcher) -> bool {
    if !watcher.is_running {
        return true;
    }

    watcher.is_running = false;
    thread_is_done(*watcher.watcher_thread, 2000);
    thread_deinit(*watcher.watcher_thread);

    return true;
}

file_watcher_shutdown :: (watcher: *File_Watcher) {
    if watcher.is_running {
        file_watcher_stop(watcher);
    }
}

file_watcher_poll_and_debounce :: (watcher: *File_Watcher) -> bool {
    current_modification_time, current_file_size, current_file_exists := get_file_modification_time_and_size(watcher.file_path);

    if !current_file_exists && !watcher.last_known_file_exists {
        return false;
    }

    has_changed := (current_modification_time != watcher.last_known_modification_time) ||
                   (current_file_size != watcher.last_known_file_size) ||
                   (current_file_exists != watcher.last_known_file_exists);

    if !has_changed {
        return false;
    }

    latest_modification_time := current_modification_time;
    latest_file_size := current_file_size;
    latest_file_exists := current_file_exists;

    elapsed_quiet_time_in_milliseconds := 0;
    debounce_step_in_milliseconds := 10;

    while watcher.is_running && elapsed_quiet_time_in_milliseconds < watcher.debounce_delay_in_milliseconds {
        sleep_milliseconds(cast(s32) debounce_step_in_milliseconds);
        elapsed_quiet_time_in_milliseconds += debounce_step_in_milliseconds;

        new_modification_time, new_file_size, new_file_exists := get_file_modification_time_and_size(watcher.file_path);

        subsequent_change := (new_modification_time != latest_modification_time) ||
                             (new_file_size != latest_file_size) ||
                             (new_file_exists != latest_file_exists);

        if subsequent_change {
            latest_modification_time = new_modification_time;
            latest_file_size = new_file_size;
            latest_file_exists = new_file_exists;
            elapsed_quiet_time_in_milliseconds = 0;
        }
    }

    if !watcher.is_running {
        return false;
    }

    watcher.last_known_modification_time = latest_modification_time;
    watcher.last_known_file_size = latest_file_size;
    watcher.last_known_file_exists = latest_file_exists;

    return latest_file_exists;
}

file_watcher_check_for_changes :: (watcher: *File_Watcher) -> bool {
    current_modification_time, current_file_size, current_file_exists := get_file_modification_time_and_size(watcher.file_path);

    has_changed := (current_modification_time != watcher.last_known_modification_time) ||
                   (current_file_size != watcher.last_known_file_size) ||
                   (current_file_exists != watcher.last_known_file_exists);

    if has_changed {
        watcher.last_known_modification_time = current_modification_time;
        watcher.last_known_file_size = current_file_size;
        watcher.last_known_file_exists = current_file_exists;

        return current_file_exists;
    }

    return false;
}

file_watcher_thread_procedure :: (thread: *Thread) -> s64 {
    watcher := cast(*File_Watcher) thread.data;

    while watcher.is_running {
        has_changed := file_watcher_poll_and_debounce(watcher);
        if has_changed && watcher.is_running && watcher.callback != null {
            watcher.callback(watcher.file_path, watcher.user_data);
        }

        sleep_milliseconds(cast(s32) watcher.polling_interval_in_milliseconds);
    }

    return 0;
}

get_file_modification_time_and_size :: (file_path: string) -> (modification_time: u64, file_size: u64, file_exists: bool) {
    if file_path.count == 0 {
        return 0, 0, false;
    }

    #if OS == .WINDOWS {
        wide_buffer: [1024] u16;
        converted_character_count := MultiByteToWideChar(
            65001,
            0,
            file_path.data,
            cast(s32) file_path.count,
            wide_buffer.data,
            1023
        );

        if converted_character_count <= 0 {
            return 0, 0, false;
        }

        wide_buffer[converted_character_count] = 0;

        attribute_data: Win32_File_Attribute_Data;
        success := GetFileAttributesExW(wide_buffer.data, 0, *attribute_data);

        if !success {
            return 0, 0, false;
        }

        modification_time := attribute_data.last_write_time.QuadPart;
        file_size := (cast(u64) attribute_data.file_size_high << 32) | cast(u64) attribute_data.file_size_low;

        return modification_time, file_size, true;
    } else {
        return 0, 0, false;
    }
}

hot_reloader_initialize :: (hot_reloader: *Hot_Reloader, file_path: string, sample_rate: s64 = DEFAULT_SAMPLE_RATE) -> bool {
    hot_reloader.file_path = file_path;
    hot_reloader.sample_rate = sample_rate;
    hot_reloader.active_slot_index = 0;
    hot_reloader.reload_count = 0;
    hot_reloader.has_error = false;
    hot_reloader.last_error_message = "";

    initial_specification, parse_success, error_message := parse_song_from_file(file_path, check_samples_on_disk = false);
    if !parse_success {
        hot_reloader.has_error = true;
        hot_reloader.last_error_message = error_message;

        return false;
    }

    initial_slot := *hot_reloader.state_slots[0];
    initial_slot.specification = initial_specification;
    initialize_sample_pool(*initial_slot.sample_pool);
    load_samples_for_song(*initial_slot.sample_pool, *initial_slot.specification);
    initial_slot.is_valid = true;
    initial_slot.version = 1;

    hot_reloader.active_state_pointer = initial_slot;

    watcher_success := file_watcher_initialize(*hot_reloader.watcher, file_path, hot_reloader_file_changed_callback, hot_reloader);

    return watcher_success;
}

hot_reloader_start :: (hot_reloader: *Hot_Reloader) -> bool {
    return file_watcher_start(*hot_reloader.watcher);
}

hot_reloader_stop :: (hot_reloader: *Hot_Reloader) -> bool {
    return file_watcher_stop(*hot_reloader.watcher);
}

hot_reloader_shutdown :: (hot_reloader: *Hot_Reloader) {
    file_watcher_shutdown(*hot_reloader.watcher);
}

hot_reloader_file_changed_callback :: (file_path: string, user_data: *void) {
    hot_reloader := cast(*Hot_Reloader) user_data;
    hot_reloader_reload_file(hot_reloader);
}

hot_reloader_reload_file :: (hot_reloader: *Hot_Reloader) -> bool {
    new_specification, parse_success, error_message := parse_song_from_file(hot_reloader.file_path, check_samples_on_disk = false);
    if !parse_success {
        hot_reloader.has_error = true;
        hot_reloader.last_error_message = error_message;
        print("Hot reload error: %\n", error_message);

        return false;
    }

    candidate_index := 1 - hot_reloader.active_slot_index;
    candidate_slot := *hot_reloader.state_slots[candidate_index];
    candidate_slot.specification = new_specification;
    initialize_sample_pool(*candidate_slot.sample_pool);
    load_samples_for_song(*candidate_slot.sample_pool, *candidate_slot.specification);
    candidate_slot.is_valid = true;

    current_active := cast(*Song_State) atomic_read(*hot_reloader.active_state_pointer);
    candidate_slot.version = ifx current_active then current_active.version + 1 else 1;

    atomic_swap(*hot_reloader.active_state_pointer, candidate_slot);
    hot_reloader.active_slot_index = candidate_index;
    hot_reloader.has_error = false;
    hot_reloader.last_error_message = "";
    hot_reloader.reload_count += 1;

    return true;
}

hot_reloader_apply_state_to_engine :: (state: *Song_State, sequencer: *Sequencer, mixer: *Mixer) {
    sequencer.clock.beats_per_minute = state.specification.project.beats_per_minute;
    sequencer.clock.total_bars = state.specification.project.total_bars;
    sequencer.clock.time_signature_numerator = state.specification.project.time_signature_numerator;
    sequencer.clock.time_signature_denominator = state.specification.project.time_signature_denominator;

    total_clock_samples := calculate_total_clock_samples(*sequencer.clock);
    if total_clock_samples > 0 && sequencer.clock.current_sample >= total_clock_samples {
        sequencer.clock.current_sample = sequencer.clock.current_sample % total_clock_samples;
    }

    sequencer.sample_pool = state.sample_pool;

    track_index := 0;
    while track_index < state.specification.mixer.tracks.count {
        track_definition := *state.specification.mixer.tracks[track_index];
        channel, channel_found := find_mixer_channel(mixer, track_definition.track_index);
        if channel_found {
            channel.name = track_definition.name;
            channel.gain = track_definition.gain;
            channel.pan = track_definition.pan;
            channel.output_target = track_definition.output_target;

            if track_definition.delay_time_seconds > 0.0 {
                channel.delay_enabled = true;
                configure_stereo_delay(
                    *channel.stereo_delay,
                    track_definition.delay_time_seconds,
                    track_definition.delay_feedback,
                    wet_level = 0.5,
                    dry_level = 1.0
                );
            } else {
                channel.delay_enabled = false;
            }
        }

        track_index += 1;
    }

    mixer.master.gain = state.specification.mixer.master.gain;
}

render_audio_block_with_hot_reload :: (
    hot_reloader: *Hot_Reloader,
    sequencer: *Sequencer,
    voice_manager: *Voice_Manager,
    mixer: *Mixer,
    output_buffer: [] float,
    frame_count: s64,
    last_applied_version: *u64
) {
    active_state := cast(*Song_State) atomic_read(*hot_reloader.active_state_pointer);
    if active_state != null && active_state.is_valid {
        if last_applied_version.* != active_state.version {
            hot_reloader_apply_state_to_engine(active_state, sequencer, mixer);
            last_applied_version.* = active_state.version;
        }

        render_sequencer_block(
            sequencer,
            *active_state.specification,
            voice_manager,
            mixer,
            output_buffer,
            frame_count
        );
    } else {
        sample_index := 0;
        total_samples := frame_count * 2;
        while sample_index < total_samples && sample_index < output_buffer.count {
            output_buffer[sample_index] = 0.0;
            sample_index += 1;
        }
    }
}

File_Changed_Callback :: #type (file_path: string, user_data: *void);

File_Watcher :: struct {
    file_path: string;
    callback: File_Changed_Callback;
    user_data: *void;
    is_running: bool;
    watcher_thread: Thread;
    polling_interval_in_milliseconds: int = 25;
    debounce_delay_in_milliseconds: int = 75;
    last_known_modification_time: u64;
    last_known_file_size: u64;
    last_known_file_exists: bool;
}

Song_State :: struct {
    specification: Song_Specification;
    sample_pool: Sample_Pool;
    is_valid: bool = false;
    version: u64 = 0;
}

Hot_Reloader :: struct {
    watcher: File_Watcher;
    file_path: string;
    sample_rate: s64 = DEFAULT_SAMPLE_RATE;
    state_slots: [2] Song_State;
    active_slot_index: s64 = 0;
    active_state_pointer: *Song_State = null;
    reload_count: s64 = 0;
    last_error_message: string;
    has_error: bool = false;
}

#if OS == .WINDOWS {
    Win32_File_Attribute_Data :: struct {
        file_attributes: u32;
        creation_time: FILETIME;
        last_access_time: FILETIME;
        last_write_time: FILETIME;
        file_size_high: u32;
        file_size_low: u32;
    }

    GetFileAttributesExW :: (filename: *u16, info_level_id: s32, file_information: *void) -> BOOL #foreign kernel32;
}
