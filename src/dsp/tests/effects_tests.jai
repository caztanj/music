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

    test("chorus_flanger_stereo_decorrelation", () {
        chorus: Chorus_Flanger;
        initialize_chorus_flanger(*chorus, 44100);
        defer deinitialize_chorus_flanger(*chorus);

        configure_chorus_flanger(*chorus, rate_hertz = 1.0, depth_milliseconds = 2.0, center_delay_milliseconds = 7.0, feedback = 0.0, mix = 0.5, stereo_phase_degrees = 90.0);

        sample_index := 0;
        total_stereo_difference: float = 0.0;

        while sample_index < 2000 {
            phase := (cast(float64) sample_index * 440.0 * 2.0 * PI) / 44100.0;
            input_sample := cast(float) sin(phase);

            output_left, output_right := process_chorus_flanger(*chorus, input_sample, input_sample);

            if sample_index >= 500 {
                difference := abs(output_left - output_right);
                total_stereo_difference += difference;
            }

            sample_index += 1;
        }

        expect_true(total_stereo_difference > 10.0);
    });

    test("chorus_flanger_feedback_resonance", () {
        flanger: Chorus_Flanger;
        initialize_chorus_flanger(*flanger, 44100);
        defer deinitialize_chorus_flanger(*flanger);

        exact_delay_milliseconds := cast(float) (100.0 * 1000.0 / 44100.0);
        configure_chorus_flanger(*flanger, rate_hertz = 0.01, depth_milliseconds = 0.0, center_delay_milliseconds = exact_delay_milliseconds, feedback = 0.5, mix = 1.0, stereo_phase_degrees = 0.0);

        sample_index := 0;
        first_echo_peak: float = 0.0;
        second_echo_peak: float = 0.0;
        third_echo_peak: float = 0.0;

        while sample_index < 400 {
            input_sample: float = 0.0;
            if sample_index == 0 {
                input_sample = 1.0;
            }

            output_left, _ := process_chorus_flanger(*flanger, input_sample, input_sample);

            if sample_index >= 98 && sample_index <= 102 {
                if abs(output_left) > first_echo_peak {
                    first_echo_peak = abs(output_left);
                }
            } else if sample_index >= 198 && sample_index <= 202 {
                if abs(output_left) > second_echo_peak {
                    second_echo_peak = abs(output_left);
                }
            } else if sample_index >= 298 && sample_index <= 302 {
                if abs(output_left) > third_echo_peak {
                    third_echo_peak = abs(output_left);
                }
            }

            sample_index += 1;
        }

        expect_true(first_echo_peak > 0.95);
        expect_true(second_echo_peak > 0.45);
        expect_true(third_echo_peak > 0.20);
    });

    test("chorus_flanger_bypass_and_dry_wet", () {
        chorus: Chorus_Flanger;
        initialize_chorus_flanger(*chorus, 44100);
        defer deinitialize_chorus_flanger(*chorus);

        configure_chorus_flanger(*chorus, rate_hertz = 1.0, depth_milliseconds = 2.0, center_delay_milliseconds = 7.0, feedback = 0.0, mix = 0.0, stereo_phase_degrees = 90.0);

        output_left, output_right := process_chorus_flanger(*chorus, 0.735, 0.412);
        expect_near(output_left, 0.735, 0.0001);
        expect_near(output_right, 0.412, 0.0001);
    });

    test("mixer_parser_chorus_arguments", () {
        song_text := "[project]\nname = \"Chorus Mixer Test\"\nbpm = 120\ntime_signature = 4/4\nbars = 1\n\n[instruments]\nlead = synth(wave=\"saw\")\n\n[pattern melody]\nC4 step=0 len=1 vel=1.0\n\n[mixer]\ntrack 1: gain = 0.8, chorus = 0.6, chorus_rate = 1.8, chorus_depth = 3.0, chorus_delay = 8.5, chorus_feedback = 0.25, chorus_phase = 120.0, output = master\nmaster: gain = 1.0, flanger = 0.4, flanger_rate = 0.5, flanger_feedback = 0.7, limiter = on\n\n[channel_routing]\nlead -> track 1\n\n[arrangement]\nbar 1: melody\n";

        specification, parse_success, _ := parse_song(song_text, check_samples_on_disk = false);
        expect_true(parse_success);

        track := *specification.mixer.tracks[0];
        expect_true(track.chorus_enabled);
        expect_near(track.chorus_mix, 0.6, 0.001);
        expect_near(track.chorus_rate_hertz, 1.8, 0.001);
        expect_near(track.chorus_depth_milliseconds, 3.0, 0.001);
        expect_near(track.chorus_center_delay_milliseconds, 8.5, 0.001);
        expect_near(track.chorus_feedback, 0.25, 0.001);
        expect_near(track.chorus_stereo_phase_degrees, 120.0, 0.001);

        expect_true(specification.mixer.master.chorus_enabled);
        expect_near(specification.mixer.master.chorus_mix, 0.4, 0.001);
        expect_near(specification.mixer.master.chorus_rate_hertz, 0.5, 0.001);
        expect_near(specification.mixer.master.chorus_feedback, 0.7, 0.001);

        mixer: Mixer;
        configure_mixer_from_definition(*mixer, specification.mixer, 44100, 120.0);
        defer deinitialize_mixer(*mixer);

        expect_true(mixer.tracks[0].chorus_flanger_enabled);
        expect_near(mixer.tracks[0].chorus_flanger.mix, 0.6, 0.001);
        expect_near(mixer.tracks[0].chorus_flanger.rate_hertz, 1.8, 0.001);
        expect_near(mixer.tracks[0].chorus_flanger.depth_milliseconds, 3.0, 0.001);
        expect_near(mixer.tracks[0].chorus_flanger.center_delay_milliseconds, 8.5, 0.001);
        expect_near(mixer.tracks[0].chorus_flanger.feedback, 0.25, 0.001);
        expect_near(mixer.tracks[0].chorus_flanger.stereo_phase_degrees, 120.0, 0.001);

        expect_true(mixer.master.chorus_flanger_enabled);
        expect_near(mixer.master.chorus_flanger.mix, 0.4, 0.001);
        expect_near(mixer.master.chorus_flanger.rate_hertz, 0.5, 0.001);
        expect_near(mixer.master.chorus_flanger.feedback, 0.7, 0.001);
    });

    test("saturation_tanh_soft_compression", () {
        saturation: Saturation_Insert;
        initialize_saturation_insert(*saturation);
        configure_saturation_insert(*saturation, saturation_type = .TANH, drive = 3.0, mix = 1.0, output_gain = 1.0);

        small_left, small_right := process_saturation_insert(*saturation, 0.1, -0.1);
        expect_near(small_left, 0.2913, 0.005);
        expect_near(small_right, -0.2913, 0.005);

        high_left, high_right := process_saturation_insert(*saturation, 1.0, -1.0);
        expect_near(high_left, 0.9950, 0.005);
        expect_near(high_right, -0.9950, 0.005);

        overdriven_left, overdriven_right := process_saturation_insert(*saturation, 50.0, -50.0);
        expect_near(overdriven_left, 1.0, 0.0001);
        expect_near(overdriven_right, -1.0, 0.0001);
    });

    test("saturation_cubic_and_hard_clip", () {
        cubic_saturation: Saturation_Insert;
        initialize_saturation_insert(*cubic_saturation);
        configure_saturation_insert(*cubic_saturation, saturation_type = .CUBIC, drive = 1.0, mix = 1.0, output_gain = 1.0);

        cubic_peak_left, _ := process_saturation_insert(*cubic_saturation, 1.5, 1.5);
        expect_near(cubic_peak_left, 1.0, 0.001);

        cubic_clipped_left, _ := process_saturation_insert(*cubic_saturation, 2.5, 2.5);
        expect_near(cubic_clipped_left, 1.0, 0.001);

        hard_saturation: Saturation_Insert;
        initialize_saturation_insert(*hard_saturation);
        configure_saturation_insert(*hard_saturation, saturation_type = .HARD_CLIP, drive = 2.0, mix = 1.0, output_gain = 1.0);

        hard_linear_left, _ := process_saturation_insert(*hard_saturation, 0.3, 0.3);
        expect_near(hard_linear_left, 0.6, 0.001);

        hard_clipped_left, hard_clipped_right := process_saturation_insert(*hard_saturation, 0.8, -0.8);
        expect_near(hard_clipped_left, 1.0, 0.001);
        expect_near(hard_clipped_right, -1.0, 0.001);
    });

    test("saturation_mix_and_bypass", () {
        saturation: Saturation_Insert;
        initialize_saturation_insert(*saturation);
        configure_saturation_insert(*saturation, saturation_type = .TANH, drive = 5.0, mix = 0.0, output_gain = 1.0);

        bypass_left, bypass_right := process_saturation_insert(*saturation, 0.75, -0.42);
        expect_near(bypass_left, 0.75, 0.0001);
        expect_near(bypass_right, -0.42, 0.0001);

        configure_saturation_insert(*saturation, saturation_type = .TANH, drive = 2.0, mix = 0.5, output_gain = 1.0);
        half_mix_left, _ := process_saturation_insert(*saturation, 1.0, 1.0);
        expected_half := (1.0 + 0.9640) * 0.5;
        expect_near(half_mix_left, cast(float) expected_half, 0.01);
    });

    test("mixer_parser_saturation_arguments", () {
        song_text := "[project]\nname = \"Saturation Mixer Test\"\nbpm = 120\ntime_signature = 4/4\nbars = 1\n\n[instruments]\nlead = synth(wave=\"saw\")\n\n[pattern melody]\nC4 step=0 len=1 vel=1.0\n\n[mixer]\ntrack 1: gain = 0.8, saturation = \"cubic\", drive = 2.5, saturation_mix = 0.75, saturation_gain = 0.9, output = master\nmaster: gain = 1.0, saturation = \"tanh\", drive = 1.5, limiter = on\n\n[channel_routing]\nlead -> track 1\n\n[arrangement]\nbar 1: melody\n";

        specification, parse_success, _ := parse_song(song_text, check_samples_on_disk = false);
        expect_true(parse_success);

        track := *specification.mixer.tracks[0];
        expect_true(track.saturation_enabled);
        expect_true(track.saturation_type == .CUBIC);
        expect_near(track.saturation_drive, 2.5, 0.001);
        expect_near(track.saturation_mix, 0.75, 0.001);
        expect_near(track.saturation_output_gain, 0.9, 0.001);

        expect_true(specification.mixer.master.saturation_enabled);
        expect_true(specification.mixer.master.saturation_type == .TANH);
        expect_near(specification.mixer.master.saturation_drive, 1.5, 0.001);

        mixer: Mixer;
        configure_mixer_from_definition(*mixer, specification.mixer, 44100, 120.0);
        defer deinitialize_mixer(*mixer);

        expect_true(mixer.tracks[0].saturation_enabled);
        expect_true(mixer.tracks[0].saturation.saturation_type == .CUBIC);
        expect_near(mixer.tracks[0].saturation.drive, 2.5, 0.001);
        expect_near(mixer.tracks[0].saturation.mix, 0.75, 0.001);
        expect_near(mixer.tracks[0].saturation.output_gain, 0.9, 0.001);

        expect_true(mixer.master.saturation_enabled);
        expect_true(mixer.master.saturation.saturation_type == .TANH);
        expect_near(mixer.master.saturation.drive, 1.5, 0.001);
    });

    test("compressor_gain_reduction_above_threshold", () {
        compressor: Dynamic_Compressor;
        initialize_dynamic_compressor(*compressor, 44100);
        configure_dynamic_compressor(*compressor, threshold_decibels = -10.0, ratio = 4.0, attack_milliseconds = 1.0, release_milliseconds = 50.0, knee_decibels = 0.0, makeup_gain_decibels = 0.0, mix = 1.0);

        sample_index := 0;
        final_left: float = 0.0;
        final_right: float = 0.0;

        while sample_index < 1000 {
            final_left, final_right = process_dynamic_compressor(*compressor, 1.0, 1.0);
            sample_index += 1;
        }

        expect_near(final_left, 0.4217, 0.015);
        expect_near(final_right, 0.4217, 0.015);
        expect_near(compressor.envelope_decibels, -7.5, 0.25);

        release_index := 0;
        while release_index < 10000 {
            process_dynamic_compressor(*compressor, 0.0, 0.0);
            release_index += 1;
        }

        expect_true(compressor.envelope_decibels > -0.5);
    });

    test("compressor_soft_knee_smooth_transition", () {
        compressor: Dynamic_Compressor;
        initialize_dynamic_compressor(*compressor, 44100);
        configure_dynamic_compressor(*compressor, threshold_decibels = -10.0, ratio = 4.0, attack_milliseconds = 0.1, release_milliseconds = 100.0, knee_decibels = 6.0, makeup_gain_decibels = 0.0, mix = 1.0);

        sub_knee_amplitude := decibels_to_linear(-14.0);
        sample_index := 0;
        while sample_index < 100 {
            process_dynamic_compressor(*compressor, sub_knee_amplitude, sub_knee_amplitude);
            sample_index += 1;
        }
        expect_near(compressor.envelope_decibels, 0.0, 0.01);

        mid_knee_amplitude := decibels_to_linear(-10.0);
        sample_index = 0;
        while sample_index < 500 {
            process_dynamic_compressor(*compressor, mid_knee_amplitude, mid_knee_amplitude);
            sample_index += 1;
        }
        expect_true(compressor.envelope_decibels < -0.5);
        expect_true(compressor.envelope_decibels > -3.0);
    });

    test("compressor_makeup_gain_and_parallel_mix", () {
        compressor: Dynamic_Compressor;
        initialize_dynamic_compressor(*compressor, 44100);
        configure_dynamic_compressor(*compressor, threshold_decibels = -10.0, ratio = 4.0, makeup_gain_decibels = 6.0206, mix = 1.0);

        small_sample: float = 0.01;
        output_left, output_right := process_dynamic_compressor(*compressor, small_sample, small_sample);
        expect_near(output_left, 0.02, 0.001);
        expect_near(output_right, 0.02, 0.001);

        configure_dynamic_compressor(*compressor, threshold_decibels = -20.0, ratio = 100.0, attack_milliseconds = 0.1, makeup_gain_decibels = 0.0, mix = 0.5);
        sample_index := 0;
        blended_left: float = 0.0;
        while sample_index < 500 {
            blended_left, _ = process_dynamic_compressor(*compressor, 1.0, 1.0);
            sample_index += 1;
        }
        expect_true(blended_left > 0.5);
        expect_true(blended_left < 0.6);
    });

    test("mixer_parser_compressor_arguments", () {
        song_text := "[project]\nname = \"Compressor Mixer Test\"\nbpm = 120\ntime_signature = 4/4\nbars = 1\n\n[instruments]\nlead = synth(wave=\"saw\")\n\n[pattern melody]\nC4 step=0 len=1 vel=1.0\n\n[mixer]\ntrack 1: gain = 0.9, comp = on, comp_threshold = -15.5, comp_ratio = 3.5, comp_attack = 5.0, comp_release = 80.0, comp_knee = 4.0, comp_gain = 3.0, comp_mix = 0.8, output = master\nmaster: gain = 1.0, compressor = -8.0, ratio = 2.5, attack = 20.0, release = 150.0, limiter = on\n\n[channel_routing]\nlead -> track 1\n\n[arrangement]\nbar 1: melody\n";

        specification, parse_success, _ := parse_song(song_text, check_samples_on_disk = false);
        expect_true(parse_success);

        track := *specification.mixer.tracks[0];
        expect_true(track.compressor_enabled);
        expect_near(track.compressor_threshold_decibels, -15.5, 0.001);
        expect_near(track.compressor_ratio, 3.5, 0.001);
        expect_near(track.compressor_attack_milliseconds, 5.0, 0.001);
        expect_near(track.compressor_release_milliseconds, 80.0, 0.001);
        expect_near(track.compressor_knee_decibels, 4.0, 0.001);
        expect_near(track.compressor_makeup_gain_decibels, 3.0, 0.001);
        expect_near(track.compressor_mix, 0.8, 0.001);

        expect_true(specification.mixer.master.compressor_enabled);
        expect_near(specification.mixer.master.compressor_threshold_decibels, -8.0, 0.001);
        expect_near(specification.mixer.master.compressor_ratio, 2.5, 0.001);
        expect_near(specification.mixer.master.compressor_attack_milliseconds, 20.0, 0.001);
        expect_near(specification.mixer.master.compressor_release_milliseconds, 150.0, 0.001);

        mixer: Mixer;
        configure_mixer_from_definition(*mixer, specification.mixer, 44100, 120.0);
        defer deinitialize_mixer(*mixer);

        expect_true(mixer.tracks[0].compressor_enabled);
        expect_near(mixer.tracks[0].compressor.threshold_decibels, -15.5, 0.001);
        expect_near(mixer.tracks[0].compressor.ratio, 3.5, 0.001);
        expect_near(mixer.tracks[0].compressor.attack_milliseconds, 5.0, 0.001);
        expect_near(mixer.tracks[0].compressor.release_milliseconds, 80.0, 0.001);
        expect_near(mixer.tracks[0].compressor.knee_decibels, 4.0, 0.001);
        expect_near(mixer.tracks[0].compressor.makeup_gain_decibels, 3.0, 0.001);
        expect_near(mixer.tracks[0].compressor.mix, 0.8, 0.001);

        expect_true(mixer.master.compressor_enabled);
        expect_near(mixer.master.compressor.threshold_decibels, -8.0, 0.001);
        expect_near(mixer.master.compressor.ratio, 2.5, 0.001);
        expect_near(mixer.master.compressor.attack_milliseconds, 20.0, 0.001);
        expect_near(mixer.master.compressor.release_milliseconds, 150.0, 0.001);
    });

    test("compressor_sidechain_ducking", () {
        compressor: Dynamic_Compressor;
        initialize_dynamic_compressor(*compressor, 44100);
        configure_dynamic_compressor(
            *compressor,
            threshold_decibels = -20.0,
            ratio = 20.0,
            attack_milliseconds = 1.0,
            release_milliseconds = 50.0,
            knee_decibels = 0.0,
            makeup_gain_decibels = 0.0,
            mix = 1.0,
            ducking_depth_decibels = 12.0
        );

        bass_sample: float = 0.8;
        sample_index := 0;
        while sample_index < 100 {
            output_left, output_right := process_dynamic_compressor(*compressor, bass_sample, bass_sample, sidechain_left = 0.0, sidechain_right = 0.0, use_sidechain = true);
            expect_near(output_left, bass_sample, 0.001);
            expect_near(output_right, bass_sample, 0.001);
            sample_index += 1;
        }

        sample_index = 0;
        ducked_left: float = 0.0;
        ducked_right: float = 0.0;
        while sample_index < 300 {
            ducked_left, ducked_right = process_dynamic_compressor(*compressor, bass_sample, bass_sample, sidechain_left = 1.0, sidechain_right = 1.0, use_sidechain = true);
            sample_index += 1;
        }

        expect_near(compressor.envelope_decibels, -12.0, 0.1);
        expected_ducked_sample := bass_sample * decibels_to_linear(-12.0);
        expect_near(ducked_left, expected_ducked_sample, 0.01);
        expect_near(ducked_right, expected_ducked_sample, 0.01);
        expect_true(ducked_left < 0.25);

        sample_index = 0;
        recovered_left: float = 0.0;
        while sample_index < 12000 {
            recovered_left, _ = process_dynamic_compressor(*compressor, bass_sample, bass_sample, sidechain_left = 0.0, sidechain_right = 0.0, use_sidechain = true);
            sample_index += 1;
        }

        expect_true(compressor.envelope_decibels > -0.5);
        expect_near(recovered_left, bass_sample, 0.05);

        mixer: Mixer;
        initialize_mixer(*mixer, 44100);
        defer deinitialize_mixer(*mixer);

        channel_1 := *mixer.tracks[0];
        channel_2 := *mixer.tracks[1];

        channel_2.sidechain_source_track_index = 1;
        channel_2.compressor_enabled = true;
        configure_dynamic_compressor(
            *channel_2.compressor,
            threshold_decibels = -24.0,
            ratio = 20.0,
            attack_milliseconds = 1.0,
            release_milliseconds = 50.0,
            knee_decibels = 0.0,
            makeup_gain_decibels = 0.0,
            mix = 1.0,
            ducking_depth_decibels = 10.0
        );

        frame_index := 0;
        while frame_index < 256 {
            channel_1.left_buffer[frame_index] = 1.0;
            channel_1.right_buffer[frame_index] = 1.0;
            channel_2.left_buffer[frame_index] = 0.8;
            channel_2.right_buffer[frame_index] = 0.8;
            frame_index += 1;
        }

        mix_channels_to_master(*mixer, 256);

        pan_factor := cast(float) cos(0.25 * PI);
        kick_expected_master := 1.0 * pan_factor;
        ducked_bass_gain := decibels_to_linear(channel_2.compressor.envelope_decibels);
        expected_ducked_bass_master := 0.8 * ducked_bass_gain * pan_factor;
        expected_combined := kick_expected_master + expected_ducked_bass_master;

        expect_near(channel_2.compressor.envelope_decibels, -10.0, 0.1);
        expect_near(mixer.master.left_buffer[250], expected_combined, 0.02);
    });

    test("mixer_parser_sidechain_arguments", () {
        song_text := "[project]\nname = \"Sidechain Ducking Test\"\nbpm = 120\ntime_signature = 4/4\nbars = 1\n\n[instruments]\nkick = sampler(\"samples/kick.wav\")\nbass = synth(wave=\"saw\")\nsynth_lead = synth(wave=\"square\")\npad = synth(wave=\"sine\")\n\n[pattern melody]\nC4 step=0 len=1 vel=1.0\n\n[mixer]\ntrack 1 (drums): gain = 0.95, output = master\ntrack 2 (bass): gain = 0.90, sidechain = 1, ducking_depth = 12 db, comp_attack = 2.0, comp_release = 120.0, output = master\ntrack 3 (synth): gain = 0.80, sidechain = drums, ducking_depth = 8 db, output = master\ntrack 4 (pad): gain = 0.70, sidechain = kick, ducking_depth = 6 db, output = master\nmaster: gain = 1.0, limiter = on\n\n[channel_routing]\nkick -> track 1\nbass -> track 2\nsynth_lead -> track 3\npad -> track 4\n\n[arrangement]\nbar 1: melody\n";

        specification, parse_success, _ := parse_song(song_text, check_samples_on_disk = false);
        expect_true(parse_success);

        track_2 := *specification.mixer.tracks[1];
        expect_equals(track_2.sidechain_source_track_index, 1);
        expect_true(track_2.compressor_enabled);
        expect_near(track_2.sidechain_depth_decibels, 12.0, 0.001);
        expect_near(track_2.compressor_attack_milliseconds, 2.0, 0.001);
        expect_near(track_2.compressor_release_milliseconds, 120.0, 0.001);

        track_3 := *specification.mixer.tracks[2];
        expect_equals(track_3.sidechain_source_track_index, 1);
        expect_true(track_3.compressor_enabled);
        expect_near(track_3.sidechain_depth_decibels, 8.0, 0.001);

        track_4 := *specification.mixer.tracks[3];
        expect_equals(track_4.sidechain_source_track_index, 1);
        expect_true(track_4.compressor_enabled);
        expect_near(track_4.sidechain_depth_decibels, 6.0, 0.001);

        mixer: Mixer;
        configure_mixer_from_definition(*mixer, specification.mixer, 44100, 120.0);
        defer deinitialize_mixer(*mixer);

        expect_equals(mixer.tracks[1].sidechain_source_track_index, 1);
        expect_true(mixer.tracks[1].compressor_enabled);
        expect_near(mixer.tracks[1].compressor.ducking_depth_decibels, 12.0, 0.001);
        expect_near(mixer.tracks[1].compressor.attack_milliseconds, 2.0, 0.001);
        expect_near(mixer.tracks[1].compressor.release_milliseconds, 120.0, 0.001);

        expect_equals(mixer.tracks[2].sidechain_source_track_index, 1);
        expect_true(mixer.tracks[2].compressor_enabled);
        expect_near(mixer.tracks[2].compressor.ducking_depth_decibels, 8.0, 0.001);

        expect_equals(mixer.tracks[3].sidechain_source_track_index, 1);
        expect_true(mixer.tracks[3].compressor_enabled);
        expect_near(mixer.tracks[3].compressor.ducking_depth_decibels, 6.0, 0.001);
    });
}
