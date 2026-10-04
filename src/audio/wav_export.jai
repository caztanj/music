write_wav_file_16_bit :: (file_path: string, samples: [] float, channel_count: int = 2, sample_rate: int = DEFAULT_SAMPLE_RATE) -> bool {
    data_size := cast(u32) (samples.count * 2);
    total_file_size := size_of(Wav_Header) + data_size;

    buffer := cast(*u8) alloc(total_file_size);
    defer free(buffer);

    header := cast(*Wav_Header) buffer;

    header.riff_marker[0] = #char "R";
    header.riff_marker[1] = #char "I";
    header.riff_marker[2] = #char "F";
    header.riff_marker[3] = #char "F";
    header.total_size = 36 + data_size;
    header.wave_marker[0] = #char "W";
    header.wave_marker[1] = #char "A";
    header.wave_marker[2] = #char "V";
    header.wave_marker[3] = #char "E";
    header.format_marker[0] = #char "f";
    header.format_marker[1] = #char "m";
    header.format_marker[2] = #char "t";
    header.format_marker[3] = #char " ";
    header.format_size = 16;
    header.audio_format = 1;
    header.channel_count = cast(u16) channel_count;
    header.sample_rate = cast(u32) sample_rate;
    header.byte_rate = cast(u32) (sample_rate * channel_count * 2);
    header.block_align = cast(u16) (channel_count * 2);
    header.bits_per_sample = 16;
    header.data_marker[0] = #char "d";
    header.data_marker[1] = #char "a";
    header.data_marker[2] = #char "t";
    header.data_marker[3] = #char "a";
    header.data_size = data_size;

    output_samples := cast(*s16) (buffer + size_of(Wav_Header));
    sample_index := 0;

    while sample_index < samples.count {
        sample_value := samples[sample_index];

        if sample_value > 1.0 {
            sample_value = 1.0;
        } else if sample_value < -1.0 {
            sample_value = -1.0;
        }

        output_samples[sample_index] = cast(s16) (sample_value * 32767.0);
        sample_index += 1;
    }

    success := write_entire_file(file_path, buffer, total_file_size);

    return success;
}

write_wav_file_32_bit_float :: (file_path: string, samples: [] float, channel_count: int = 2, sample_rate: int = DEFAULT_SAMPLE_RATE) -> bool {
    data_size := cast(u32) (samples.count * 4);
    total_file_size := size_of(Wav_Header) + data_size;

    buffer := cast(*u8) alloc(total_file_size);
    defer free(buffer);

    header := cast(*Wav_Header) buffer;

    header.riff_marker[0] = #char "R";
    header.riff_marker[1] = #char "I";
    header.riff_marker[2] = #char "F";
    header.riff_marker[3] = #char "F";
    header.total_size = 36 + data_size;
    header.wave_marker[0] = #char "W";
    header.wave_marker[1] = #char "A";
    header.wave_marker[2] = #char "V";
    header.wave_marker[3] = #char "E";
    header.format_marker[0] = #char "f";
    header.format_marker[1] = #char "m";
    header.format_marker[2] = #char "t";
    header.format_marker[3] = #char " ";
    header.format_size = 16;
    header.audio_format = 3;
    header.channel_count = cast(u16) channel_count;
    header.sample_rate = cast(u32) sample_rate;
    header.byte_rate = cast(u32) (sample_rate * channel_count * 4);
    header.block_align = cast(u16) (channel_count * 4);
    header.bits_per_sample = 32;
    header.data_marker[0] = #char "d";
    header.data_marker[1] = #char "a";
    header.data_marker[2] = #char "t";
    header.data_marker[3] = #char "a";
    header.data_size = data_size;

    output_samples := cast(*float) (buffer + size_of(Wav_Header));
    sample_index := 0;

    while sample_index < samples.count {
        output_samples[sample_index] = samples[sample_index];
        sample_index += 1;
    }

    success := write_entire_file(file_path, buffer, total_file_size);

    return success;
}

soft_saturate :: (value: float) -> float {
    clamped_value := value / (1.0 + abs(value));

    return clamped_value;
}

