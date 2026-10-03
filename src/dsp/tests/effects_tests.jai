effects_tests :: () {
    test("stereo delay creates echo", () {
        delay: Stereo_Delay;
        initialize_stereo_delay(*delay, 1000);
        configure_stereo_delay(*delay, delay_time_seconds = 0.01, feedback = 0.5, wet_level = 1.0, dry_level = 0.0);

        output_left, output_right := process_stereo_delay(*delay, 1.0, 1.0);
        expect_equals(output_left, 0.0);
        expect_equals(output_right, 0.0);

        step_index := 0;
        while step_index < 9 {
            process_stereo_delay(*delay, 0.0, 0.0);
            step_index += 1;
        }

        delayed_left, delayed_right := process_stereo_delay(*delay, 0.0, 0.0);
        expect_near(delayed_left, 1.0, 0.001);
        expect_near(delayed_right, 1.0, 0.001);

        deinitialize_stereo_delay(*delay);
    });

    test("master limiter clamps loud signals", () {
        limiter: Master_Limiter;
        initialize_master_limiter(*limiter, 44100);
        configure_master_limiter(*limiter, ceiling_decibels = -0.1, release_milliseconds = 20.0);

        ceiling_linear := decibels_to_linear(-0.1);

        sample_index := 0;
        while sample_index < 100 {
            output_left, output_right := process_master_limiter(*limiter, 5.0, -5.0);
            expect_true(output_left <= ceiling_linear + 0.0001);
            expect_true(output_left >= -ceiling_linear - 0.0001);
            expect_true(output_right <= ceiling_linear + 0.0001);
            expect_true(output_right >= -ceiling_linear - 0.0001);
            sample_index += 1;
        }
    });

    test("filter insert lowpass filtering", () {
        insert: Filter_Insert;
        initialize_filter_insert(*insert, 44100);
        configure_filter_insert(*insert, Filter_Type.LOWPASS, 500.0, 0.0);

        filtered_left, filtered_right := process_filter_insert(*insert, 0.5, 0.5);
        expect_true(abs(filtered_left) > 0.0);
    });
}
