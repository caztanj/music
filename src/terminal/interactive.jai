map_character_to_playback_command :: (character: s32) -> Playback_Control_Command {
    if character == {
        case 32;
            return .TOGGLE_PLAY_PAUSE;

        case 82;
            return .REWIND;

        case 114;
            return .REWIND;

        case 77;
            return .TOGGLE_MIXER_VIEW;

        case 109;
            return .TOGGLE_MIXER_VIEW;

        case 81;
            return .QUIT;

        case 113;
            return .QUIT;

        case 27;
            return .QUIT;

        case;
            return .NONE;
    }

    return .NONE;
}

poll_interactive_keyboard_input :: () -> Playback_Control_Command {
    #if OS == .WINDOWS {
        if _kbhit() != 0 {
            character := _getch();
            if character == 0 || character == 224 {
                _getch();

                return .NONE;
            }

            command := map_character_to_playback_command(character);

            return command;
        }

        return .NONE;
    } else {
        return .NONE;
    }
}

apply_playback_command :: (command: Playback_Control_Command, player: *Playback_State) {
    if command == {
        case .TOGGLE_PLAY_PAUSE;
            player.is_paused = !player.is_paused;

        case .REWIND;
            rewind_playback(player);

        case .TOGGLE_MIXER_VIEW;
            player.show_mixer_view = !player.show_mixer_view;

        case .QUIT;
            player.should_exit = true;

        case .NONE;
    }
}

rewind_playback :: (player: *Playback_State) {
    player.sequencer.clock.current_sample = 0;
}

format_vu_meter_bar :: (level: float, bar_width: int = 12) -> string {
    if bar_width <= 0 {
        return "[]";
    }

    builder: String_Builder;
    append(*builder, "[");

    clamped_level := clamp(level, 0.0, 1.0);
    filled_count := cast(int) (clamped_level * cast(float) bar_width);

    index := 0;
    while index < bar_width {
        if index < filled_count {
            append(*builder, "#");
        } else {
            append(*builder, "-");
        }
        index += 1;
    }

    append(*builder, "]");

    result := builder_to_string(*builder);

    return result;
}

format_vu_meters_display :: (left_level: float, right_level: float, bar_width: int = 12) -> string {
    left_bar := format_vu_meter_bar(left_level, bar_width);
    defer free(left_bar);

    right_bar := format_vu_meter_bar(right_level, bar_width);
    defer free(right_bar);

    builder: String_Builder;
    print_to_builder(*builder, "L: %  R: %", left_bar, right_bar);

    result := builder_to_string(*builder);

    return result;
}

format_playback_status_line :: (player: *Playback_State) -> string {
    bar_index := get_current_bar_index(*player.sequencer.clock);
    beat_index := get_current_beat_index(*player.sequencer.clock);
    beats_per_minute := cast(s64) player.sequencer.clock.beats_per_minute;
    active_voices := count_active_voices(*player.voice_manager);
    state_label := ifx player.is_paused then "[PAUSED] " else "[PLAYING]";

    builder: String_Builder;
    append(*builder, state_label);
    append(*builder, " Bar: ");
    if bar_index < 10 {
        append(*builder, "0");
    }
    print_to_builder(*builder, "%.% | BPM: % | CPU: ", bar_index, beat_index, beats_per_minute);

    clamped_cpu := clamp(player.estimated_cpu_percentage, 0.0, 99.9);
    cpu_integer := cast(s64) clamped_cpu;
    cpu_fraction := cast(s64) ((clamped_cpu - cast(float) cpu_integer) * 10.0);
    print_to_builder(*builder, "%.%", cpu_integer, cpu_fraction);
    append(*builder, "%");
    print_to_builder(*builder, " | Voices: %/%", active_voices, MAXIMUM_VOICES);

    result := builder_to_string(*builder);

    return result;
}

print_mixer_view :: (mixer: *Mixer) {
    print("\n--- Mixer Channel View ---\n");
    track_index := 0;
    while track_index < MAXIMUM_TRACKS {
        channel := *mixer.tracks[track_index];
        if channel.name.count > 0 || channel.gain != 1.0 {
            mute_indicator := ifx channel.is_muted then " [MUTED]" else "";
            solo_indicator := ifx channel.is_soloed then " [SOLO]" else "";
            print("  Track % (%): Gain = %, Pan = %%%\n", channel.track_index, channel.name, channel.gain, channel.pan, mute_indicator, solo_indicator);
        }
        track_index += 1;
    }
    print("  Master: Gain = %, Limiter = %\n\n", mixer.master.gain, ifx mixer.master.limiter_enabled then "ON" else "OFF");
}

playback_audio_callback :: (output_samples: [] float, channel_count: int, sample_rate: int, user_data: *void) {
    player := cast(*Playback_State) user_data;
    frame_count := output_samples.count / channel_count;

    if player.is_paused {
        sample_index := 0;
        while sample_index < output_samples.count {
            output_samples[sample_index] = 0.0;
            sample_index += 1;
        }

        player.peak_level_left = player.peak_level_left * 0.7;
        player.peak_level_right = player.peak_level_right * 0.7;

        return;
    }

    start_time := current_time_monotonic();

    render_audio_block_with_hot_reload(
        *player.hot_reloader,
        *player.sequencer,
        *player.voice_manager,
        *player.mixer,
        output_samples,
        frame_count,
        *player.last_applied_version
    );

    render_duration_seconds, _ := to_float64_seconds(current_time_monotonic() - start_time);
    block_duration_seconds := cast(float64) frame_count / cast(float64) sample_rate;
    if block_duration_seconds > 0.0 {
        cpu_ratio := cast(float) ((render_duration_seconds / block_duration_seconds) * 100.0);
        player.estimated_cpu_percentage = player.estimated_cpu_percentage * 0.9 + cpu_ratio * 0.1;
    }

    maximum_left: float = 0.0;
    maximum_right: float = 0.0;
    sample_index := 0;
    while sample_index < output_samples.count {
        left_sample := abs(output_samples[sample_index]);
        if left_sample > maximum_left {
            maximum_left = left_sample;
        }

        if channel_count > 1 {
            right_sample := abs(output_samples[sample_index + 1]);
            if right_sample > maximum_right {
                maximum_right = right_sample;
            }
        } else {
            maximum_right = maximum_left;
        }

        sample_index += channel_count;
    }

    player.peak_level_left = player.peak_level_left * 0.7 + maximum_left * 0.3;
    player.peak_level_right = player.peak_level_right * 0.7 + maximum_right * 0.3;
}

