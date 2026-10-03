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

    test("parametric_equalizer_low_shelf_boost_and_cut", () {
        boosted_equalizer: Parametric_Equalizer;
        initialize_parametric_equalizer(*boosted_equalizer, 44100);
        configure_parametric_equalizer(*boosted_equalizer, low_gain_decibels = 6.0, mid_gain_decibels = 0.0, high_gain_decibels = 0.0, low_frequency_hertz = 200.0);

        cut_equalizer: Parametric_Equalizer;
        initialize_parametric_equalizer(*cut_equalizer, 44100);
        configure_parametric_equalizer(*cut_equalizer, low_gain_decibels = -6.0, mid_gain_decibels = 0.0, high_gain_decibels = 0.0, low_frequency_hertz = 200.0);

        sample_index := 0;
        flat_energy: float = 0.0;
        boosted_energy: float = 0.0;
        cut_energy: float = 0.0;

        while sample_index < 2000 {
            phase := (cast(float64) sample_index * 100.0 * 2.0 * PI) / 44100.0;
            input_sample := cast(float) sin(phase);

            boosted_left, _ := process_parametric_equalizer(*boosted_equalizer, input_sample, input_sample);
            cut_left, _ := process_parametric_equalizer(*cut_equalizer, input_sample, input_sample);

            if sample_index >= 500 {
                flat_energy += input_sample * input_sample;
                boosted_energy += boosted_left * boosted_left;
                cut_energy += cut_left * cut_left;
            }

            sample_index += 1;
        }

        expect_true(boosted_energy > flat_energy * 2.5);
        expect_true(cut_energy < flat_energy * 0.5);
    });

    test("parametric_equalizer_mid_peaking_bell_boost_and_cut", () {
        boosted_equalizer: Parametric_Equalizer;
        initialize_parametric_equalizer(*boosted_equalizer, 44100);
        configure_parametric_equalizer(*boosted_equalizer, low_gain_decibels = 0.0, mid_gain_decibels = 6.0, high_gain_decibels = 0.0, mid_frequency_hertz = 1000.0, mid_quality_factor = 2.0);

        cut_equalizer: Parametric_Equalizer;
        initialize_parametric_equalizer(*cut_equalizer, 44100);
        configure_parametric_equalizer(*cut_equalizer, low_gain_decibels = 0.0, mid_gain_decibels = -6.0, high_gain_decibels = 0.0, mid_frequency_hertz = 1000.0, mid_quality_factor = 2.0);

        sample_index := 0;
        flat_energy: float = 0.0;
        boosted_energy: float = 0.0;
        cut_energy: float = 0.0;

        while sample_index < 2000 {
            phase := (cast(float64) sample_index * 1000.0 * 2.0 * PI) / 44100.0;
            input_sample := cast(float) sin(phase);

            boosted_left, _ := process_parametric_equalizer(*boosted_equalizer, input_sample, input_sample);
            cut_left, _ := process_parametric_equalizer(*cut_equalizer, input_sample, input_sample);

            if sample_index >= 500 {
                flat_energy += input_sample * input_sample;
                boosted_energy += boosted_left * boosted_left;
                cut_energy += cut_left * cut_left;
            }

            sample_index += 1;
        }

        expect_true(boosted_energy > flat_energy * 2.5);
        expect_true(cut_energy < flat_energy * 0.5);
    });

    test("parametric_equalizer_high_shelf_air_boost", () {
        equalizer: Parametric_Equalizer;
        initialize_parametric_equalizer(*equalizer, 44100);
        configure_parametric_equalizer(*equalizer, low_gain_decibels = 0.0, mid_gain_decibels = 0.0, high_gain_decibels = 6.0, high_frequency_hertz = 8000.0);

        sample_index := 0;
        flat_energy: float = 0.0;
        boosted_energy: float = 0.0;

        while sample_index < 2000 {
            phase := (cast(float64) sample_index * 10000.0 * 2.0 * PI) / 44100.0;
            input_sample := cast(float) sin(phase);

            boosted_left, _ := process_parametric_equalizer(*equalizer, input_sample, input_sample);

            if sample_index >= 500 {
                flat_energy += input_sample * input_sample;
                boosted_energy += boosted_left * boosted_left;
            }

            sample_index += 1;
        }

        expect_true(boosted_energy > flat_energy * 2.0);
    });

    test("mixer_parser_equalizer_arguments", () {
        song_text := "[project]\nname = \"EQ Mixer Test\"\nbpm = 120\ntime_signature = 4/4\nbars = 1\n\n[instruments]\nlead = synth(wave=\"saw\")\n\n[pattern melody]\nC4 step=0 len=1 vel=1.0\n\n[mixer]\ntrack 1: gain = 0.9, eq_low = 3.5, eq_low_freq = 100, eq_mid = -2.5, eq_mid_freq = 800, eq_mid_q = 1.5, eq_high = 4.0, eq_high_freq = 10000, output = master\nmaster: gain = 1.0, eq_low = -1.5, eq_high = 2.5, limiter = on\n\n[channel_routing]\nlead -> track 1\n\n[arrangement]\nbar 1: melody\n";

        specification, parse_success, _ := parse_song(song_text, check_samples_on_disk = false);
        expect_true(parse_success);

        track := *specification.mixer.tracks[0];
        expect_true(track.equalizer_enabled);
        expect_near(track.equalizer_low_gain_decibels, 3.5, 0.001);
        expect_near(track.equalizer_low_frequency_hertz, 100.0, 0.001);
        expect_near(track.equalizer_mid_gain_decibels, -2.5, 0.001);
        expect_near(track.equalizer_mid_frequency_hertz, 800.0, 0.001);
        expect_near(track.equalizer_mid_quality_factor, 1.5, 0.001);
        expect_near(track.equalizer_high_gain_decibels, 4.0, 0.001);
        expect_near(track.equalizer_high_frequency_hertz, 10000.0, 0.001);

        expect_true(specification.mixer.master.equalizer_enabled);
        expect_near(specification.mixer.master.equalizer_low_gain_decibels, -1.5, 0.001);
        expect_near(specification.mixer.master.equalizer_high_gain_decibels, 2.5, 0.001);

        mixer: Mixer;
        configure_mixer_from_definition(*mixer, specification.mixer, 44100, 120.0);
        defer deinitialize_mixer(*mixer);

        expect_true(mixer.tracks[0].equalizer_enabled);
        expect_near(mixer.tracks[0].equalizer.low_band.gain_decibels, 3.5, 0.001);
        expect_near(mixer.tracks[0].equalizer.low_band.frequency_hertz, 100.0, 0.001);
        expect_near(mixer.tracks[0].equalizer.mid_band.gain_decibels, -2.5, 0.001);
        expect_near(mixer.tracks[0].equalizer.mid_band.quality_factor, 1.5, 0.001);
        expect_true(mixer.master.equalizer_enabled);
        expect_near(mixer.master.equalizer.low_band.gain_decibels, -1.5, 0.001);
        expect_near(mixer.master.equalizer.high_band.gain_decibels, 2.5, 0.001);
    });
}
