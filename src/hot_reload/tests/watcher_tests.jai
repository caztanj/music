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

    test("hot_reloader_initialization_and_initial_state", () {
        temporary_file_path := "temporary_hot_reload_initial_test.song";
        write_entire_file(temporary_file_path, VALID_SONG_VERSION_ONE);

        hot_reloader: Hot_Reloader;
        initialize_success := hot_reloader_initialize(*hot_reloader, temporary_file_path);
        expect_true(initialize_success);
        expect_equals(hot_reloader.reload_count, 0);
        expect_true(!hot_reloader.has_error);

        active_state := cast(*Song_State) atomic_read(*hot_reloader.active_state_pointer);
        expect_true(active_state != null);
        expect_true(active_state.is_valid);
        expect_equals(active_state.version, 1);
        expect_equals(active_state.specification.project.name, "Initial Track");
        expect_equals(active_state.specification.project.beats_per_minute, 120.0);

        hot_reloader_shutdown(*hot_reloader);
        file_delete(temporary_file_path);
    });

    test("hot_reloader_lock_free_state_swap", () {
        temporary_file_path := "temporary_hot_reload_swap_test.song";
        write_entire_file(temporary_file_path, VALID_SONG_VERSION_ONE);

        hot_reloader: Hot_Reloader;
        hot_reloader_initialize(*hot_reloader, temporary_file_path);

        write_entire_file(temporary_file_path, VALID_SONG_VERSION_TWO);

        reload_success := hot_reloader_reload_file(*hot_reloader);
        expect_true(reload_success);
        expect_equals(hot_reloader.reload_count, 1);
        expect_true(!hot_reloader.has_error);

        active_state := cast(*Song_State) atomic_read(*hot_reloader.active_state_pointer);
        expect_true(active_state != null);
        expect_true(active_state.is_valid);
        expect_equals(active_state.version, 2);
        expect_equals(active_state.specification.project.name, "Updated Track");
        expect_equals(active_state.specification.project.beats_per_minute, 140.0);

        hot_reloader_shutdown(*hot_reloader);
        file_delete(temporary_file_path);
    });

    test("hot_reloader_syntax_error_non_blocking", () {
        temporary_file_path := "temporary_hot_reload_error_test.song";
        write_entire_file(temporary_file_path, VALID_SONG_VERSION_ONE);

        hot_reloader: Hot_Reloader;
        hot_reloader_initialize(*hot_reloader, temporary_file_path);

        write_entire_file(temporary_file_path, "[invalid_section this is garbage [[[");

        reload_success := hot_reloader_reload_file(*hot_reloader);
        expect_true(!reload_success);
        expect_true(hot_reloader.has_error);
        expect_true(hot_reloader.last_error_message.count > 0);

        active_state := cast(*Song_State) atomic_read(*hot_reloader.active_state_pointer);
        expect_true(active_state != null);
        expect_true(active_state.is_valid);
        expect_equals(active_state.version, 1);
        expect_equals(active_state.specification.project.name, "Initial Track");

        hot_reloader_shutdown(*hot_reloader);
        file_delete(temporary_file_path);
    });

    test("hot_reloader_audio_rendering_and_voice_preservation", () {
        temporary_file_path := "temporary_hot_reload_audio_test.song";
        write_entire_file(temporary_file_path, VALID_SONG_VERSION_ONE);

        hot_reloader: Hot_Reloader;
        hot_reloader_initialize(*hot_reloader, temporary_file_path);

        sequencer: Sequencer;
        initialize_sequencer_clock(*sequencer.clock, 44100, 120.0, 4, 4, 4);

        voice_manager: Voice_Manager;
        initialize_voice_manager(*voice_manager, 44100);

        mixer: Mixer;
        initialize_mixer(*mixer, 44100);

        configuration: Synthesizer_Configuration;
        configuration.waveform = .SAWTOOTH;
        configuration.envelope.attack_milliseconds = 2.0;
        configuration.envelope.decay_milliseconds = 50.0;
        configuration.envelope.sustain_level = 0.5;
        configuration.envelope.release_milliseconds = 200.0;

        trigger_synthesizer_note(*voice_manager, "lead", 1, configuration, 60, 0.8);
        expect_equals(count_active_voices(*voice_manager), 1);

        last_applied_version: u64 = 0;
        output_buffer: [512] float;

        render_audio_block_with_hot_reload(
            *hot_reloader,
            *sequencer,
            *voice_manager,
            *mixer,
            output_buffer,
            256,
            *last_applied_version
        );

        expect_equals(last_applied_version, 1);
        expect_true(count_active_voices(*voice_manager) >= 1);

        write_entire_file(temporary_file_path, VALID_SONG_VERSION_TWO);
        hot_reloader_reload_file(*hot_reloader);

        render_audio_block_with_hot_reload(
            *hot_reloader,
            *sequencer,
            *voice_manager,
            *mixer,
            output_buffer,
            256,
            *last_applied_version
        );

        expect_equals(last_applied_version, 2);
        expect_equals(sequencer.clock.beats_per_minute, 140.0);
        expect_true(count_active_voices(*voice_manager) >= 1);

        hot_reloader_shutdown(*hot_reloader);
        file_delete(temporary_file_path);
    });
}

Watcher_Test_Context :: struct {
    callback_count: int = 0;
    last_changed_path: string;
}

VALID_SONG_VERSION_ONE :: #string END_OF_SONG
[project]
name = "Initial Track"
bpm = 120
bars = 4

[instruments]
lead = synth(wave="saw", attack=10, decay=50, sustain=0.5, release=100)

[pattern melody]
C4 step=0 len=2 vel=0.8

[mixer]
track 1 (lead): gain = 0.8, pan = 0.0, output = master
master: gain = 1.0, limiter = on

[channel_routing]
lead -> track 1

[arrangement]
bar 1-4: melody
END_OF_SONG

VALID_SONG_VERSION_TWO :: #string END_OF_SONG
[project]
name = "Updated Track"
bpm = 140
bars = 8

[instruments]
lead = synth(wave="saw", attack=10, decay=50, sustain=0.5, release=100)

[pattern melody]
D4 step=0 len=2 vel=0.9

[mixer]
track 1 (lead): gain = 0.9, pan = 0.2, output = master
master: gain = 1.0, limiter = on

[channel_routing]
lead -> track 1

[arrangement]
bar 1-8: melody
END_OF_SONG
