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
