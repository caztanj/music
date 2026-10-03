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
