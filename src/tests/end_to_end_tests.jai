end_to_end_tests :: () {
    test("offline_export_determinism", () {
        first_export_path := "temporary_export_first.wav";
        second_export_path := "temporary_export_second.wav";

        first_export_success := export_song_to_wav("songs/drums.song", first_export_path);
        second_export_success := export_song_to_wav("songs/drums.song", second_export_path);

        expect_true(first_export_success);
        expect_true(second_export_success);

        first_file_content, first_read_success := read_entire_file(first_export_path);
        second_file_content, second_read_success := read_entire_file(second_export_path);

        defer {
            free(first_file_content);
            free(second_file_content);
            file_delete(first_export_path);
            file_delete(second_export_path);
        }

        expect_true(first_read_success);
        expect_true(second_read_success);
        expect_true(first_file_content.count > 0);
        expect_equals(first_file_content.count, second_file_content.count);

        bytes_are_identical := true;
        byte_index := 0;
        while byte_index < first_file_content.count {
            if first_file_content[byte_index] != second_file_content[byte_index] {
                bytes_are_identical = false;
                break;
            }
            byte_index += 1;
        }

        expect_true(bytes_are_identical);
    });

    test("realtime_playback_matches_offline_export", () {
        song_specification, parse_success, _ := parse_song_from_file("songs/drums.song", check_samples_on_disk = true);
        expect_true(parse_success);

        sample_rate: s64 = DEFAULT_SAMPLE_RATE;
        total_frames_to_test: s64 = 2048;
        block_size_in_frames: s64 = 512;

        offline_sequencer: Sequencer;
        configure_sequencer_from_song(*offline_sequencer, *song_specification, sample_rate);
        offline_sequencer.clock.is_looping = false;

        offline_voice_manager := New(Voice_Manager);
        defer free(offline_voice_manager);
        initialize_voice_manager(offline_voice_manager, sample_rate);

        offline_mixer := New(Mixer);
        defer {
            deinitialize_mixer(offline_mixer);
            free(offline_mixer);
        }
        configure_mixer_from_definition(offline_mixer, song_specification.mixer, sample_rate, song_specification.project.beats_per_minute);

        realtime_sequencer: Sequencer;
        configure_sequencer_from_song(*realtime_sequencer, *song_specification, sample_rate);
        realtime_sequencer.clock.is_looping = false;

        realtime_voice_manager := New(Voice_Manager);
        defer free(realtime_voice_manager);
        initialize_voice_manager(realtime_voice_manager, sample_rate);

        realtime_mixer := New(Mixer);
        defer {
            deinitialize_mixer(realtime_mixer);
            free(realtime_mixer);
        }
        configure_mixer_from_definition(realtime_mixer, song_specification.mixer, sample_rate, song_specification.project.beats_per_minute);

        offline_samples := NewArray(total_frames_to_test * 2, float);
        defer free(offline_samples.data);

        realtime_samples := NewArray(total_frames_to_test * 2, float);
        defer free(realtime_samples.data);

        rendered_frames: s64 = 0;
        while rendered_frames < total_frames_to_test {
            frames_to_render := total_frames_to_test - rendered_frames;
            if frames_to_render > block_size_in_frames {
                frames_to_render = block_size_in_frames;
            }

            offline_slice: [] float;
            offline_slice.data = offline_samples.data + rendered_frames * 2;
            offline_slice.count = frames_to_render * 2;

            render_sequencer_block(*offline_sequencer, *song_specification, offline_voice_manager, offline_mixer, offline_slice, frames_to_render);

            realtime_slice: [] float;
            realtime_slice.data = realtime_samples.data + rendered_frames * 2;
            realtime_slice.count = frames_to_render * 2;

            render_sequencer_block(*realtime_sequencer, *song_specification, realtime_voice_manager, realtime_mixer, realtime_slice, frames_to_render);

            rendered_frames += frames_to_render;
        }

        maximum_sample_difference: float = 0.0;
        has_non_zero_samples := false;
        sample_index := 0;

        while sample_index < total_frames_to_test * 2 {
            difference := abs(offline_samples[sample_index] - realtime_samples[sample_index]);
            if difference > maximum_sample_difference {
                maximum_sample_difference = difference;
            }
            if abs(offline_samples[sample_index]) > 0.01 {
                has_non_zero_samples = true;
            }
            sample_index += 1;
        }

        expect_true(has_non_zero_samples);
        expect_near(maximum_sample_difference, 0.0, 0.000001);
    });

    test("hot_reloading_song_updates_in_place_without_glitches", () {
        temporary_song_path := "temporary_hot_reload_validation.song";

        initial_content := "[project]\nname = \"Validation\"\nbpm = 120\ntime_signature = 4/4\nbars = 2\n\n[instruments]\nlead = synth(wave=\"saw\", filter=\"lowpass\", cutoff=1000, res=0.3, attack=8, decay=80, sustain=0.4, release=150, gain=0.85)\n\n[pattern melody]\nC4 step=0 len=4 vel=0.9\n\n[mixer]\ntrack 1 (lead): gain = 0.85, pan = 0.0, output = master\nmaster: gain = 1.0, limiter = on\n\n[channel_routing]\nlead -> track 1\n\n[arrangement]\nbar 1-2: melody\n";

        write_entire_file(temporary_song_path, initial_content);

        hot_reloader: Hot_Reloader;
        initialize_success := hot_reloader_initialize(*hot_reloader, temporary_song_path, DEFAULT_SAMPLE_RATE);
        expect_true(initialize_success);

        sequencer: Sequencer;
        voice_manager := New(Voice_Manager);
        defer free(voice_manager);
        initialize_voice_manager(voice_manager, DEFAULT_SAMPLE_RATE);

        mixer := New(Mixer);
        defer {
            deinitialize_mixer(mixer);
            free(mixer);
        }

        block_size_in_frames: s64 = 512;
        audio_buffer := NewArray(block_size_in_frames * 2, float);
        defer free(audio_buffer.data);

        last_applied_version: u64 = 0;

        render_audio_block_with_hot_reload(
            *hot_reloader,
            *sequencer,
            voice_manager,
            mixer,
            audio_buffer,
            block_size_in_frames,
            *last_applied_version
        );

        expect_equals(last_applied_version, 1);
        expect_equals(sequencer.clock.beats_per_minute, 120);

        has_glitches := false;
        sample_index := 0;
        while sample_index < audio_buffer.count {
            sample_value := audio_buffer[sample_index];
            is_nan_value, is_inf_value := is_nan_is_inf(sample_value);
            if is_nan_value || is_inf_value {
                has_glitches = true;
                break;
            }
            sample_index += 1;
        }
        expect_true(!has_glitches);

        updated_content := "[project]\nname = \"Validation\"\nbpm = 144\ntime_signature = 4/4\nbars = 2\n\n[instruments]\nlead = synth(wave=\"saw\", filter=\"lowpass\", cutoff=1500, res=0.3, attack=8, decay=80, sustain=0.4, release=150, gain=0.85)\n\n[pattern melody]\nE4 step=0 len=4 vel=0.9\n\n[mixer]\ntrack 1 (lead): gain = 0.85, pan = 0.0, output = master\nmaster: gain = 1.0, limiter = on\n\n[channel_routing]\nlead -> track 1\n\n[arrangement]\nbar 1-2: melody\n";

        write_entire_file(temporary_song_path, updated_content);

        reload_success := hot_reloader_reload_file(*hot_reloader);
        expect_true(reload_success);

        render_audio_block_with_hot_reload(
            *hot_reloader,
            *sequencer,
            voice_manager,
            mixer,
            audio_buffer,
            block_size_in_frames,
            *last_applied_version
        );

        expect_equals(last_applied_version, 2);
        expect_equals(sequencer.clock.beats_per_minute, 144);

        sample_index = 0;
        while sample_index < audio_buffer.count {
            sample_value := audio_buffer[sample_index];
            is_nan_value, is_inf_value := is_nan_is_inf(sample_value);
            if is_nan_value || is_inf_value {
                has_glitches = true;
                break;
            }
            sample_index += 1;
        }
        expect_true(!has_glitches);

        invalid_content := "invalid content without section header\n";
        write_entire_file(temporary_song_path, invalid_content);

        invalid_reload_success := hot_reloader_reload_file(*hot_reloader);
        expect_true(!invalid_reload_success);
        expect_true(hot_reloader.has_error);

        render_audio_block_with_hot_reload(
            *hot_reloader,
            *sequencer,
            voice_manager,
            mixer,
            audio_buffer,
            block_size_in_frames,
            *last_applied_version
        );

        expect_equals(last_applied_version, 2);
        expect_equals(sequencer.clock.beats_per_minute, 144);

        sample_index = 0;
        while sample_index < audio_buffer.count {
            sample_value := audio_buffer[sample_index];
            is_nan_value, is_inf_value := is_nan_is_inf(sample_value);
            if is_nan_value || is_inf_value {
                has_glitches = true;
                break;
            }
            sample_index += 1;
        }
        expect_true(!has_glitches);

        hot_reloader_shutdown(*hot_reloader);
        file_delete(temporary_song_path);
    });

    test("cyber_city_showcase_song_validation", () {
        song_specification, parse_success, parse_error_message := parse_song_from_file("songs/cyber_city.song", check_samples_on_disk = true);
        expect_true(parse_success);
        expect_equals(song_specification.project.name, "Cyber City");
        expect_equals(song_specification.project.beats_per_minute, 120.0);
        expect_equals(song_specification.instruments.count, 8);
        expect_equals(song_specification.mixer.tracks.count, 5);
        expect_equals(song_specification.mixer.aux_tracks.count, 1);
        expect_equals(song_specification.automation.curves.count, 8);

        sample_rate: s64 = 44100;
        sequencer: Sequencer;
        configure_sequencer_from_song(*sequencer, *song_specification, sample_rate);
        sequencer.clock.is_looping = false;

        total_clock_samples := calculate_total_clock_samples(*sequencer.clock);
        duration_in_seconds := cast(float) total_clock_samples / cast(float) sample_rate;
        expect_true(duration_in_seconds >= 180.0);

        voice_manager := New(Voice_Manager);
        defer free(voice_manager);
        initialize_voice_manager(voice_manager, sample_rate);

        mixer := New(Mixer);
        defer {
            deinitialize_mixer(mixer);
            free(mixer);
        }
        configure_mixer_from_definition(mixer, song_specification.mixer, sample_rate, song_specification.project.beats_per_minute);

        test_block_frames: s64 = 1024;
        audio_buffer := NewArray(test_block_frames * 2, float);
        defer free(audio_buffer.data);

        render_sequencer_block(*sequencer, *song_specification, voice_manager, mixer, audio_buffer, test_block_frames);

        has_numerical_error := false;
        sample_index := 0;
        while sample_index < audio_buffer.count {
            sample_value := audio_buffer[sample_index];
            is_nan_value, is_inf_value := is_nan_is_inf(sample_value);
            if is_nan_value || is_inf_value {
                has_numerical_error = true;
                break;
            }
            sample_index += 1;
        }

        expect_true(!has_numerical_error);
    });
}