generate_kick_sample :: (sample_rate: int = DEFAULT_SAMPLE_RATE) -> [] float {
    duration_in_seconds: float = 0.35;
    frame_count := cast(int) (cast(float) sample_rate * duration_in_seconds);
    samples := NewArray(frame_count * 2, float);

    phase: float64 = 0.0;
    frame_index := 0;

    while frame_index < frame_count {
        time_in_seconds := cast(float64) frame_index / cast(float64) sample_rate;
        pitch_envelope := exp(-time_in_seconds * 30.0);
        frequency := 45.0 + 115.0 * pitch_envelope;

        phase += (frequency * 6.283185307179586) / cast(float64) sample_rate;
        if phase >= 6.283185307179586 {
            phase -= 6.283185307179586;
        }

        amplitude_envelope := cast(float) exp(-time_in_seconds * 10.0);
        click := ifx time_in_seconds < 0.005 then cast(float) (1.0 - time_in_seconds / 0.005) * 0.3 else 0.0;

        sample_value := (cast(float) sin(phase) * amplitude_envelope + click);
        saturated_value := soft_saturate(sample_value * 1.5) * 0.95;

        samples[frame_index * 2] = saturated_value;
        samples[frame_index * 2 + 1] = saturated_value;

        frame_index += 1;
    }

    return samples;
}

generate_snare_sample :: (sample_rate: int = DEFAULT_SAMPLE_RATE) -> [] float {
    duration_in_seconds: float = 0.25;
    frame_count := cast(int) (cast(float) sample_rate * duration_in_seconds);
    samples := NewArray(frame_count * 2, float);

    phase: float64 = 0.0;
    seed: u32 = 1234567;
    previous_noise: float = 0.0;
    frame_index := 0;

    while frame_index < frame_count {
        time_in_seconds := cast(float64) frame_index / cast(float64) sample_rate;
        pitch_envelope := exp(-time_in_seconds * 22.0);
        frequency := 140.0 + 100.0 * pitch_envelope;

        phase += (frequency * 6.283185307179586) / cast(float64) sample_rate;
        if phase >= 6.283185307179586 {
            phase -= 6.283185307179586;
        }

        tone_envelope := cast(float) exp(-time_in_seconds * 18.0);
        tone := cast(float) sin(phase) * tone_envelope;

        seed = seed * 1103515245 + 12345;
        normalized_noise := (cast(float) (seed & 0x7FFFFFFF) / cast(float) 0x7FFFFFFF) * 2.0 - 1.0;
        filtered_noise := normalized_noise - previous_noise * 0.5;
        previous_noise = normalized_noise;

        noise_envelope := cast(float) exp(-time_in_seconds * 14.0);
        noise := filtered_noise * noise_envelope;

        sample_value := soft_saturate(tone * 0.45 + noise * 0.55);

        samples[frame_index * 2] = sample_value;
        samples[frame_index * 2 + 1] = sample_value;

        frame_index += 1;
    }

    return samples;
}

generate_hihat_sample :: (sample_rate: int = DEFAULT_SAMPLE_RATE) -> [] float {
    duration_in_seconds: float = 0.08;
    frame_count := cast(int) (cast(float) sample_rate * duration_in_seconds);
    samples := NewArray(frame_count * 2, float);

    seed: u32 = 7654321;
    previous_sample: float = 0.0;
    frame_index := 0;

    while frame_index < frame_count {
        time_in_seconds := cast(float64) frame_index / cast(float64) sample_rate;

        seed = seed * 1103515245 + 12345;
        normalized_noise := (cast(float) (seed & 0x7FFFFFFF) / cast(float) 0x7FFFFFFF) * 2.0 - 1.0;

        highpass_sample := normalized_noise - previous_sample * 0.85;
        previous_sample = normalized_noise;

        decay_envelope := cast(float) exp(-time_in_seconds * 65.0);
        sample_value := soft_saturate(highpass_sample * decay_envelope * 0.8);

        samples[frame_index * 2] = sample_value;
        samples[frame_index * 2 + 1] = sample_value;

        frame_index += 1;
    }

    return samples;
}

