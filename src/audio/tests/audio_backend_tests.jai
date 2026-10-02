test_dummy_audio_callback :: (output_samples: [] float, channel_count: int, sample_rate: int, user_data: *void) {
    sample_index := 0;
    while sample_index < output_samples.count {
        output_samples[sample_index] = 0.0;
        sample_index += 1;
    }
}

audio_backend_tests :: () {
    test("audio_configuration_defaults", () {
        configuration: Audio_Configuration;

        expect_equals(configuration.sample_rate, DEFAULT_SAMPLE_RATE);
        expect_equals(configuration.channel_count, 2);
        expect_equals(configuration.buffer_size_in_frames, 512);
    });

    test("audio_backend_lifecycle", () {
        configuration: Audio_Configuration;
        backend: Audio_Backend;

        initialize_success := audio_backend_initialize(*backend, configuration, test_dummy_audio_callback);

        if initialize_success {
            start_success := audio_backend_start(*backend);
            expect_true(start_success);
            expect_true(backend.is_running);

            sleep_milliseconds(50);

            stop_success := audio_backend_stop(*backend);
            expect_true(stop_success);
            expect_true(!backend.is_running);

            audio_backend_shutdown(*backend);
        }
    });

    test("audio_backend_idempotency", () {
        configuration: Audio_Configuration;
        backend: Audio_Backend;

        initialize_success := audio_backend_initialize(*backend, configuration, test_dummy_audio_callback);

        if initialize_success {
            expect_true(audio_backend_start(*backend));
            expect_true(audio_backend_start(*backend));

            expect_true(audio_backend_stop(*backend));
            expect_true(audio_backend_stop(*backend));

            audio_backend_shutdown(*backend);
        }
    });
}
