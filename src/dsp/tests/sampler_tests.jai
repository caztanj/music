sampler_tests :: () {
    test("audio sample buffer retrieval", () {
        raw_samples := NewArray(4, float);
        raw_samples[0] = 0.2;
        raw_samples[1] = -0.2;
        raw_samples[2] = 0.8;
        raw_samples[3] = -0.8;

        buffer := create_audio_sample_buffer(raw_samples, 2, 44100, 60);
        expect_equals(buffer.frame_count, 2);
        expect_near(get_sample_from_buffer(*buffer, 0, 0), 0.2, 0.0001);
        expect_near(get_sample_from_buffer(*buffer, 0, 1), -0.2, 0.0001);
        expect_near(get_sample_from_buffer(*buffer, 1, 0), 0.8, 0.0001);
        expect_near(get_sample_from_buffer(*buffer, 1, 1), -0.8, 0.0001);
        expect_equals(get_sample_from_buffer(*buffer, 2, 0), 0.0);
    });

    test("sampler one-shot playback mode", () {
        raw_samples := NewArray(10, float);
        sample_index := 0;
        while sample_index < raw_samples.count {
            raw_samples[sample_index] = 0.5;
            sample_index += 1;
        }

        buffer := create_audio_sample_buffer(raw_samples, 1, 44100, 60);

        voice: Sampler_Voice;
        initialize_sampler_voice(*voice, 44100);
        expect_true(!is_sampler_voice_active(*voice));

        trigger_sampler_note_on(*voice, *buffer, 60, 1.0, is_one_shot = true, gain = 1.0);
        expect_true(is_sampler_voice_active(*voice));
        expect_near(cast(float) voice.playback_speed, 1.0, 0.001);

        trigger_sampler_note_off(*voice);
        expect_true(is_sampler_voice_active(*voice));

        render_index := 0;
        while render_index < 12 {
            render_sampler_sample(*voice);
            render_index += 1;
        }

        expect_true(!is_sampler_voice_active(*voice));
    });

    test("sampler pitch resampling speed", () {
        raw_samples := NewArray(4, float);
        buffer := create_audio_sample_buffer(raw_samples, 1, 44100, 60);

        voice: Sampler_Voice;
        initialize_sampler_voice(*voice, 44100);

        trigger_sampler_note_on(*voice, *buffer, 72, 1.0, is_one_shot = true, gain = 1.0);
        expect_near(cast(float) voice.playback_speed, 2.0, 0.001);

        trigger_sampler_note_on(*voice, *buffer, 48, 1.0, is_one_shot = true, gain = 1.0);
        expect_near(cast(float) voice.playback_speed, 0.5, 0.001);

        trigger_sampler_note_on(*voice, *buffer, 60, 1.0, is_one_shot = true, gain = 1.0);
        expect_near(cast(float) voice.playback_speed, 1.0, 0.001);
    });

    test("sampler linear interpolation accuracy", () {
        raw_samples := NewArray(2, float);
        raw_samples[0] = 0.0;
        raw_samples[1] = 1.0;

        buffer := create_audio_sample_buffer(raw_samples, 1, 44100, 60);

        voice: Sampler_Voice;
        initialize_sampler_voice(*voice, 44100);
        trigger_sampler_note_on(*voice, *buffer, 60, 1.0, is_one_shot = true, gain = 1.0);

        voice.playhead_frame = 0.5;
        sample := render_sampler_sample(*voice);
        expect_near(sample, 0.5, 0.001);
    });

    test("load wav file roundtrip", () {
        test_file_path := "test_sampler_roundtrip.wav";
        original_samples := NewArray(100, float);
        sample_index := 0;
        while sample_index < original_samples.count {
            original_samples[sample_index] = cast(float) sin(cast(float64) sample_index * 0.1);
            sample_index += 1;
        }

        write_success := write_wav_file_16_bit(test_file_path, original_samples, channel_count = 2, sample_rate = 44100);
        expect_true(write_success);

        loaded_buffer, load_success := load_wav_file(test_file_path);
        expect_true(load_success);
        expect_equals(loaded_buffer.channel_count, 2);
        expect_equals(loaded_buffer.sample_rate, 44100);
        expect_equals(loaded_buffer.frame_count, 50);

        compare_index := 0;
        while compare_index < 10 {
            expect_near(loaded_buffer.samples[compare_index], original_samples[compare_index], 0.01);
            compare_index += 1;
        }

        file_delete(test_file_path);
    });

    test("sampler_attack_and_decay_volume_envelope", () {
        raw_samples := NewArray(1000, float);
        sample_index := 0;
        while sample_index < raw_samples.count {
            raw_samples[sample_index] = 1.0;
            sample_index += 1;
        }

        buffer := create_audio_sample_buffer(raw_samples, 1, 44100, 60);

        envelope_config: Envelope_Configuration;
        envelope_config.attack_milliseconds = 2.0;
        envelope_config.decay_milliseconds = 5.0;
        envelope_config.sustain_level = 0.0;
        envelope_config.release_milliseconds = 5.0;

        voice: Sampler_Voice;
        initialize_sampler_voice(*voice, 44100);
        trigger_sampler_note_on(
            *voice,
            *buffer,
            60,
            1.0,
            is_one_shot = true,
            gain = 1.0,
            choke_group = 0,
            envelope_configuration = envelope_config,
            has_envelope = true
        );

        first_sample := render_sampler_sample(*voice);
        expect_true(first_sample < 0.2);

        step_counter := 0;
        peak_level: float = 0.0;
        while step_counter < 100 {
            sample := render_sampler_sample(*voice);
            if sample > peak_level peak_level = sample;
            step_counter += 1;
        }
        expect_true(peak_level > 0.9);

        decay_counter := 0;
        while decay_counter < 300 {
            render_sampler_sample(*voice);
            decay_counter += 1;
        }

        expect_true(!is_sampler_voice_active(*voice));
    });

    test("sampler_loop_points_and_continuous_sustain", () {
        raw_samples := NewArray(100, float);
        sample_index := 0;
        while sample_index < raw_samples.count {
            raw_samples[sample_index] = cast(float) sample_index;
            sample_index += 1;
        }

        buffer := create_audio_sample_buffer(raw_samples, 1, 44100, 60);

        voice: Sampler_Voice;
        initialize_sampler_voice(*voice, 44100);
        trigger_sampler_note_on(
            *voice,
            *buffer,
            60,
            1.0,
            is_one_shot = false,
            gain = 1.0,
            choke_group = 0,
            is_looping = true,
            loop_start_frame = 20,
            loop_end_frame = 60
        );

        frame_counter := 0;
        while frame_counter < 150 {
            sample := render_sampler_sample(*voice);
            if frame_counter > 60 {
                expect_true(sample >= 20.0 && sample <= 60.0);
            }
            frame_counter += 1;
        }

        expect_true(is_sampler_voice_active(*voice));
        expect_true(voice.playhead_frame >= 20.0 && voice.playhead_frame <= 60.0);

        trigger_sampler_note_off(*voice);
        expect_true(!is_sampler_voice_active(*voice));
    });

    test("sampler_start_offset_slicing", () {
        raw_samples := NewArray(1000, float);
        sample_index := 0;
        while sample_index < raw_samples.count {
            raw_samples[sample_index] = cast(float) sample_index;
            sample_index += 1;
        }

        buffer := create_audio_sample_buffer(raw_samples, 1, 44100, 60);

        frame_config: Sampler_Configuration;
        frame_config.start_offset_frame = 30;
        calculated_frame_offset := calculate_sampler_start_offset_frame(frame_config, *buffer);
        expect_equals(calculated_frame_offset, 30);

        ms_config: Sampler_Configuration;
        ms_config.start_offset_is_milliseconds = true;
        ms_config.start_offset_milliseconds = 10.0;
        calculated_ms_offset := calculate_sampler_start_offset_frame(ms_config, *buffer);
        expect_equals(calculated_ms_offset, 441);

        percent_config: Sampler_Configuration;
        percent_config.start_offset_is_percentage = true;
        percent_config.start_offset_percentage = 0.5;
        calculated_percent_offset := calculate_sampler_start_offset_frame(percent_config, *buffer);
        expect_equals(calculated_percent_offset, 500);

        voice: Sampler_Voice;
        initialize_sampler_voice(*voice, 44100);
        trigger_sampler_note_on(
            *voice,
            *buffer,
            60,
            1.0,
            is_one_shot = true,
            gain = 1.0,
            choke_group = 0,
            start_offset_frame = 25
        );

        first_sample := render_sampler_sample(*voice);
        expect_near(first_sample, 25.0, 0.001);

        second_sample := render_sampler_sample(*voice);
        expect_near(second_sample, 26.0, 0.001);
    });

    test("sampler_reverse_playback", () {
        raw_samples := NewArray(10, float);
        sample_index := 0;
        while sample_index < raw_samples.count {
            raw_samples[sample_index] = cast(float) sample_index;
            sample_index += 1;
        }

        buffer := create_audio_sample_buffer(raw_samples, 1, 44100, 60);

        voice: Sampler_Voice;
        initialize_sampler_voice(*voice, 44100);
        trigger_sampler_note_on(
            *voice,
            *buffer,
            60,
            1.0,
            is_one_shot = true,
            gain = 1.0,
            choke_group = 0,
            is_reversed = true
        );

        expect_true(is_sampler_voice_active(*voice));
        expect_near(cast(float) voice.playhead_frame, 9.0, 0.001);

        first_sample := render_sampler_sample(*voice);
        expect_near(first_sample, 9.0, 0.001);

        second_sample := render_sampler_sample(*voice);
        expect_near(second_sample, 8.0, 0.001);

        render_counter := 0;
        while render_counter < 8 {
            render_sampler_sample(*voice);
            render_counter += 1;
        }

        expect_true(!is_sampler_voice_active(*voice));

        initialize_sampler_voice(*voice, 44100);
        trigger_sampler_note_on(
            *voice,
            *buffer,
            60,
            1.0,
            is_one_shot = true,
            gain = 1.0,
            choke_group = 0,
            start_offset_frame = 2,
            is_reversed = true
        );

        first_offset_sample := render_sampler_sample(*voice);
        expect_near(first_offset_sample, 7.0, 0.001);

        second_offset_sample := render_sampler_sample(*voice);
        expect_near(second_offset_sample, 6.0, 0.001);
    });

    test("sampler_cubic_and_linear_pitch_interpolation", () {
        raw_samples := NewArray(4, float);
        raw_samples[0] = 0.0;
        raw_samples[1] = 1.0;
        raw_samples[2] = 0.0;
        raw_samples[3] = -1.0;

        buffer := create_audio_sample_buffer(raw_samples, 1, 44100, 60);

        linear_voice: Sampler_Voice;
        initialize_sampler_voice(*linear_voice, 44100);
        trigger_sampler_note_on(*linear_voice, *buffer, 60, 1.0, is_one_shot = true, gain = 1.0, interpolation = .LINEAR);
        linear_voice.playhead_frame = 1.5;
        linear_sample := render_sampler_sample(*linear_voice);
        expect_near(linear_sample, 0.5, 0.001);

        cubic_voice: Sampler_Voice;
        initialize_sampler_voice(*cubic_voice, 44100);
        trigger_sampler_note_on(*cubic_voice, *buffer, 60, 1.0, is_one_shot = true, gain = 1.0, interpolation = .CUBIC);
        cubic_voice.playhead_frame = 1.5;
        cubic_sample := render_sampler_sample(*cubic_voice);
        cubic_interpolated := interpolate_cubic(0.0, 1.0, 0.0, -1.0, 0.5);
        expect_near(cubic_sample, cubic_interpolated, 0.001);
        expect_near(cubic_sample, 0.625, 0.001);
    });

    test("sampler_multi_octave_pitch_tracking", () {
        raw_samples := NewArray(10, float);
        buffer := create_audio_sample_buffer(raw_samples, 1, 44100, 60);

        voice: Sampler_Voice;
        initialize_sampler_voice(*voice, 44100);

        trigger_sampler_note_on(*voice, *buffer, 72, 1.0);
        expect_near(cast(float) voice.playback_speed, 2.0, 0.001);

        trigger_sampler_note_on(*voice, *buffer, 84, 1.0);
        expect_near(cast(float) voice.playback_speed, 4.0, 0.001);

        trigger_sampler_note_on(*voice, *buffer, 48, 1.0);
        expect_near(cast(float) voice.playback_speed, 0.5, 0.001);

        trigger_sampler_note_on(*voice, *buffer, 36, 1.0);
        expect_near(cast(float) voice.playback_speed, 0.25, 0.001);

        trigger_sampler_note_on(*voice, *buffer, 72, 1.0, root_midi_note = 72);
        expect_near(cast(float) voice.playback_speed, 1.0, 0.001);

        trigger_sampler_note_on(*voice, *buffer, 60, 1.0, root_midi_note = 48);
        expect_near(cast(float) voice.playback_speed, 2.0, 0.001);
    });

    test("sample_pool_multi_sample_zone_selection", () {
        pool: Sample_Pool;
        initialize_sample_pool(*pool);

        samples_c2 := NewArray(4, float);
        samples_c2[0] = 2.0;
        buffer_c2 := create_audio_sample_buffer(samples_c2, 1, 44100, 36);

        samples_c4 := NewArray(4, float);
        samples_c4[0] = 4.0;
        buffer_c4 := create_audio_sample_buffer(samples_c4, 1, 44100, 60);

        samples_c6 := NewArray(4, float);
        samples_c6[0] = 6.0;
        buffer_c6 := create_audio_sample_buffer(samples_c6, 1, 44100, 84);

        add_sample_to_pool(*pool, "piano", buffer_c2, 36, 0, 47);
        add_sample_to_pool(*pool, "piano", buffer_c4, 60, 48, 71);
        add_sample_to_pool(*pool, "piano", buffer_c6, 84, 72, 127);

        found_c2, ok_c2 := find_sample_in_pool(*pool, "piano", 40);
        expect_true(ok_c2);
        expect_equals(found_c2.root_midi_note, 36);
        expect_near(found_c2.samples[0], 2.0, 0.001);

        found_c4, ok_c4 := find_sample_in_pool(*pool, "piano", 64);
        expect_true(ok_c4);
        expect_equals(found_c4.root_midi_note, 60);
        expect_near(found_c4.samples[0], 4.0, 0.001);

        found_c6, ok_c6 := find_sample_in_pool(*pool, "piano", 88);
        expect_true(ok_c6);
        expect_equals(found_c6.root_midi_note, 84);
        expect_near(found_c6.samples[0], 6.0, 0.001);
    });
}