generate_clap_sample :: (sample_rate: int = DEFAULT_SAMPLE_RATE) -> [] float {
    duration_in_seconds: float = 0.25;
    frame_count := cast(int) (cast(float) sample_rate * duration_in_seconds);
    samples := NewArray(frame_count * 2, float);

    seed: u32 = 9876543;
    previous_sample: float = 0.0;
    frame_index := 0;

    while frame_index < frame_count {
        time_in_seconds := cast(float64) frame_index / cast(float64) sample_rate;

        seed = seed * 1103515245 + 12345;
        normalized_noise := (cast(float) (seed & 0x7FFFFFFF) / cast(float) 0x7FFFFFFF) * 2.0 - 1.0;
        filtered_noise := normalized_noise - previous_sample * 0.6;
        previous_sample = normalized_noise;

        burst_one := cast(float) exp(-abs(time_in_seconds - 0.000) * 150.0);
        burst_two := ifx time_in_seconds >= 0.012 then cast(float) exp(-abs(time_in_seconds - 0.012) * 150.0) else 0.0;
        burst_three := ifx time_in_seconds >= 0.024 then cast(float) exp(-abs(time_in_seconds - 0.024) * 100.0) else 0.0;
        tail := ifx time_in_seconds >= 0.024 then cast(float) exp(-(time_in_seconds - 0.024) * 20.0) * 0.6 else 0.0;

        amplitude_envelope := max(burst_one, burst_two) + burst_three + tail;
        sample_value := soft_saturate(filtered_noise * amplitude_envelope * 0.7);

        samples[frame_index * 2] = sample_value;
        samples[frame_index * 2 + 1] = sample_value;

        frame_index += 1;
    }

    return samples;
}

generate_sample_kit :: (output_directory: string = "samples", sample_rate: int = DEFAULT_SAMPLE_RATE) -> bool {
    make_directory_if_it_does_not_exist(output_directory);

    kick_path := sprint("%/kick.wav", output_directory);
    defer free(kick_path);
    kick_samples := generate_kick_sample(sample_rate);
    defer free(kick_samples.data);
    write_kick_success := write_wav_file_16_bit(kick_path, kick_samples, 2, sample_rate);

    snare_path := sprint("%/snare.wav", output_directory);
    defer free(snare_path);
    snare_samples := generate_snare_sample(sample_rate);
    defer free(snare_samples.data);
    write_snare_success := write_wav_file_16_bit(snare_path, snare_samples, 2, sample_rate);

    hihat_path := sprint("%/hihat.wav", output_directory);
    defer free(hihat_path);
    hihat_samples := generate_hihat_sample(sample_rate);
    defer free(hihat_samples.data);
    write_hihat_success := write_wav_file_16_bit(hihat_path, hihat_samples, 2, sample_rate);

    clap_path := sprint("%/clap.wav", output_directory);
    defer free(clap_path);
    clap_samples := generate_clap_sample(sample_rate);
    defer free(clap_samples.data);
    write_clap_success := write_wav_file_16_bit(clap_path, clap_samples, 2, sample_rate);

    all_succeeded := write_kick_success && write_snare_success && write_hihat_success && write_clap_success;

    return all_succeeded;
}

export_song_to_wav :: (song_path: string, output_wav_path: string, sample_rate: int = DEFAULT_SAMPLE_RATE) -> bool {
    song_specification, parse_success, error_message := parse_song_from_file(song_path, check_samples_on_disk = true);
    if !parse_success {
        print("Export error: %\n", error_message);

        return false;
    }

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

    total_frames := calculate_total_clock_samples(*sequencer.clock);
    if total_frames == 0 {
        return false;
    }

    total_samples := cast(s64) total_frames * 2;
    output_samples := NewArray(total_samples, float);
    defer free(output_samples.data);

    block_size_in_frames: s64 = 512;
    rendered_frames: s64 = 0;

    while rendered_frames < cast(s64) total_frames {
        frames_to_render := cast(s64) total_frames - rendered_frames;
        if frames_to_render > block_size_in_frames {
            frames_to_render = block_size_in_frames;
        }

        slice: [] float;
        slice.data = output_samples.data + rendered_frames * 2;
        slice.count = frames_to_render * 2;

        render_sequencer_block(*sequencer, *song_specification, voice_manager, mixer, slice, frames_to_render);
        rendered_frames += frames_to_render;
    }

    write_success := write_wav_file_32_bit_float(output_wav_path, output_samples, 2, sample_rate);

    return write_success;
}

sanitize_stem_name :: (name: string) -> string {
    if name.count == 0 {
        return "";
    }

    result := alloc_string(name.count);
    character_index := 0;
    while character_index < name.count {
        character := name[character_index];
        if character >= #char "A" && character <= #char "Z" {
            result[character_index] = character + 32;
        } else if (character >= #char "a" && character <= #char "z") || (character >= #char "0" && character <= #char "9") || character == #char "_" || character == #char "-" {
            result[character_index] = character;
        } else {
            result[character_index] = #char "_";
        }

        character_index += 1;
    }

    return result;
}

trim_trailing_slashes :: (path: string) -> string {
    result := path;
    while result.count > 0 && (result[result.count - 1] == #char "/" || result[result.count - 1] == #char "\\") {
        result.count -= 1;
    }

    return result;
}