initialize_playback_state :: (player: *Playback_State, song_path: string, sample_rate: s64 = DEFAULT_SAMPLE_RATE) -> bool {
    player.last_applied_version = 0;
    player.is_paused = false;
    player.show_mixer_view = false;
    player.should_exit = false;
    player.is_running = false;
    player.peak_level_left = 0.0;
    player.peak_level_right = 0.0;
    player.estimated_cpu_percentage = 0.0;

    initialize_voice_manager(*player.voice_manager, sample_rate);
    initialize_mixer(*player.mixer, sample_rate);
    initialize_sequencer_clock(*player.sequencer.clock, sample_rate);

    hot_reloader_success := hot_reloader_initialize(*player.hot_reloader, song_path, sample_rate);
    if !hot_reloader_success {
        return false;
    }

    active_state := cast(*Song_State) atomic_read(*player.hot_reloader.active_state_pointer);
    if active_state != null && active_state.is_valid {
        hot_reloader_apply_state_to_engine(active_state, *player.sequencer, *player.mixer);
        player.last_applied_version = active_state.version;
    }

    configuration: Audio_Configuration;
    configuration.sample_rate = cast(int) sample_rate;
    configuration.channel_count = 2;
    configuration.buffer_size_in_frames = 512;

    backend_success := audio_backend_initialize(*player.audio_backend, configuration, playback_audio_callback, player);
    if !backend_success {
        hot_reloader_shutdown(*player.hot_reloader);

        return false;
    }

    return true;
}

start_playback :: (player: *Playback_State) -> bool {
    if player.is_running {
        return true;
    }

    backend_success := audio_backend_start(*player.audio_backend);
    if !backend_success {
        return false;
    }

    hot_reloader_start(*player.hot_reloader);
    player.is_running = true;

    return true;
}

stop_playback :: (player: *Playback_State) {
    if !player.is_running {
        return;
    }

    audio_backend_stop(*player.audio_backend);
    hot_reloader_stop(*player.hot_reloader);
    player.is_running = false;
}

shutdown_playback_state :: (player: *Playback_State) {
    if player.is_running {
        stop_playback(player);
    }

    audio_backend_shutdown(*player.audio_backend);
    hot_reloader_shutdown(*player.hot_reloader);
}

run_interactive_playback :: (song_path: string) -> bool {
    player: Playback_State;
    initialize_success := initialize_playback_state(*player, song_path);
    if !initialize_success {
        print("Failed to initialize playback for '%'\n", song_path);

        return false;
    }

    start_success := start_playback(*player);
    if !start_success {
        print("Failed to start audio playback for '%'\n", song_path);
        shutdown_playback_state(*player);

        return false;
    }

    print("Playing '%' with hot reloading enabled.\n", song_path);
    print("Controls: [Space] Pause/Resume | [R] Rewind | [M] Mixer View | [Q/Esc] Exit\n\n");

    previous_mixer_view := false;

    while !player.should_exit {
        command := poll_interactive_keyboard_input();
        if command != .NONE {
            apply_playback_command(command, *player);
            if command == .QUIT {
                break;
            }
        }

        if player.show_mixer_view != previous_mixer_view {
            previous_mixer_view = player.show_mixer_view;
            if player.show_mixer_view {
                print_mixer_view(*player.mixer);
            }
        }

        status_line := format_playback_status_line(*player);
        vu_meters := format_vu_meters_display(player.peak_level_left, player.peak_level_right);

        print("\r% | %   ", status_line, vu_meters);

        free(status_line);
        free(vu_meters);

        sleep_milliseconds(25);
    }

    print("\n\nStopping playback and shutting down...\n");
    stop_playback(*player);
    shutdown_playback_state(*player);

    return true;
}

Playback_Control_Command :: enum {
    NONE;
    TOGGLE_PLAY_PAUSE;
    REWIND;
    TOGGLE_MIXER_VIEW;
    QUIT;
}

Playback_State :: struct {
    hot_reloader: Hot_Reloader;
    sequencer: Sequencer;
    voice_manager: Voice_Manager;
    mixer: Mixer;
    audio_backend: Audio_Backend;
    last_applied_version: u64 = 0;
    is_paused: bool = false;
    show_mixer_view: bool = false;
    should_exit: bool = false;
    is_running: bool = false;
    peak_level_left: float = 0.0;
    peak_level_right: float = 0.0;
    estimated_cpu_percentage: float = 0.0;
}

#if OS == .WINDOWS {
    msvcrt :: #library,system "msvcrt";
    _kbhit :: () -> s32 #foreign msvcrt;
    _getch :: () -> s32 #foreign msvcrt;
}
