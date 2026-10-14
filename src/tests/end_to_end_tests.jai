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

    test("midnight_coffee_showcase_song_validation", () {
        song_specification, parse_success, parse_error_message := parse_song_from_file("songs/midnight_coffee.song", check_samples_on_disk = true);
        expect_true(parse_success);
        expect_equals(song_specification.project.name, "Midnight Coffee");
        expect_equals(song_specification.project.beats_per_minute, 78.0);
        expect_equals(song_specification.instruments.count, 10);
        expect_equals(song_specification.mixer.tracks.count, 6);
        expect_equals(song_specification.mixer.aux_tracks.count, 1);
        expect_equals(song_specification.automation.curves.count, 7);

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

    test("pulse_reactor_showcase_song_validation", () {
        song_specification, parse_success, parse_error_message := parse_song_from_file("songs/pulse_reactor.song", check_samples_on_disk = true);
        expect_true(parse_success);
        expect_equals(song_specification.project.name, "Pulse Reactor");
        expect_equals(song_specification.project.beats_per_minute, 128.0);
        expect_equals(song_specification.instruments.count, 13);
        expect_equals(song_specification.mixer.tracks.count, 6);
        expect_equals(song_specification.mixer.aux_tracks.count, 1);
        expect_equals(song_specification.automation.curves.count, 10);

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

    test("stress_test_voice_engine_under_maximum_polyphony", () {
        sample_rate: s64 = 44100;
        voice_manager := New(Voice_Manager);
        defer free(voice_manager);
        initialize_voice_manager(voice_manager, sample_rate);

        configuration: Synthesizer_Configuration;
        configuration.waveform = .SAWTOOTH;
        configuration.oscillator_2_enabled = true;
        configuration.oscillator_2_waveform = .SQUARE;
        configuration.oscillator_2_semitones = -12;
        configuration.oscillator_mix = 0.5;
        configuration.noise_type = .PINK_NOISE;
        configuration.noise_level = 0.2;
        configuration.unison_voices = 4;
        configuration.unison_detune = 20.0;
        configuration.unison_spread = 0.8;
        configuration.filter.type = .LOWPASS;
        configuration.filter.cutoff_frequency_hertz = 1500.0;
        configuration.filter.resonance = 0.3;
        configuration.envelope.attack_milliseconds = 5.0;
        configuration.envelope.decay_milliseconds = 200.0;
        configuration.envelope.sustain_level = 0.8;
        configuration.envelope.release_milliseconds = 100.0;
        configuration.lfo_1.enabled = true;
        configuration.lfo_1.waveform = .SINE;
        configuration.lfo_1.destination = .FILTER_CUTOFF;
        configuration.lfo_1.rate_hertz = 3.5;
        configuration.lfo_1.amount = 0.25;

        note_index := 0;
        while note_index < MAXIMUM_VOICES {
            midi_note := cast(s32) (36 + (note_index % 48));
            trigger_synthesizer_note(voice_manager, "lead", 1, configuration, midi_note, 0.9);
            note_index += 1;
        }

        expect_equals(count_active_voices(voice_manager), MAXIMUM_VOICES);

        overflow_index := 0;
        while overflow_index < 32 {
            midi_note := cast(s32) (60 + overflow_index);
            trigger_synthesizer_note(voice_manager, "lead", 1, configuration, midi_note, 1.0);
            overflow_index += 1;
        }

        expect_equals(count_active_voices(voice_manager), MAXIMUM_VOICES);

        render_buffer_frames: s64 = 1024;
        left_channel_buffer := NewArray(render_buffer_frames, float);
        defer free(left_channel_buffer.data);
        right_channel_buffer := NewArray(render_buffer_frames, float);
        defer free(right_channel_buffer.data);

        blocks_to_render := 8;
        block_counter := 0;
        has_numerical_instability := false;
        has_sound_output := false;

        while block_counter < blocks_to_render {
            render_track_voices_into_buffer(voice_manager, 1, left_channel_buffer, right_channel_buffer);

            sample_index := 0;
            while sample_index < render_buffer_frames {
                left_sample := left_channel_buffer[sample_index];
                right_sample := right_channel_buffer[sample_index];

                left_nan, left_inf := is_nan_is_inf(left_sample);
                right_nan, right_inf := is_nan_is_inf(right_sample);
                if left_nan || left_inf || right_nan || right_inf {
                    has_numerical_instability = true;
                    break;
                }

                if abs(left_sample) > 0.001 || abs(right_sample) > 0.001 {
                    has_sound_output = true;
                }

                sample_index += 1;
            }

            block_counter += 1;
        }

        expect_true(!has_numerical_instability);
        expect_true(has_sound_output);
    });

    test("stress_test_effect_pipelines_and_heavy_automation", () {
        sample_rate: s64 = 44100;
        beats_per_minute: float = 130.0;

        mixer := New(Mixer);
        defer {
            deinitialize_mixer(mixer);
            free(mixer);
        }

        mixer_definition: Mixer_Definition;
        track_counter := 1;
        while track_counter <= 8 {
            track_definition: Mixer_Track_Definition;
            track_definition.track_index = track_counter;
            track_definition.gain = 0.8;
            track_definition.pan = ifx (track_counter % 2 == 0) then 0.2 else -0.2;
            track_definition.filter_enabled = true;
            track_definition.filter_type = .LOWPASS;
            track_definition.filter_cutoff_frequency_hertz = 2000.0;
            track_definition.filter_resonance = 0.3;
            track_definition.equalizer_enabled = true;
            track_definition.equalizer_low_gain_decibels = 2.0;
            track_definition.equalizer_low_frequency_hertz = 120.0;
            track_definition.equalizer_mid_gain_decibels = -2.0;
            track_definition.equalizer_mid_frequency_hertz = 1000.0;
            track_definition.equalizer_mid_quality_factor = 1.0;
            track_definition.equalizer_high_gain_decibels = 1.5;
            track_definition.equalizer_high_frequency_hertz = 8000.0;
            track_definition.chorus_enabled = true;
            track_definition.chorus_mix = 0.4;
            track_definition.chorus_rate_hertz = 1.2;
            track_definition.chorus_depth_milliseconds = 2.0;
            track_definition.saturation_enabled = true;
            track_definition.saturation_type = ifx (track_counter % 2 == 0) then .TANH else .CUBIC;
            track_definition.saturation_drive = 1.5;
            track_definition.saturation_mix = 0.7;
            track_definition.compressor_enabled = true;
            track_definition.compressor_threshold_decibels = -12.0;
            track_definition.compressor_ratio = 4.0;
            track_definition.compressor_attack_milliseconds = 2.0;
            track_definition.compressor_release_milliseconds = 80.0;
            track_definition.delay_time_seconds = 0.25;
            track_definition.delay_feedback = 0.3;
            track_definition.send_levels[0] = 0.4;
            if track_counter > 1 {
                track_definition.sidechain_source_track_index = 1;
                track_definition.sidechain_depth_decibels = 10.0;
            }

            array_add(*mixer_definition.tracks, track_definition);
            track_counter += 1;
        }

        aux_definition: Aux_Track_Definition;
        aux_definition.aux_index = 1;
        aux_definition.gain = 0.8;
        aux_definition.reverb_enabled = true;
        aux_definition.reverb_room_size = 0.8;
        aux_definition.reverb_damping = 0.3;
        aux_definition.reverb_predelay_milliseconds = 20.0;
        array_add(*mixer_definition.aux_tracks, aux_definition);

        mixer_definition.master.gain = 1.0;
        mixer_definition.master.limiter_enabled = true;

        configure_mixer_from_definition(mixer, mixer_definition, sample_rate, beats_per_minute);

        frames_per_block: s64 = 512;
        output_buffer := NewArray(frames_per_block * 2, float);
        defer free(output_buffer.data);

        blocks_to_render := 16;
        block_counter := 0;
        has_numerical_errors := false;

        while block_counter < blocks_to_render {
            clear_channel_buffers(mixer, frames_per_block);

            track_index := 0;
            while track_index < 8 {
                channel := *mixer.tracks[track_index];
                sample_index := 0;
                while sample_index < frames_per_block {
                    synthetic_signal := sin(cast(float) (block_counter * frames_per_block + sample_index) * 0.05) * 0.5;
                    channel.left_buffer[sample_index] = synthetic_signal;
                    channel.right_buffer[sample_index] = synthetic_signal;
                    sample_index += 1;
                }
                track_index += 1;
            }

            sweep_cutoff := 300.0 + cast(float) (block_counter * 300);
            track_index = 0;
            while track_index < 8 {
                channel := *mixer.tracks[track_index];
                channel.filter_insert.cutoff_frequency_hertz = sweep_cutoff;
                channel.pan = sin(cast(float) block_counter * 0.3) * 0.7;
                track_index += 1;
            }

            mix_channels_to_master(mixer, frames_per_block);
            render_mixer_master_block_interleaved(mixer, output_buffer, frames_per_block);

            sample_index := 0;
            while sample_index < output_buffer.count {
                sample_value := output_buffer[sample_index];
                is_nan_value, is_inf_value := is_nan_is_inf(sample_value);
                if is_nan_value || is_inf_value {
                    has_numerical_errors = true;
                    break;
                }
                sample_index += 1;
            }

            block_counter += 1;
        }

        expect_true(!has_numerical_errors);
        expect_true(mixer.master.limiter.envelope_follower >= 0.0);
    });

    test("showcase_songs_rendering_benchmark_and_cpu_load", () {
        song_paths: [3] string;
        song_paths[0] = "songs/cyber_city.song";
        song_paths[1] = "songs/midnight_coffee.song";
        song_paths[2] = "songs/pulse_reactor.song";

        sample_rate: s64 = 44100;
        frames_per_block: s64 = 512;
        blocks_to_benchmark: s64 = 40;
        total_benchmark_frames := frames_per_block * blocks_to_benchmark;
        audio_duration_seconds := cast(float64) total_benchmark_frames / cast(float64) sample_rate;

        output_buffer := NewArray(frames_per_block * 2, float);
        defer free(output_buffer.data);

        song_index := 0;
        while song_index < song_paths.count {
            song_path := song_paths[song_index];
            song_specification, parse_success, _ := parse_song_from_file(song_path, check_samples_on_disk = true);
            expect_true(parse_success);

            sequencer: Sequencer;
            configure_sequencer_from_song(*sequencer, *song_specification, sample_rate);
            sequencer.clock.is_looping = false;

            voice_manager := New(Voice_Manager);
            defer free(voice_manager);
            initialize_voice_manager(voice_manager, sample_rate);

            mixer := New(Mixer);
            defer {
                deinitialize_mixer(mixer);
                free(mixer);
            }
            configure_mixer_from_definition(mixer, song_specification.mixer, sample_rate, song_specification.project.beats_per_minute);

            start_time := current_time_monotonic();

            block_index: s64 = 0;
            has_numerical_error := false;

            while block_index < blocks_to_benchmark {
                render_sequencer_block(*sequencer, *song_specification, voice_manager, mixer, output_buffer, frames_per_block);

                sample_index := 0;
                while sample_index < output_buffer.count {
                    sample_value := output_buffer[sample_index];
                    is_nan_value, is_inf_value := is_nan_is_inf(sample_value);
                    if is_nan_value || is_inf_value {
                        has_numerical_error = true;
                        break;
                    }
                    sample_index += 1;
                }

                block_index += 1;
            }

            render_duration_seconds, _ := to_float64_seconds(current_time_monotonic() - start_time);
            cpu_percentage := (render_duration_seconds / audio_duration_seconds) * 100.0;

            expect_true(!has_numerical_error);
            expect_true(cpu_percentage < 15.0);

            song_index += 1;
        }
    });
}
