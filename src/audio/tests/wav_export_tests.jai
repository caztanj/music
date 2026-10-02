wav_export_tests :: () {
    test("write_wav_file_16_bit", () {
        channel_count := 2;
        sample_rate := 44100;
        test_file_path := "test_output_16_bit.wav";

        samples: [4] float;
        samples[0] = 0.0;
        samples[1] = 0.5;
        samples[2] = 1.5;
        samples[3] = -1.5;

        write_success := write_wav_file_16_bit(test_file_path, samples, channel_count, sample_rate);
        expect_true(write_success);

        file_content, read_success := read_entire_file(test_file_path);
        expect_true(read_success);

        expected_file_size := size_of(Wav_Header) + samples.count * 2;
        expect_equals(file_content.count, expected_file_size);

        header := cast(*Wav_Header) file_content.data;
        expect_equals(header.riff_marker[0], #char "R");
        expect_equals(header.riff_marker[1], #char "I");
        expect_equals(header.riff_marker[2], #char "F");
        expect_equals(header.riff_marker[3], #char "F");
        expect_equals(header.wave_marker[0], #char "W");
        expect_equals(header.wave_marker[1], #char "A");
        expect_equals(header.wave_marker[2], #char "V");
        expect_equals(header.wave_marker[3], #char "E");
        expect_equals(header.audio_format, 1);
        expect_equals(header.channel_count, 2);
        expect_equals(header.sample_rate, 44100);
        expect_equals(header.bits_per_sample, 16);
        expect_equals(header.data_size, cast(u32) (samples.count * 2));

        output_samples := cast(*s16) (file_content.data + size_of(Wav_Header));
        expect_equals(output_samples[0], 0);
        expect_equals(output_samples[1], 16383);
        expect_equals(output_samples[2], 32767);
        expect_equals(output_samples[3], -32767);

        file_delete(test_file_path);
    });

    test("write_wav_file_32_bit_float", () {
        channel_count := 2;
        sample_rate := 44100;
        test_file_path := "test_output_32_bit.wav";

        samples: [4] float;
        samples[0] = 0.0;
        samples[1] = 0.25;
        samples[2] = 0.75;
        samples[3] = -0.5;

        write_success := write_wav_file_32_bit_float(test_file_path, samples, channel_count, sample_rate);
        expect_true(write_success);

        file_content, read_success := read_entire_file(test_file_path);
        expect_true(read_success);

        expected_file_size := size_of(Wav_Header) + samples.count * 4;
        expect_equals(file_content.count, expected_file_size);

        header := cast(*Wav_Header) file_content.data;
        expect_equals(header.riff_marker[0], #char "R");
        expect_equals(header.riff_marker[1], #char "I");
        expect_equals(header.riff_marker[2], #char "F");
        expect_equals(header.riff_marker[3], #char "F");
        expect_equals(header.wave_marker[0], #char "W");
        expect_equals(header.wave_marker[1], #char "A");
        expect_equals(header.wave_marker[2], #char "V");
        expect_equals(header.wave_marker[3], #char "E");
        expect_equals(header.audio_format, 3);
        expect_equals(header.channel_count, 2);
        expect_equals(header.sample_rate, 44100);
        expect_equals(header.bits_per_sample, 32);
        expect_equals(header.data_size, cast(u32) (samples.count * 4));

        output_samples := cast(*float) (file_content.data + size_of(Wav_Header));
        expect_near(output_samples[0], 0.0);
        expect_near(output_samples[1], 0.25);
        expect_near(output_samples[2], 0.75);
        expect_near(output_samples[3], -0.5);

        file_delete(test_file_path);
    });
}
