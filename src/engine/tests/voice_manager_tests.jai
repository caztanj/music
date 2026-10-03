voice_manager_tests :: () {
    test("voice manager initialization", () {
        voice_manager: Voice_Manager;
        initialize_voice_manager(*voice_manager, 44100);

        expect_equals(count_active_voices(*voice_manager), 0);
        expect_equals(voice_manager.total_rendered_samples, 0);
    });

    test("trigger and render synthesizer note", () {
        voice_manager: Voice_Manager;
        initialize_voice_manager(*voice_manager, 44100);

        configuration: Synthesizer_Configuration;
        configuration.waveform = .SAWTOOTH;
        configuration.envelope.attack_milliseconds = 2.0;
        configuration.envelope.decay_milliseconds = 10.0;
        configuration.envelope.sustain_level = 0.5;
        configuration.envelope.release_milliseconds = 10.0;

        slot := trigger_synthesizer_note(*voice_manager, "lead", 1, configuration, 60, 1.0);
        expect_equals(count_active_voices(*voice_manager), 1);
        expect_equals(slot.kind, Voice_Kind.SYNTHESIZER);
        expect_equals(slot.instrument_name, "lead");
        expect_equals(slot.mixer_track_index, 1);

        left_buffer: [100] float;
        right_buffer: [100] float;
        render_voices_into_buffer(*voice_manager, left_buffer, right_buffer);

        has_sound := false;
        sample_index := 0;
        while sample_index < left_buffer.count {
            if abs(left_buffer[sample_index]) > 0.01 {
                has_sound = true;
            }
            sample_index += 1;
        }
        expect_true(has_sound);

        trigger_note_off(*voice_manager, "lead", 60);

        drain_index := 0;
        while drain_index < 2000 {
            render_voices_into_buffer(*voice_manager, left_buffer, right_buffer);
            if count_active_voices(*voice_manager) == 0 {
                break;
            }
            drain_index += 100;
        }

        expect_equals(count_active_voices(*voice_manager), 0);
    });

    test("trigger and render sampler note", () {
        voice_manager: Voice_Manager;
        initialize_voice_manager(*voice_manager, 44100);

        raw_samples := NewArray(20, float);
        sample_index := 0;
        while sample_index < raw_samples.count {
            raw_samples[sample_index] = 0.6;
            sample_index += 1;
        }

        buffer := create_audio_sample_buffer(raw_samples, 2, 44100, 60);

        slot := trigger_sampler_note(*voice_manager, "kick", 2, *buffer, 60, 1.0, is_one_shot = true, gain = 1.0);
        expect_equals(count_active_voices(*voice_manager), 1);
        expect_equals(slot.kind, Voice_Kind.SAMPLER);
        expect_equals(slot.mixer_track_index, 2);

        left_buffer: [30] float;
        right_buffer: [30] float;
        render_track_voices_into_buffer(*voice_manager, 2, left_buffer, right_buffer);

        expect_near(left_buffer[0], 0.6, 0.001);
        expect_near(right_buffer[0], 0.6, 0.001);
        expect_equals(count_active_voices(*voice_manager), 0);
    });

    test("polyphonic concurrent voices", () {
        voice_manager: Voice_Manager;
        initialize_voice_manager(*voice_manager, 44100);

        configuration: Synthesizer_Configuration;
        configuration.waveform = .SINE;
        configuration.envelope.attack_milliseconds = 5.0;
        configuration.envelope.decay_milliseconds = 20.0;
        configuration.envelope.sustain_level = 0.8;
        configuration.envelope.release_milliseconds = 20.0;

        trigger_synthesizer_note(*voice_manager, "lead", 1, configuration, 60, 1.0);
        trigger_synthesizer_note(*voice_manager, "lead", 1, configuration, 64, 1.0);
        trigger_synthesizer_note(*voice_manager, "lead", 1, configuration, 67, 1.0);

        expect_equals(count_active_voices(*voice_manager), 3);

        left_buffer: [50] float;
        right_buffer: [50] float;
        render_voices_into_buffer(*voice_manager, left_buffer, right_buffer);

        expect_equals(count_active_voices(*voice_manager), 3);

        stop_all_voices(*voice_manager);
        expect_equals(count_active_voices(*voice_manager), 0);
    });

    test("deterministic voice stealing under high load", () {
        voice_manager: Voice_Manager;
        initialize_voice_manager(*voice_manager, 44100);

        configuration: Synthesizer_Configuration;
        configuration.waveform = .SAWTOOTH;
        configuration.envelope.attack_milliseconds = 1.0;
        configuration.envelope.decay_milliseconds = 10.0;
        configuration.envelope.sustain_level = 0.7;
        configuration.envelope.release_milliseconds = 50.0;

        voice_index := 0;
        while voice_index < MAXIMUM_VOICES {
            midi_note := cast(s32) (40 + (voice_index % 40));
            trigger_synthesizer_note(*voice_manager, "synth", 1, configuration, midi_note, 0.5);
            voice_index += 1;
        }

        expect_equals(count_active_voices(*voice_manager), MAXIMUM_VOICES);

        trigger_note_off(*voice_manager, "synth", 40);

        new_slot := trigger_synthesizer_note(*voice_manager, "solo", 1, configuration, 80, 1.0);
        expect_true(new_slot != null);
        expect_equals(new_slot.instrument_name, "solo");
        expect_equals(new_slot.midi_note_number, 80);
        expect_equals(count_active_voices(*voice_manager), MAXIMUM_VOICES);
    });
}
