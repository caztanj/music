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
}
