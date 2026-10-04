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

    test("generate_sample_kit_creates_clean_audio_files", () {
        generate_success := generate_sample_kit("samples", 44100);
        expect_true(generate_success);

        kick_buffer, kick_success := load_wav_file("samples/kick.wav");
        expect_true(kick_success);
        expect_true(kick_buffer.frame_count > 0);
        expect_equals(kick_buffer.channel_count, 2);
        expect_equals(kick_buffer.sample_rate, 44100);

        snare_buffer, snare_success := load_wav_file("samples/snare.wav");
        expect_true(snare_success);
        expect_true(snare_buffer.frame_count > 0);
        expect_equals(snare_buffer.channel_count, 2);
        expect_equals(snare_buffer.sample_rate, 44100);

        hihat_buffer, hihat_success := load_wav_file("samples/hihat.wav");
        expect_true(hihat_success);
        expect_true(hihat_buffer.frame_count > 0);
        expect_equals(hihat_buffer.channel_count, 2);
        expect_equals(hihat_buffer.sample_rate, 44100);

        clap_buffer, clap_success := load_wav_file("samples/clap.wav");
        expect_true(clap_success);
        expect_true(clap_buffer.frame_count > 0);
        expect_equals(clap_buffer.channel_count, 2);
        expect_equals(clap_buffer.sample_rate, 44100);
    });

    test("sanitize_stem_name_and_trim_trailing_slashes", () {
        sanitized_lead := sanitize_stem_name("Lead Synth 1");
        defer free(sanitized_lead);
        expect_equals(sanitized_lead, "lead_synth_1");

        sanitized_empty := sanitize_stem_name("");
        defer free(sanitized_empty);
        expect_equals(sanitized_empty, "");

        trimmed_path := trim_trailing_slashes("exports/stems///");
        expect_equals(trimmed_path, "exports/stems");

        trimmed_empty := trim_trailing_slashes("");
        expect_equals(trimmed_empty, "");
    });

    test("collect_song_stem_descriptors_resolves_tracks_aux_and_master", () {
        song_specification, parse_success, _ := parse_song_from_file("songs/drums.song", check_samples_on_disk = true);
        expect_true(parse_success);

        descriptors := collect_song_stem_descriptors(*song_specification);
        defer {
            descriptor_index := 0;
            while descriptor_index < descriptors.count {
                free(descriptors[descriptor_index].filename);
                descriptor_index += 1;
            }
            array_reset(*descriptors);
        }

        expect_equals(descriptors.count, 2);
        expect_equals(descriptors[0].stem_type, Stem_Type.TRACK);
        expect_equals(descriptors[0].channel_index, 1);
        expect_equals(descriptors[0].name, "drums");
        expect_equals(descriptors[0].filename, "drums.wav");

        expect_equals(descriptors[1].stem_type, Stem_Type.MASTER);
        expect_equals(descriptors[1].channel_index, 0);
        expect_equals(descriptors[1].name, "master");
        expect_equals(descriptors[1].filename, "master.wav");
    });

    test("export_song_stems_to_wav_multi_track_single_pass", () {
        temporary_directory := "temporary_stem_export_test";
        export_success := export_song_stems_to_wav("songs/drums.song", temporary_directory, 44100);
        expect_true(export_success);

        single_export_path := "temporary_single_master.wav";
        single_success := export_song_to_wav("songs/drums.song", single_export_path, 44100);
        expect_true(single_success);

        drums_stem_path := sprint("%/drums.wav", temporary_directory);
        defer free(drums_stem_path);
        master_stem_path := sprint("%/master.wav", temporary_directory);
        defer free(master_stem_path);

        drums_content, read_drums_success := read_entire_file(drums_stem_path);
        expect_true(read_drums_success);
        defer free(drums_content);

        master_content, read_master_success := read_entire_file(master_stem_path);
        expect_true(read_master_success);
        defer free(master_content);

        single_content, read_single_success := read_entire_file(single_export_path);
        expect_true(read_single_success);
        defer free(single_content);

        expect_equals(drums_content.count, master_content.count);
        expect_equals(master_content.count, single_content.count);

        master_header := cast(*Wav_Header) master_content.data;
        expect_equals(master_header.audio_format, 3);
        expect_equals(master_header.channel_count, 2);
        expect_equals(master_header.bits_per_sample, 32);
        expect_equals(master_header.sample_rate, 44100);

        byte_index := 0;
        master_matches_single := true;
        while byte_index < master_content.count {
            if master_content[byte_index] != single_content[byte_index] {
                master_matches_single = false;
                break;
            }
            byte_index += 1;
        }
        expect_true(master_matches_single);

        drums_samples := cast(*float) (drums_content.data + size_of(Wav_Header));
        total_float_samples := (drums_content.count - size_of(Wav_Header)) / 4;
        has_drums_audio := false;
        sample_index := 0;
        while sample_index < total_float_samples {
            if abs(drums_samples[sample_index]) > 0.05 {
                has_drums_audio = true;
                break;
            }
            sample_index += 1;
        }
        expect_true(has_drums_audio);

        file_delete(drums_stem_path);
        file_delete(master_stem_path);
        file_delete(single_export_path);
        delete_directory(temporary_directory);
    });

    test("render_channel_and_aux_block_interleaved", () {
        channel: Mixer_Channel;
        channel.output_left_buffer[0] = 0.25;
        channel.output_right_buffer[0] = 0.75;
        channel.output_left_buffer[1] = -0.5;
        channel.output_right_buffer[1] = 0.5;

        interleaved_buffer: [4] float;
        render_channel_block_interleaved(*channel, interleaved_buffer, 2);

        expect_near(interleaved_buffer[0], 0.25);
        expect_near(interleaved_buffer[1], 0.75);
        expect_near(interleaved_buffer[2], -0.5);
        expect_near(interleaved_buffer[3], 0.5);

        aux: Aux_Channel;
        aux.output_left_buffer[0] = 0.1;
        aux.output_right_buffer[0] = 0.9;
        render_aux_channel_block_interleaved(*aux, interleaved_buffer, 1);

        expect_near(interleaved_buffer[0], 0.1);
        expect_near(interleaved_buffer[1], 0.9);
    });
}
