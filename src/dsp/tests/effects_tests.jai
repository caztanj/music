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

    test("studio_reverb_impulse_response_and_decay_tail", () {
        reverb: Studio_Reverb;
        initialize_studio_reverb(*reverb, 44100);
        configure_studio_reverb(*reverb, room_size = 0.75, damping = 0.3, predelay_milliseconds = 10.0, wet_level = 1.0, dry_level = 0.0, stereo_width = 1.0);

        sample_index := 0;
        accumulated_early_energy: float = 0.0;
        accumulated_late_energy: float = 0.0;
        channel_difference_accumulated: float = 0.0;
        has_glitch := false;

        while sample_index < 20000 {
            input_sample := ifx sample_index == 0 then 1.0 else 0.0;
            left_sample, right_sample := process_studio_reverb(*reverb, input_sample, input_sample);

            is_nan_left, is_inf_left := is_nan_is_inf(left_sample);
            is_nan_right, is_inf_right := is_nan_is_inf(right_sample);
            if is_nan_left || is_inf_left || is_nan_right || is_inf_right {
                has_glitch = true;
            }

            if sample_index < 400 {
                accumulated_early_energy += left_sample * left_sample + right_sample * right_sample;
            } else if sample_index >= 1000 && sample_index < 5000 {
                accumulated_late_energy += left_sample * left_sample + right_sample * right_sample;
                channel_difference_accumulated += abs(left_sample - right_sample);
            }

            sample_index += 1;
        }

        expect_true(!has_glitch);
        expect_near(accumulated_early_energy, 0.0, 0.001);
        expect_true(accumulated_late_energy > 0.1);
        expect_true(channel_difference_accumulated > 1.0);

        deinitialize_studio_reverb(*reverb);
    });

    test("studio_reverb_predelay_silence", () {
        reverb: Studio_Reverb;
        initialize_studio_reverb(*reverb, 44100);
        configure_studio_reverb(*reverb, room_size = 0.5, damping = 0.5, predelay_milliseconds = 20.0, wet_level = 1.0, dry_level = 0.0);

        sample_index := 0;
        silence_maintained := true;

        while sample_index < 800 {
            input_sample := ifx sample_index == 0 then 1.0 else 0.0;
            left_sample, right_sample := process_studio_reverb(*reverb, input_sample, input_sample);
            if left_sample != 0.0 || right_sample != 0.0 {
                silence_maintained = false;
            }

            sample_index += 1;
        }

        expect_true(silence_maintained);

        deinitialize_studio_reverb(*reverb);
    });

    test("mixer_parser_reverb_arguments", () {
        song_text := "[project]\nname = \"Reverb Mixer Test\"\nbpm = 120\ntime_signature = 4/4\nbars = 1\n\n[instruments]\nlead = synth(wave=\"saw\")\n\n[pattern melody]\nC4 step=0 len=1 vel=1.0\n\n[mixer]\ntrack 1: gain = 0.8, pan = 0.1, reverb = 0.45, reverb_room = 0.85, reverb_damp = 0.35, reverb_predelay = 25.0, output = master\nmaster: gain = 1.0, reverb = 0.2, reverb_room = 0.65, limiter = on\n\n[channel_routing]\nlead -> track 1\n\n[arrangement]\nbar 1: melody\n";

        specification, parse_success, _ := parse_song(song_text, check_samples_on_disk = false);
        expect_true(parse_success);
        expect_equals(specification.mixer.tracks.count, 1);

        track := *specification.mixer.tracks[0];
        expect_true(track.reverb_enabled);
        expect_near(track.reverb_mix, 0.45, 0.001);
        expect_near(track.reverb_room_size, 0.85, 0.001);
        expect_near(track.reverb_damping, 0.35, 0.001);
        expect_near(track.reverb_predelay_milliseconds, 25.0, 0.001);

        expect_true(specification.mixer.master.reverb_enabled);
        expect_near(specification.mixer.master.reverb_mix, 0.2, 0.001);
        expect_near(specification.mixer.master.reverb_room_size, 0.65, 0.001);

        mixer: Mixer;
        configure_mixer_from_definition(*mixer, specification.mixer, 44100, 120.0);
        defer deinitialize_mixer(*mixer);

        expect_true(mixer.tracks[0].reverb_enabled);
        expect_near(mixer.tracks[0].reverb.wet_level, 0.45, 0.001);
        expect_near(mixer.tracks[0].reverb.room_size, 0.85, 0.001);
        expect_true(mixer.master.reverb_enabled);
        expect_near(mixer.master.reverb.wet_level, 0.2, 0.001);
    });
}
