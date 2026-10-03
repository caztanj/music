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