collect_song_stem_descriptors :: (song_specification: *Song_Specification) -> [..] Stem_Descriptor {
    descriptors: [..] Stem_Descriptor;

    track_index := 1;
    while track_index <= MAXIMUM_TRACKS {
        track_is_active := false;
        track_name := "";

        mixer_track, track_found := find_mixer_track(song_specification, track_index);
        if track_found {
            track_is_active = true;
            track_name = mixer_track.name;
        }

        routing_index := 0;
        while routing_index < song_specification.routings.count {
            routing := *song_specification.routings[routing_index];
            if routing.track_index == track_index {
                track_is_active = true;
                if track_name.count == 0 {
                    track_name = routing.instrument_name;
                }
            }
            routing_index += 1;
        }

        if !track_is_active && track_index == 1 && song_specification.instruments.count > 0 && song_specification.mixer.tracks.count == 0 && song_specification.routings.count == 0 {
            track_is_active = true;
        }

        if track_is_active {
            descriptor: Stem_Descriptor;
            descriptor.stem_type = .TRACK;
            descriptor.channel_index = track_index;
            descriptor.name = track_name;

            base_filename := "";
            if track_name.count > 0 {
                sanitized := sanitize_stem_name(track_name);
                base_filename = sprint("%.wav", sanitized);
                free(sanitized);
            } else {
                base_filename = sprint("track_%.wav", track_index);
            }

            collision := false;
            search_index := 0;
            while search_index < descriptors.count {
                if descriptors[search_index].filename == base_filename {
                    collision = true;
                    break;
                }
                search_index += 1;
            }

            if collision || base_filename == "master.wav" {
                free(base_filename);
                if track_name.count > 0 {
                    sanitized := sanitize_stem_name(track_name);
                    base_filename = sprint("track_%_%.wav", track_index, sanitized);
                    free(sanitized);
                } else {
                    base_filename = sprint("track_%.wav", track_index);
                }
            }

            descriptor.filename = base_filename;
            array_add(*descriptors, descriptor);
        }

        track_index += 1;
    }

    aux_index := 1;
    while aux_index <= MAXIMUM_AUX_TRACKS {
        aux_is_active := false;
        aux_name := "";

        aux_definition_index := 0;
        while aux_definition_index < song_specification.mixer.aux_tracks.count {
            aux_definition := *song_specification.mixer.aux_tracks[aux_definition_index];
            if aux_definition.aux_index == aux_index {
                aux_is_active = true;
                aux_name = aux_definition.name;
                break;
            }
            aux_definition_index += 1;
        }

        mixer_track_index := 0;
        while mixer_track_index < song_specification.mixer.tracks.count {
            track := *song_specification.mixer.tracks[mixer_track_index];
            if track.send_levels[aux_index - 1] > 0.0 {
                aux_is_active = true;
            }
            mixer_track_index += 1;
        }

        automation_index := 0;
        while automation_index < song_specification.automation.curves.count {
            curve := *song_specification.automation.curves[automation_index];
            if curve.target_type == .TRACK_SEND && curve.aux_send_index == aux_index {
                aux_is_active = true;
            }
            automation_index += 1;
        }

        if aux_is_active {
            descriptor: Stem_Descriptor;
            descriptor.stem_type = .AUX;
            descriptor.channel_index = aux_index;
            descriptor.name = aux_name;

            base_filename := "";
            if aux_name.count > 0 {
                sanitized := sanitize_stem_name(aux_name);
                base_filename = sprint("%.wav", sanitized);
                free(sanitized);
            } else {
                base_filename = sprint("aux_%.wav", aux_index);
            }

            collision := false;
            search_index := 0;
            while search_index < descriptors.count {
                if descriptors[search_index].filename == base_filename {
                    collision = true;
                    break;
                }
                search_index += 1;
            }

            if collision || base_filename == "master.wav" {
                free(base_filename);
                if aux_name.count > 0 {
                    sanitized := sanitize_stem_name(aux_name);
                    base_filename = sprint("aux_%_%.wav", aux_index, sanitized);
                    free(sanitized);
                } else {
                    base_filename = sprint("aux_%.wav", aux_index);
                }
            }

            descriptor.filename = base_filename;
            array_add(*descriptors, descriptor);
        }

        aux_index += 1;
    }

    master_descriptor: Stem_Descriptor;
    master_descriptor.stem_type = .MASTER;
    master_descriptor.channel_index = 0;
    master_descriptor.name = "master";
    master_descriptor.filename = copy_string("master.wav");
    array_add(*descriptors, master_descriptor);

    return descriptors;
}

