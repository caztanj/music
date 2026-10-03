watcher_test_callback :: (file_path: string, user_data: *void) {
    watcher_test_context := cast(*Watcher_Test_Context) user_data;
    watcher_test_context.callback_count += 1;
    watcher_test_context.last_changed_path = file_path;
}

watcher_tests :: () {
    test("file_watcher_initialization", () {
        watcher: File_Watcher;
        initialize_success := file_watcher_initialize(*watcher, "songs/test.song", watcher_test_callback);

        expect_true(initialize_success);
        expect_equals(watcher.file_path, "songs/test.song");
        expect_equals(watcher.polling_interval_in_milliseconds, 25);
        expect_equals(watcher.debounce_delay_in_milliseconds, 75);
        expect_true(!watcher.is_running);
    });

    test("file_modification_time_and_size_detection", () {
        temporary_file_path := "temporary_watcher_test_file.txt";
        write_success := write_entire_file(temporary_file_path, "sample text");
        expect_true(write_success);

        modification_time, file_size, file_exists := get_file_modification_time_and_size(temporary_file_path);
        expect_true(file_exists);
        expect_equals(file_size, 11);
        expect_true(modification_time > 0);

        file_delete(temporary_file_path);

        _, _, exists_after_delete := get_file_modification_time_and_size(temporary_file_path);
        expect_true(!exists_after_delete);
    });

    test("file_watcher_check_for_changes", () {
        temporary_file_path := "temporary_watcher_check_file.txt";
        write_entire_file(temporary_file_path, "initial content");

        watcher: File_Watcher;
        file_watcher_initialize(*watcher, temporary_file_path, watcher_test_callback);

        initial_has_changed := file_watcher_check_for_changes(*watcher);
        expect_true(!initial_has_changed);

        sleep_milliseconds(20);
        write_entire_file(temporary_file_path, "updated content with more text");

        updated_has_changed := file_watcher_check_for_changes(*watcher);
        expect_true(updated_has_changed);

        subsequent_has_changed := file_watcher_check_for_changes(*watcher);
        expect_true(!subsequent_has_changed);

        file_delete(temporary_file_path);
    });

    test("file_watcher_debouncing_and_callback", () {
        temporary_file_path := "temporary_watcher_debounce_file.txt";
        write_entire_file(temporary_file_path, "version 0");

        watcher_test_context: Watcher_Test_Context;
        watcher: File_Watcher;
        file_watcher_initialize(
            *watcher,
            temporary_file_path,
            watcher_test_callback,
            *watcher_test_context,
            polling_interval_in_milliseconds = 15,
            debounce_delay_in_milliseconds = 60
        );

        start_success := file_watcher_start(*watcher);
        expect_true(start_success);
        expect_true(watcher.is_running);

        sleep_milliseconds(30);
        expect_equals(watcher_test_context.callback_count, 0);

        write_entire_file(temporary_file_path, "version 1");
        sleep_milliseconds(15);
        write_entire_file(temporary_file_path, "version 2");
        sleep_milliseconds(15);
        write_entire_file(temporary_file_path, "version 3 finished");

        sleep_milliseconds(140);

        expect_equals(watcher_test_context.callback_count, 1);
        expect_equals(watcher_test_context.last_changed_path, temporary_file_path);

        stop_success := file_watcher_stop(*watcher);
        expect_true(stop_success);
        expect_true(!watcher.is_running);

        file_watcher_shutdown(*watcher);
        file_delete(temporary_file_path);
    });

    test("file_watcher_lifecycle_idempotency", () {
        temporary_file_path := "temporary_watcher_lifecycle_file.txt";
        write_entire_file(temporary_file_path, "test");

        watcher: File_Watcher;
        file_watcher_initialize(*watcher, temporary_file_path, watcher_test_callback);

        expect_true(file_watcher_start(*watcher));
        expect_true(file_watcher_start(*watcher));

        expect_true(file_watcher_stop(*watcher));
        expect_true(file_watcher_stop(*watcher));

        file_watcher_shutdown(*watcher);
        file_delete(temporary_file_path);
    });
}

Watcher_Test_Context :: struct {
    callback_count: int = 0;
    last_changed_path: string;
}
