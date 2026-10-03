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
}
