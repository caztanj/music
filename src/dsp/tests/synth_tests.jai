synth_tests :: () {
    test("oscillator waveforms within valid bounds", () {
        phase_increment := 440.0 / 44100.0;
        phase := 0.0;

        while phase < 1.0 {
            sine_sample := generate_oscillator_sample(Waveform_Type.SINE, phase, phase_increment);
            expect_true(sine_sample >= -1.0 && sine_sample <= 1.0);

            sawtooth_sample := generate_oscillator_sample(Waveform_Type.SAWTOOTH, phase, phase_increment);
            expect_true(sawtooth_sample >= -1.1 && sawtooth_sample <= 1.1);

            square_sample := generate_oscillator_sample(Waveform_Type.SQUARE, phase, phase_increment);
            expect_true(square_sample >= -1.1 && square_sample <= 1.1);

            triangle_sample := generate_oscillator_sample(Waveform_Type.TRIANGLE, phase, phase_increment);
            expect_true(triangle_sample >= -1.0 && triangle_sample <= 1.0);

            phase += 0.05;
        }
    });

    test("biquad filter lowpass attenuation", () {
        coefficients := calculate_biquad_coefficients(Filter_Type.LOWPASS, 500.0, 0.0, 44100);
        state_1: float = 0.0;
        state_2: float = 0.0;

        low_frequency := 100.0;
        low_frequency_phase_increment := low_frequency / 44100.0;
        low_phase := 0.0;
        low_max_amplitude: float = 0.0;

        sample_index := 0;
        while sample_index < 1000 {
            input_sample := cast(float) sin(low_phase * 2.0 * PI);
            output_sample := process_biquad_filter(coefficients, input_sample, *state_1, *state_2);
            if sample_index > 200 && abs(output_sample) > low_max_amplitude {
                low_max_amplitude = abs(output_sample);
            }
            low_phase += low_frequency_phase_increment;
            sample_index += 1;
        }

        expect_true(low_max_amplitude > 0.8);

        state_1 = 0.0;
        state_2 = 0.0;
        high_frequency := 5000.0;
        high_frequency_phase_increment := high_frequency / 44100.0;
        high_phase := 0.0;
        high_max_amplitude: float = 0.0;

        sample_index = 0;
        while sample_index < 1000 {
            input_sample := cast(float) sin(high_phase * 2.0 * PI);
            output_sample := process_biquad_filter(coefficients, input_sample, *state_1, *state_2);
            if sample_index > 200 && abs(output_sample) > high_max_amplitude {
                high_max_amplitude = abs(output_sample);
            }
            high_phase += high_frequency_phase_increment;
            sample_index += 1;
        }

        expect_true(high_max_amplitude < 0.2);
    });

    test("biquad filter highpass attenuation", () {
        coefficients := calculate_biquad_coefficients(Filter_Type.HIGHPASS, 2000.0, 0.0, 44100);
        state_1: float = 0.0;
        state_2: float = 0.0;

        low_frequency := 100.0;
        low_frequency_phase_increment := low_frequency / 44100.0;
        low_phase := 0.0;
        low_max_amplitude: float = 0.0;

        sample_index := 0;
        while sample_index < 1000 {
            input_sample := cast(float) sin(low_phase * 2.0 * PI);
            output_sample := process_biquad_filter(coefficients, input_sample, *state_1, *state_2);
            if sample_index > 200 && abs(output_sample) > low_max_amplitude {
                low_max_amplitude = abs(output_sample);
            }
            low_phase += low_frequency_phase_increment;
            sample_index += 1;
        }

        expect_true(low_max_amplitude < 0.2);
    });

    test("synthesizer voice lifecycle and rendering", () {
        configuration: Synthesizer_Configuration;
        configuration.waveform = .SAWTOOTH;
        configuration.filter.type = .LOWPASS;
        configuration.filter.cutoff_frequency_hertz = 2000.0;
        configuration.filter.resonance = 0.2;
        configuration.envelope.attack_milliseconds = 5.0;
        configuration.envelope.decay_milliseconds = 20.0;
        configuration.envelope.sustain_level = 0.5;
        configuration.envelope.release_milliseconds = 20.0;
        configuration.gain = 0.8;

        voice: Synthesizer_Voice;
        initialize_synthesizer_voice(*voice, configuration, 44100);
        expect_true(!is_synthesizer_voice_active(*voice));

        trigger_synthesizer_note_on(*voice, 69, 1.0);
        expect_true(is_synthesizer_voice_active(*voice));
        expect_near(voice.frequency_hertz, 440.0, 0.001);

        rendered_samples: [1000] float;
        render_synthesizer_block(*voice, rendered_samples);

        has_non_zero_sample := false;
        sample_index := 0;
        while sample_index < rendered_samples.count {
            sample := rendered_samples[sample_index];
            expect_true(sample >= -1.0 && sample <= 1.0);
            if abs(sample) > 0.01 {
                has_non_zero_sample = true;
            }
            sample_index += 1;
        }
        expect_true(has_non_zero_sample);

        trigger_synthesizer_note_off(*voice);

        release_sample_index := 0;
        while release_sample_index < 3000 {
            render_synthesizer_sample(*voice);
            release_sample_index += 1;
        }

        expect_true(!is_synthesizer_voice_active(*voice));

        reset_synthesizer_voice(*voice);
        expect_true(!is_synthesizer_voice_active(*voice));
        expect_equals(voice.oscillator_phase, 0.0);
    });

    test("white_and_pink_noise_generation", () {
        seed: u32 = 1234567;
        state_0: float = 0.0;
        state_1: float = 0.0;
        state_2: float = 0.0;

        sample_index := 0;
        has_non_zero_white := false;
        has_non_zero_pink := false;

        while sample_index < 1000 {
            white_sample := generate_white_noise_sample(*seed);
            expect_true(white_sample >= -1.0 && white_sample <= 1.0);
            if abs(white_sample) > 0.01 {
                has_non_zero_white = true;
            }

            pink_sample := generate_pink_noise_sample(*seed, *state_0, *state_1, *state_2);
            expect_true(pink_sample >= -1.5 && pink_sample <= 1.5);
            if abs(pink_sample) > 0.01 {
                has_non_zero_pink = true;
            }

            sample_index += 1;
        }

        expect_true(has_non_zero_white);
        expect_true(has_non_zero_pink);
    });

    test("calculate_detuned_frequency", () {
        expect_near(calculate_detuned_frequency(440.0, 0, 0.0), 440.0, 0.001);
        expect_near(calculate_detuned_frequency(440.0, 12, 0.0), 880.0, 0.001);
        expect_near(calculate_detuned_frequency(440.0, -12, 0.0), 220.0, 0.001);
        expect_near(calculate_detuned_frequency(440.0, 7, 0.0), 659.255, 0.01);
        expect_near(calculate_detuned_frequency(440.0, 0, 100.0), 466.164, 0.01);
    });

    test("dual_oscillator_rendering_and_noise_layer", () {
        configuration: Synthesizer_Configuration;
        configuration.waveform = .SAWTOOTH;
        configuration.oscillator_2_enabled = true;
        configuration.oscillator_2_waveform = .SQUARE;
        configuration.oscillator_2_semitones = -12;
        configuration.oscillator_2_cents = 10.0;
        configuration.oscillator_mix = 0.5;
        configuration.noise_level = 0.1;
        configuration.noise_type = .PINK_NOISE;
        configuration.envelope.attack_milliseconds = 2.0;
        configuration.envelope.decay_milliseconds = 50.0;
        configuration.envelope.sustain_level = 0.8;
        configuration.envelope.release_milliseconds = 50.0;
        configuration.gain = 0.9;

        voice: Synthesizer_Voice;
        initialize_synthesizer_voice(*voice, configuration, 44100);

        trigger_synthesizer_note_on(*voice, 60, 1.0);
        expect_true(is_synthesizer_voice_active(*voice));

        sample_index := 0;
        has_non_zero_sample := false;
        has_glitch := false;

        while sample_index < 1000 {
            sample_value := render_synthesizer_sample(*voice);
            is_nan_value, is_inf_value := is_nan_is_inf(sample_value);
            if is_nan_value || is_inf_value {
                has_glitch = true;
            }
            if abs(sample_value) > 0.01 {
                has_non_zero_sample = true;
            }
            sample_index += 1;
        }

        expect_true(!has_glitch);
        expect_true(has_non_zero_sample);
    });

    test("synthesizer_parser_dual_oscillator_and_noise_arguments", () {
        song_text := "[project]\nname = \"Synth Test\"\nbpm = 120\ntime_signature = 4/4\nbars = 1\n\n[instruments]\nlead = synth(wave=\"saw\", wave2=\"square\", osc2_transpose=-12, osc2_tune=15, mix=0.4, noise=\"pink\", noise_level=0.2)\n\n[pattern melody]\nC4 step=0 len=1 vel=1.0\n\n[mixer]\ntrack 1: gain = 1.0, pan = 0.0, output = master\nmaster: gain = 1.0, limiter = on\n\n[channel_routing]\nlead -> track 1\n\n[arrangement]\nbar 1: melody\n";

        specification, parse_success, _ := parse_song(song_text, check_samples_on_disk = false);
        expect_true(parse_success);

        instrument, instrument_found := find_instrument(*specification, "lead");
        expect_true(instrument_found);
        expect_equals(instrument.synthesizer.waveform, Waveform_Type.SAWTOOTH);
        expect_true(instrument.synthesizer.oscillator_2_enabled);
        expect_equals(instrument.synthesizer.oscillator_2_waveform, Waveform_Type.SQUARE);
        expect_equals(instrument.synthesizer.oscillator_2_semitones, -12);
        expect_near(instrument.synthesizer.oscillator_2_cents, 15.0, 0.001);
        expect_near(instrument.synthesizer.oscillator_mix, 0.4, 0.001);
        expect_equals(instrument.synthesizer.noise_type, Waveform_Type.PINK_NOISE);
        expect_near(instrument.synthesizer.noise_level, 0.2, 0.001);
    });

    test("stereo_unison_renders_multiple_voices_with_stereo_spread", () {
        configuration: Synthesizer_Configuration;
        configuration.waveform = .SAWTOOTH;
        configuration.unison_voices = 4;
        configuration.unison_detune = 20.0;
        configuration.unison_spread = 1.0;
        configuration.envelope.attack_milliseconds = 2.0;
        configuration.envelope.decay_milliseconds = 50.0;
        configuration.envelope.sustain_level = 0.8;
        configuration.envelope.release_milliseconds = 50.0;

        voice: Synthesizer_Voice;
        initialize_synthesizer_voice(*voice, configuration, 44100);
        trigger_synthesizer_note_on(*voice, 60, 1.0);

        sample_index := 0;
        channel_difference_accumulated: float = 0.0;
        left_energy_accumulated: float = 0.0;
        right_energy_accumulated: float = 0.0;
        has_glitch := false;

        while sample_index < 1000 {
            left_sample, right_sample := render_synthesizer_frame(*voice);
            is_nan_left, is_inf_left := is_nan_is_inf(left_sample);
            is_nan_right, is_inf_right := is_nan_is_inf(right_sample);
            if is_nan_left || is_inf_left || is_nan_right || is_inf_right {
                has_glitch = true;
            }

            channel_difference_accumulated += abs(left_sample - right_sample);
            left_energy_accumulated += left_sample * left_sample;
            right_energy_accumulated += right_sample * right_sample;

            sample_index += 1;
        }

        expect_true(!has_glitch);
        expect_true(left_energy_accumulated > 1.0);
        expect_true(right_energy_accumulated > 1.0);
        expect_true(channel_difference_accumulated > 5.0);
    });

    test("stereo_unison_mono_spread_produces_identical_channels", () {
        configuration: Synthesizer_Configuration;
        configuration.waveform = .SAWTOOTH;
        configuration.unison_voices = 4;
        configuration.unison_detune = 20.0;
        configuration.unison_spread = 0.0;
        configuration.envelope.attack_milliseconds = 2.0;
        configuration.envelope.decay_milliseconds = 50.0;
        configuration.envelope.sustain_level = 0.8;
        configuration.envelope.release_milliseconds = 50.0;

        voice: Synthesizer_Voice;
        initialize_synthesizer_voice(*voice, configuration, 44100);
        trigger_synthesizer_note_on(*voice, 60, 1.0);

        sample_index := 0;
        maximum_difference: float = 0.0;

        while sample_index < 500 {
            left_sample, right_sample := render_synthesizer_frame(*voice);
            difference := abs(left_sample - right_sample);
            if difference > maximum_difference {
                maximum_difference = difference;
            }

            sample_index += 1;
        }

        expect_near(maximum_difference, 0.0, 0.0001);
    });

    test("synthesizer_parser_unison_arguments", () {
        song_text := "[project]\nname = \"Unison Test\"\nbpm = 120\ntime_signature = 4/4\nbars = 1\n\n[instruments]\nsupersaw = synth(wave=\"saw\", unison=7, detune=25.0, spread=0.85)\n\n[pattern melody]\nC4 step=0 len=1 vel=1.0\n\n[mixer]\ntrack 1: gain = 1.0, pan = 0.0, output = master\nmaster: gain = 1.0, limiter = on\n\n[channel_routing]\nsupersaw -> track 1\n\n[arrangement]\nbar 1: melody\n";

        specification, parse_success, _ := parse_song(song_text, check_samples_on_disk = false);
        expect_true(parse_success);

        instrument, instrument_found := find_instrument(*specification, "supersaw");
        expect_true(instrument_found);
        expect_equals(instrument.synthesizer.waveform, Waveform_Type.SAWTOOTH);
        expect_equals(instrument.synthesizer.unison_voices, 7);
        expect_near(instrument.synthesizer.unison_detune, 25.0, 0.001);
        expect_near(instrument.synthesizer.unison_spread, 0.85, 0.001);
    });

    test("filter_envelope_modulates_cutoff_dynamically", () {
        configuration: Synthesizer_Configuration;
        configuration.waveform = .SAWTOOTH;
        configuration.filter.type = .LOWPASS;
        configuration.filter.cutoff_frequency_hertz = 150.0;
        configuration.filter.resonance = 0.2;
        configuration.filter.envelope_amount = 0.8;
        configuration.filter.envelope.attack_milliseconds = 2.0;
        configuration.filter.envelope.decay_milliseconds = 15.0;
        configuration.filter.envelope.sustain_level = 0.0;
        configuration.filter.envelope.release_milliseconds = 10.0;
        configuration.envelope.attack_milliseconds = 1.0;
        configuration.envelope.decay_milliseconds = 100.0;
        configuration.envelope.sustain_level = 1.0;
        configuration.envelope.release_milliseconds = 100.0;

        voice: Synthesizer_Voice;
        initialize_synthesizer_voice(*voice, configuration, 44100);
        trigger_synthesizer_note_on(*voice, 60, 1.0);

        sample_index := 0;
        peak_derivative_energy: float = 0.0;
        settled_derivative_energy: float = 0.0;
        previous_sample: float = 0.0;

        while sample_index < 2000 {
            current_sample := render_synthesizer_sample(*voice);
            derivative := current_sample - previous_sample;
            previous_sample = current_sample;

            if sample_index >= 80 && sample_index < 200 {
                peak_derivative_energy += derivative * derivative;
            } else if sample_index >= 1200 && sample_index < 1320 {
                settled_derivative_energy += derivative * derivative;
            }

            sample_index += 1;
        }

        expect_true(peak_derivative_energy > settled_derivative_energy * 2.0);
    });

    test("filter_envelope_bipolar_negative_modulation", () {
        positive_configuration: Synthesizer_Configuration;
        positive_configuration.waveform = .SAWTOOTH;
        positive_configuration.filter.type = .LOWPASS;
        positive_configuration.filter.cutoff_frequency_hertz = 1000.0;
        positive_configuration.filter.envelope_amount = 0.7;
        positive_configuration.filter.envelope.attack_milliseconds = 1.0;
        positive_configuration.filter.envelope.decay_milliseconds = 50.0;
        positive_configuration.filter.envelope.sustain_level = 1.0;
        positive_configuration.filter.envelope.release_milliseconds = 50.0;
        positive_configuration.envelope.attack_milliseconds = 1.0;
        positive_configuration.envelope.decay_milliseconds = 50.0;
        positive_configuration.envelope.sustain_level = 1.0;
        positive_configuration.envelope.release_milliseconds = 50.0;

        negative_configuration := positive_configuration;
        negative_configuration.filter.envelope_amount = -0.7;

        positive_voice: Synthesizer_Voice;
        initialize_synthesizer_voice(*positive_voice, positive_configuration, 44100);
        trigger_synthesizer_note_on(*positive_voice, 60, 1.0);

        negative_voice: Synthesizer_Voice;
        initialize_synthesizer_voice(*negative_voice, negative_configuration, 44100);
        trigger_synthesizer_note_on(*negative_voice, 60, 1.0);

        sample_index := 0;
        positive_energy: float = 0.0;
        negative_energy: float = 0.0;

        while sample_index < 800 {
            positive_sample := render_synthesizer_sample(*positive_voice);
            negative_sample := render_synthesizer_sample(*negative_voice);
            if sample_index >= 150 {
                positive_energy += positive_sample * positive_sample;
                negative_energy += negative_sample * negative_sample;
            }

            sample_index += 1;
        }

        expect_true(positive_energy > negative_energy * 2.0);
    });

    test("synthesizer_parser_filter_envelope_arguments", () {
        song_text := "[project]\nname = \"Filter Env Test\"\nbpm = 120\ntime_signature = 4/4\nbars = 1\n\n[instruments]\npluck = synth(wave=\"saw\", filter=\"lowpass\", cutoff=400, res=0.35, env_amount=0.75, filter_attack=5, filter_decay=80, filter_sustain=0.2, filter_release=120)\n\n[pattern melody]\nC4 step=0 len=1 vel=1.0\n\n[mixer]\ntrack 1: gain = 1.0, pan = 0.0, output = master\nmaster: gain = 1.0, limiter = on\n\n[channel_routing]\npluck -> track 1\n\n[arrangement]\nbar 1: melody\n";

        specification, parse_success, _ := parse_song(song_text, check_samples_on_disk = false);
        expect_true(parse_success);

        instrument, instrument_found := find_instrument(*specification, "pluck");
        expect_true(instrument_found);
        expect_equals(instrument.synthesizer.filter.type, Filter_Type.LOWPASS);
        expect_near(instrument.synthesizer.filter.cutoff_frequency_hertz, 400.0, 0.001);
        expect_near(instrument.synthesizer.filter.resonance, 0.35, 0.001);
        expect_near(instrument.synthesizer.filter.envelope_amount, 0.75, 0.001);
        expect_near(instrument.synthesizer.filter.envelope.attack_milliseconds, 5.0, 0.001);
        expect_near(instrument.synthesizer.filter.envelope.decay_milliseconds, 80.0, 0.001);
        expect_near(instrument.synthesizer.filter.envelope.sustain_level, 0.2, 0.001);
        expect_near(instrument.synthesizer.filter.envelope.release_milliseconds, 120.0, 0.001);
    });

    test("lfo_tempo_sync_rate_calculation", () {
        configuration: LFO_Configuration;
        configuration.is_tempo_synced = false;
        configuration.rate_hertz = 3.5;
        expect_near(calculate_lfo_frequency_hertz(configuration, 120.0), 3.5, 0.001);

        configuration.is_tempo_synced = true;
        configuration.tempo_sync_numerator = 1;
        configuration.tempo_sync_denominator = 4;
        configuration.is_triplet = false;
        expect_near(calculate_lfo_frequency_hertz(configuration, 120.0), 2.0, 0.001);
        expect_near(calculate_lfo_frequency_hertz(configuration, 60.0), 1.0, 0.001);

        configuration.tempo_sync_denominator = 8;
        expect_near(calculate_lfo_frequency_hertz(configuration, 120.0), 4.0, 0.001);

        configuration.tempo_sync_denominator = 16;
        expect_near(calculate_lfo_frequency_hertz(configuration, 120.0), 8.0, 0.001);

        configuration.tempo_sync_denominator = 1;
        expect_near(calculate_lfo_frequency_hertz(configuration, 120.0), 0.5, 0.001);

        configuration.tempo_sync_denominator = 4;
        configuration.is_triplet = true;
        expect_near(calculate_lfo_frequency_hertz(configuration, 120.0), 3.0, 0.001);
    });

    test("lfo_pitch_vibrato_modulation", () {
        unmodulated_configuration: Synthesizer_Configuration;
        unmodulated_configuration.waveform = .SINE;
        unmodulated_configuration.envelope.attack_milliseconds = 2.0;
        unmodulated_configuration.envelope.decay_milliseconds = 50.0;
        unmodulated_configuration.envelope.sustain_level = 1.0;
        unmodulated_configuration.envelope.release_milliseconds = 50.0;

        vibrato_configuration := unmodulated_configuration;
        vibrato_configuration.lfo_1.enabled = true;
        vibrato_configuration.lfo_1.waveform = .SINE;
        vibrato_configuration.lfo_1.destination = .PITCH;
        vibrato_configuration.lfo_1.rate_hertz = 5.0;
        vibrato_configuration.lfo_1.amount = 1.0;

        unmodulated_voice: Synthesizer_Voice;
        initialize_synthesizer_voice(*unmodulated_voice, unmodulated_configuration, 44100);
        trigger_synthesizer_note_on(*unmodulated_voice, 60, 1.0);

        vibrato_voice: Synthesizer_Voice;
        initialize_synthesizer_voice(*vibrato_voice, vibrato_configuration, 44100);
        trigger_synthesizer_note_on(*vibrato_voice, 60, 1.0);

        sample_index := 0;
        difference_accumulated: float = 0.0;
        has_glitch := false;

        while sample_index < 1000 {
            unmodulated_sample := render_synthesizer_sample(*unmodulated_voice);
            vibrato_sample := render_synthesizer_sample(*vibrato_voice);

            is_nan_sample, is_inf_sample := is_nan_is_inf(vibrato_sample);
            if is_nan_sample || is_inf_sample {
                has_glitch = true;
            }

            difference_accumulated += abs(vibrato_sample - unmodulated_sample);
            sample_index += 1;
        }

        expect_true(!has_glitch);
        expect_true(difference_accumulated > 10.0);
    });

    test("lfo_filter_cutoff_modulation", () {
        configuration: Synthesizer_Configuration;
        configuration.waveform = .SAWTOOTH;
        configuration.filter.type = .LOWPASS;
        configuration.filter.cutoff_frequency_hertz = 500.0;
        configuration.filter.resonance = 0.5;
        configuration.envelope.attack_milliseconds = 1.0;
        configuration.envelope.decay_milliseconds = 50.0;
        configuration.envelope.sustain_level = 1.0;
        configuration.envelope.release_milliseconds = 50.0;
        configuration.lfo_1.enabled = true;
        configuration.lfo_1.waveform = .SQUARE;
        configuration.lfo_1.destination = .FILTER_CUTOFF;
        configuration.lfo_1.rate_hertz = 10.0;
        configuration.lfo_1.amount = 0.5;

        voice: Synthesizer_Voice;
        initialize_synthesizer_voice(*voice, configuration, 44100);
        trigger_synthesizer_note_on(*voice, 60, 1.0);

        sample_index := 0;
        first_half_energy: float = 0.0;
        second_half_energy: float = 0.0;

        while sample_index < 4410 {
            sample_value := render_synthesizer_sample(*voice);
            if sample_index >= 500 && sample_index < 2000 {
                first_half_energy += sample_value * sample_value;
            } else if sample_index >= 2700 && sample_index < 4200 {
                second_half_energy += sample_value * sample_value;
            }

            sample_index += 1;
        }

        expect_true(first_half_energy > second_half_energy * 1.5);
    });

    test("lfo_auto_pan_modulation", () {
        configuration: Synthesizer_Configuration;
        configuration.waveform = .SAWTOOTH;
        configuration.envelope.attack_milliseconds = 1.0;
        configuration.envelope.decay_milliseconds = 50.0;
        configuration.envelope.sustain_level = 1.0;
        configuration.envelope.release_milliseconds = 50.0;
        configuration.lfo_1.enabled = true;
        configuration.lfo_1.waveform = .SQUARE;
        configuration.lfo_1.destination = .PAN;
        configuration.lfo_1.rate_hertz = 10.0;
        configuration.lfo_1.amount = 1.0;

        voice: Synthesizer_Voice;
        initialize_synthesizer_voice(*voice, configuration, 44100);
        trigger_synthesizer_note_on(*voice, 60, 1.0);

        sample_index := 0;
        first_half_left_energy: float = 0.0;
        first_half_right_energy: float = 0.0;
        second_half_left_energy: float = 0.0;
        second_half_right_energy: float = 0.0;

        while sample_index < 4410 {
            left_sample, right_sample := render_synthesizer_frame(*voice);
            if sample_index >= 500 && sample_index < 2000 {
                first_half_left_energy += left_sample * left_sample;
                first_half_right_energy += right_sample * right_sample;
            } else if sample_index >= 2700 && sample_index < 4200 {
                second_half_left_energy += left_sample * left_sample;
                second_half_right_energy += right_sample * right_sample;
            }

            sample_index += 1;
        }

        expect_true(first_half_right_energy > 1.0);
        expect_near(first_half_left_energy, 0.0, 0.001);
        expect_true(second_half_left_energy > 1.0);
        expect_near(second_half_right_energy, 0.0, 0.001);
    });

    test("lfo_volume_tremolo_modulation", () {
        configuration: Synthesizer_Configuration;
        configuration.waveform = .SAWTOOTH;
        configuration.envelope.attack_milliseconds = 1.0;
        configuration.envelope.decay_milliseconds = 50.0;
        configuration.envelope.sustain_level = 1.0;
        configuration.envelope.release_milliseconds = 50.0;
        configuration.lfo_1.enabled = true;
        configuration.lfo_1.waveform = .SQUARE;
        configuration.lfo_1.destination = .VOLUME;
        configuration.lfo_1.rate_hertz = 10.0;
        configuration.lfo_1.amount = 1.0;

        voice: Synthesizer_Voice;
        initialize_synthesizer_voice(*voice, configuration, 44100);
        trigger_synthesizer_note_on(*voice, 60, 1.0);

        sample_index := 0;
        first_half_energy: float = 0.0;
        second_half_energy: float = 0.0;

        while sample_index < 4410 {
            sample_value := render_synthesizer_sample(*voice);
            if sample_index >= 500 && sample_index < 2000 {
                first_half_energy += sample_value * sample_value;
            } else if sample_index >= 2700 && sample_index < 4200 {
                second_half_energy += sample_value * sample_value;
            }

            sample_index += 1;
        }

        expect_true(first_half_energy > 1.0);
        expect_near(second_half_energy, 0.0, 0.001);
    });

    test("synthesizer_parser_lfo_arguments", () {
        song_text := "[project]\nname = \"LFO Parser Test\"\nbpm = 120\ntime_signature = 4/4\nbars = 1\n\n[instruments]\nlead = synth(wave=\"saw\", lfo1_wave=\"triangle\", lfo1_dest=\"filter\", lfo1_rate=\"1/8\", lfo1_amount=0.6, lfo1_retrigger=\"off\", lfo2_wave=\"sine\", lfo2_dest=\"pan\", lfo2_speed=4.5, lfo2_depth=0.8)\n\n[pattern melody]\nC4 step=0 len=1 vel=1.0\n\n[mixer]\ntrack 1: gain = 1.0, pan = 0.0, output = master\nmaster: gain = 1.0, limiter = on\n\n[channel_routing]\nlead -> track 1\n\n[arrangement]\nbar 1: melody\n";

        specification, parse_success, _ := parse_song(song_text, check_samples_on_disk = false);
        expect_true(parse_success);

        instrument, instrument_found := find_instrument(*specification, "lead");
        expect_true(instrument_found);
        expect_true(instrument.synthesizer.lfo_1.enabled);
        expect_equals(instrument.synthesizer.lfo_1.waveform, LFO_Waveform.TRIANGLE);
        expect_equals(instrument.synthesizer.lfo_1.destination, LFO_Destination.FILTER_CUTOFF);
        expect_true(instrument.synthesizer.lfo_1.is_tempo_synced);
        expect_equals(instrument.synthesizer.lfo_1.tempo_sync_numerator, 1);
        expect_equals(instrument.synthesizer.lfo_1.tempo_sync_denominator, 8);
        expect_near(instrument.synthesizer.lfo_1.amount, 0.6, 0.001);
        expect_true(!instrument.synthesizer.lfo_1.retrigger);

        expect_true(instrument.synthesizer.lfo_2.enabled);
        expect_equals(instrument.synthesizer.lfo_2.waveform, LFO_Waveform.SINE);
        expect_equals(instrument.synthesizer.lfo_2.destination, LFO_Destination.PAN);
        expect_true(!instrument.synthesizer.lfo_2.is_tempo_synced);
        expect_near(instrument.synthesizer.lfo_2.rate_hertz, 4.5, 0.001);
        expect_near(instrument.synthesizer.lfo_2.amount, 0.8, 0.001);
    });

    test("portamento_exponential_pitch_glide", () {
        configuration: Synthesizer_Configuration;
        configuration.waveform = .SAWTOOTH;
        configuration.is_monophonic = true;
        configuration.portamento_milliseconds = 50.0;
        configuration.envelope.attack_milliseconds = 1.0;
        configuration.envelope.decay_milliseconds = 1000.0;
        configuration.envelope.sustain_level = 1.0;
        configuration.envelope.release_milliseconds = 1000.0;

        voice: Synthesizer_Voice;
        initialize_synthesizer_voice(*voice, configuration, 44100);

        trigger_synthesizer_note_on(*voice, 36, 1.0);
        initial_frequency := midi_to_hertz(36);
        expect_near(voice.frequency_hertz, initial_frequency, 0.01);
        expect_near(voice.target_frequency_hertz, initial_frequency, 0.01);

        target_frequency := midi_to_hertz(48);
        trigger_synthesizer_note_glide(*voice, 48, 1.0);
        expect_near(voice.target_frequency_hertz, target_frequency, 0.01);
        expect_near(voice.frequency_hertz, initial_frequency, 0.01);

        sample_index := 0;
        while sample_index < 500 {
            render_synthesizer_sample(*voice);
            sample_index += 1;
        }

        expect_true(voice.frequency_hertz > initial_frequency + 10.0);
        expect_true(voice.frequency_hertz < target_frequency - 5.0);

        while sample_index < 3000 {
            render_synthesizer_sample(*voice);
            sample_index += 1;
        }

        expect_near(voice.frequency_hertz, target_frequency, 0.05);
    });

    test("monophonic_voice_reuse_and_legato", () {
        voice_manager: Voice_Manager;
        initialize_voice_manager(*voice_manager, 44100);

        configuration: Synthesizer_Configuration;
        configuration.waveform = .SAWTOOTH;
        configuration.is_monophonic = true;
        configuration.portamento_milliseconds = 40.0;
        configuration.legato = true;
        configuration.envelope.attack_milliseconds = 5.0;
        configuration.envelope.decay_milliseconds = 1000.0;
        configuration.envelope.sustain_level = 0.8;
        configuration.envelope.release_milliseconds = 500.0;

        slot_1 := trigger_synthesizer_note(*voice_manager, "lead", 1, configuration, 40, 1.0);
        expect_equals(count_active_voices(*voice_manager), 1);

        sample_index := 0;
        while sample_index < 1000 {
            render_voice_sample(slot_1);
            sample_index += 1;
        }

        envelope_level_before_glide := slot_1.synthesizer_voice.amplitude_envelope.current_level;
        expect_true(envelope_level_before_glide > 0.7);

        slot_2 := trigger_synthesizer_note(*voice_manager, "lead", 1, configuration, 52, 0.9);
        expect_equals(count_active_voices(*voice_manager), 1);
        expect_true(slot_1 == slot_2);

        expect_near(slot_2.synthesizer_voice.amplitude_envelope.current_level, envelope_level_before_glide, 0.05);
        expect_near(slot_2.synthesizer_voice.target_frequency_hertz, midi_to_hertz(52), 0.01);
    });

    test("synthesizer_parser_portamento_and_monophonic_arguments", () {
        song_text := "[project]\nname = \"Portamento Test\"\nbpm = 120\ntime_signature = 4/4\nbars = 1\n\n[instruments]\nbass = synth(wave=\"saw\", glide=60ms, mono=on, legato=on)\nlead = synth(wave=\"square\", portamento=\"1/16\", legato=off)\n\n[pattern melody]\nC4 step=0 len=1 vel=1.0\n\n[mixer]\ntrack 1: gain = 1.0, pan = 0.0, output = master\nmaster: gain = 1.0, limiter = on\n\n[channel_routing]\nbass -> track 1\nlead -> track 1\n\n[arrangement]\nbar 1: melody\n";

        specification, parse_success, _ := parse_song(song_text, check_samples_on_disk = false);
        expect_true(parse_success);

        bass, bass_found := find_instrument(*specification, "bass");
        expect_true(bass_found);
        expect_true(bass.synthesizer.is_monophonic);
        expect_near(bass.synthesizer.portamento_milliseconds, 60.0, 0.001);
        expect_true(bass.synthesizer.legato);
        expect_true(!bass.synthesizer.is_portamento_tempo_synced);

        lead, lead_found := find_instrument(*specification, "lead");
        expect_true(lead_found);
        expect_true(lead.synthesizer.is_monophonic);
        expect_true(lead.synthesizer.is_portamento_tempo_synced);
        expect_equals(lead.synthesizer.portamento_tempo_sync_numerator, 1);
        expect_equals(lead.synthesizer.portamento_tempo_sync_denominator, 16);
        expect_true(!lead.synthesizer.legato);
    });

    test("velocity_scales_amplifier_gain_and_dynamic_envelope", () {
        voice_manager: Voice_Manager;
        initialize_voice_manager(*voice_manager, 44100);

        configuration_with_velocity_gain: Synthesizer_Configuration;
        configuration_with_velocity_gain.waveform = .SAWTOOTH;
        configuration_with_velocity_gain.gain = 1.0;
        configuration_with_velocity_gain.velocity_to_gain = 1.0;
        configuration_with_velocity_gain.envelope.attack_milliseconds = 2.0;
        configuration_with_velocity_gain.envelope.decay_milliseconds = 100.0;
        configuration_with_velocity_gain.envelope.sustain_level = 1.0;

        full_velocity_slot := trigger_synthesizer_note(*voice_manager, "synth", 1, configuration_with_velocity_gain, 60, 1.0);
        half_velocity_slot := trigger_synthesizer_note(*voice_manager, "synth", 2, configuration_with_velocity_gain, 60, 0.5);

        sample_counter := 0;
        full_max_amplitude: float = 0.0;
        half_max_amplitude: float = 0.0;

        while sample_counter < 300 {
            full_sample := render_voice_sample(full_velocity_slot);
            half_sample := render_voice_sample(half_velocity_slot);

            if abs(full_sample) > full_max_amplitude full_max_amplitude = abs(full_sample);
            if abs(half_sample) > half_max_amplitude half_max_amplitude = abs(half_sample);

            sample_counter += 1;
        }

        expect_true(full_max_amplitude > 0.8);
        expect_near(half_max_amplitude, full_max_amplitude * 0.5, 0.05);

        configuration_without_velocity_gain: Synthesizer_Configuration;
        configuration_without_velocity_gain.waveform = .SAWTOOTH;
        configuration_without_velocity_gain.gain = 1.0;
        configuration_without_velocity_gain.velocity_to_gain = 0.0;
        configuration_without_velocity_gain.envelope.attack_milliseconds = 2.0;
        configuration_without_velocity_gain.envelope.decay_milliseconds = 100.0;
        configuration_without_velocity_gain.envelope.sustain_level = 1.0;

        fixed_full_slot := trigger_synthesizer_note(*voice_manager, "synth", 3, configuration_without_velocity_gain, 60, 1.0);
        fixed_half_slot := trigger_synthesizer_note(*voice_manager, "synth", 4, configuration_without_velocity_gain, 60, 0.3);

        sample_counter = 0;
        fixed_full_max: float = 0.0;
        fixed_half_max: float = 0.0;

        while sample_counter < 300 {
            full_sample := render_voice_sample(fixed_full_slot);
            half_sample := render_voice_sample(fixed_half_slot);

            if abs(full_sample) > fixed_full_max fixed_full_max = abs(full_sample);
            if abs(half_sample) > fixed_half_max fixed_half_max = abs(half_sample);

            sample_counter += 1;
        }

        expect_near(fixed_full_max, fixed_half_max, 0.02);
    });

    test("velocity_modulates_filter_envelope_and_cutoff", () {
        configuration: Synthesizer_Configuration;
        configuration.waveform = .SAWTOOTH;
        configuration.filter.type = .LOWPASS;
        configuration.filter.cutoff_frequency_hertz = 500.0;
        configuration.filter.envelope_amount = 0.8;
        configuration.filter.velocity_to_envelope = 1.0;
        configuration.filter.velocity_to_cutoff = 1.5;
        configuration.filter.resonance = 0.2;
        configuration.envelope.attack_milliseconds = 1.0;
        configuration.envelope.decay_milliseconds = 50.0;
        configuration.envelope.sustain_level = 0.8;
        configuration.filter.envelope.attack_milliseconds = 1.0;
        configuration.filter.envelope.decay_milliseconds = 50.0;
        configuration.filter.envelope.sustain_level = 0.8;

        voice_manager: Voice_Manager;
        initialize_voice_manager(*voice_manager, 44100);

        accent_voice_slot := trigger_synthesizer_note(*voice_manager, "synth", 1, configuration, 60, ACCENT_NOTE_VELOCITY);
        ghost_voice_slot := trigger_synthesizer_note(*voice_manager, "synth", 2, configuration, 60, GHOST_NOTE_VELOCITY);

        sample_index := 0;
        accent_energy: float = 0.0;
        ghost_energy: float = 0.0;

        while sample_index < 400 {
            accent_sample := render_voice_sample(accent_voice_slot);
            ghost_sample := render_voice_sample(ghost_voice_slot);

            accent_energy += accent_sample * accent_sample;
            ghost_energy += ghost_sample * ghost_sample;

            sample_index += 1;
        }

        expect_true(accent_energy > ghost_energy * 2.0);
    });

    test("synthesizer_parser_velocity_mapping_arguments", () {
        song_text := "[project]\nname = \"Velocity Mapping Test\"\nbpm = 120\ntime_signature = 4/4\nbars = 1\n\n[instruments]\nlead = synth(wave=\"saw\", filter=\"lowpass\", cutoff=600, vel_to_filter=80%, vel_to_cutoff=1.5, vel_to_res=0.4, vel_to_gain=0.75)\n\n[pattern melody]\nC4 step=0 len=1 vel=1.0\n\n[mixer]\ntrack 1: gain = 1.0, pan = 0.0, output = master\nmaster: gain = 1.0, limiter = on\n\n[channel_routing]\nlead -> track 1\n\n[arrangement]\nbar 1: melody\n";

        specification, parse_success, _ := parse_song(song_text, check_samples_on_disk = false);
        expect_true(parse_success);

        lead, lead_found := find_instrument(*specification, "lead");
        expect_true(lead_found);
        expect_near(lead.synthesizer.filter.velocity_to_envelope, 0.80, 0.001);
        expect_near(lead.synthesizer.filter.velocity_to_cutoff, 1.5, 0.001);
        expect_near(lead.synthesizer.filter.velocity_to_resonance, 0.40, 0.001);
        expect_near(lead.synthesizer.velocity_to_gain, 0.75, 0.001);
    });
}