export_song_stems_to_wav :: (song_path: string, output_directory_path: string, sample_rate: int = DEFAULT_SAMPLE_RATE) -> bool {
    song_specification, parse_success, error_message := parse_song_from_file(song_path, check_samples_on_disk = true);
    if !parse_success {
        print("Export error: %\n", error_message);

        return false;
    }

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

    total_frames := calculate_total_clock_samples(*sequencer.clock);
    if total_frames == 0 {
        return false;
    }

    descriptors := collect_song_stem_descriptors(*song_specification);
    if descriptors.count == 0 {
        return false;
    }
    defer {
        descriptor_index := 0;
        while descriptor_index < descriptors.count {
            free(descriptors[descriptor_index].filename);
            descriptor_index += 1;
        }
        array_reset(*descriptors);
    }

    total_samples := cast(s64) total_frames * 2;
    stem_buffers := NewArray(descriptors.count, [] float);
    defer {
        stem_buffer_index := 0;
        while stem_buffer_index < descriptors.count {
            free(stem_buffers[stem_buffer_index].data);
            stem_buffer_index += 1;
        }
        free(stem_buffers.data);
    }

    descriptor_index := 0;
    while descriptor_index < descriptors.count {
        stem_buffers[descriptor_index] = NewArray(total_samples, float);
        descriptor_index += 1;
    }

    block_size_in_frames: s64 = 512;
    rendered_frames: s64 = 0;
    master_block_buffer: [1024 * 2] float;

    while rendered_frames < cast(s64) total_frames {
        frames_to_render := cast(s64) total_frames - rendered_frames;
        if frames_to_render > block_size_in_frames {
            frames_to_render = block_size_in_frames;
        }

        master_slice: [] float;
        master_slice.data = master_block_buffer.data;
        master_slice.count = frames_to_render * 2;

        render_sequencer_block(*sequencer, *song_specification, voice_manager, mixer, master_slice, frames_to_render);

        frame_offset := rendered_frames * 2;
        stem_index := 0;
        while stem_index < descriptors.count {
            descriptor := *descriptors[stem_index];
            destination_buffer := stem_buffers[stem_index];

            target_slice: [] float;
            target_slice.data = destination_buffer.data + frame_offset;
            target_slice.count = frames_to_render * 2;

            if descriptor.stem_type == {
                case .TRACK;
                    channel, channel_found := find_mixer_channel(mixer, descriptor.channel_index);
                    if channel_found {
                        render_channel_block_interleaved(channel, target_slice, frames_to_render);
                    }

                case .AUX;
                    aux, aux_found := find_mixer_aux_channel(mixer, descriptor.channel_index);
                    if aux_found {
                        render_aux_channel_block_interleaved(aux, target_slice, frames_to_render);
                    }

                case .MASTER;
                    sample_index := 0;
                    while sample_index < frames_to_render * 2 {
                        target_slice[sample_index] = master_slice[sample_index];
                        sample_index += 1;
                    }
            }

            stem_index += 1;
        }

        rendered_frames += frames_to_render;
    }

    clean_directory := trim_trailing_slashes(output_directory_path);
    if clean_directory.count == 0 {
        clean_directory = ".";
    }
    make_directory_if_it_does_not_exist(clean_directory, recursive = true);

    all_written_successfully := true;
    stem_index := 0;
    while stem_index < descriptors.count {
        descriptor := *descriptors[stem_index];
        destination_path := sprint("%/%", clean_directory, descriptor.filename);
        defer free(destination_path);

        write_success := write_wav_file_32_bit_float(destination_path, stem_buffers[stem_index], 2, sample_rate);
        if !write_success {
            all_written_successfully = false;
        }

        stem_index += 1;
    }

    return all_written_successfully;
}

Stem_Type :: enum {
    TRACK;
    AUX;
    MASTER;
}

Stem_Descriptor :: struct {
    stem_type: Stem_Type = .TRACK;
    channel_index: s64 = 1;
    name: string;
    filename: string;
}

Wav_Header :: struct {
    riff_marker: [4] u8;
    total_size: u32;
    wave_marker: [4] u8;
    format_marker: [4] u8;
    format_size: u32;
    audio_format: u16;
    channel_count: u16;
    sample_rate: u32;
    byte_rate: u32;
    block_align: u16;
    bits_per_sample: u16;
    data_marker: [4] u8;
    data_size: u32;
} #no_padding;
