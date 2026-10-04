load_wav_file :: (file_path: string) -> Audio_Sample_Buffer, bool {
    audio_buffer: Audio_Sample_Buffer;
    audio_buffer.file_path = file_path;

    file_content, read_success := read_entire_file(file_path);
    if !read_success || file_content.count < size_of(Wav_Header) {
        return audio_buffer, false;
    }

    if file_content.count < 12 {
        return audio_buffer, false;
    }

    if file_content[0] != #char "R" || file_content[1] != #char "I" || file_content[2] != #char "F" || file_content[3] != #char "F" {
        return audio_buffer, false;
    }

    if file_content[8] != #char "W" || file_content[9] != #char "A" || file_content[10] != #char "V" || file_content[11] != #char "E" {
        return audio_buffer, false;
    }

    cursor_index := 12;
    audio_format: u16 = 1;
    channel_count: u16 = 2;
    sample_rate: u32 = 44100;
    bits_per_sample: u16 = 16;
    data_pointer: *u8 = null;
    data_size: u32 = 0;

    while cursor_index + 8 <= file_content.count {
        chunk_id_0 := file_content[cursor_index];
        chunk_id_1 := file_content[cursor_index + 1];
        chunk_id_2 := file_content[cursor_index + 2];
        chunk_id_3 := file_content[cursor_index + 3];

        chunk_size := (cast(*u32) (file_content.data + cursor_index + 4)).*;
        cursor_index += 8;

        if chunk_id_0 == #char "f" && chunk_id_1 == #char "m" && chunk_id_2 == #char "t" && chunk_id_3 == #char " " {
            if chunk_size >= 16 && cursor_index + 16 <= file_content.count {
                audio_format = (cast(*u16) (file_content.data + cursor_index)).*;
                channel_count = (cast(*u16) (file_content.data + cursor_index + 2)).*;
                sample_rate = (cast(*u32) (file_content.data + cursor_index + 4)).*;
                bits_per_sample = (cast(*u16) (file_content.data + cursor_index + 14)).*;
            }
        } else if chunk_id_0 == #char "d" && chunk_id_1 == #char "a" && chunk_id_2 == #char "t" && chunk_id_3 == #char "a" {
            data_pointer = file_content.data + cursor_index;
            data_size = chunk_size;
        }

        cursor_index += cast(s64) chunk_size;
    }

    if data_pointer == null || data_size == 0 || channel_count == 0 {
        return audio_buffer, false;
    }

    bytes_per_sample := bits_per_sample / 8;
    if bytes_per_sample == 0 {
        return audio_buffer, false;
    }

    total_samples := data_size / cast(u32) bytes_per_sample;
    decoded_samples := NewArray(total_samples, float);

    if audio_format == 1 && bits_per_sample == 16 {
        s16_pointer := cast(*s16) data_pointer;
        sample_index := 0;
        while sample_index < total_samples {
            decoded_samples[sample_index] = cast(float) s16_pointer[sample_index] / 32768.0;
            sample_index += 1;
        }
    } else if audio_format == 3 && bits_per_sample == 32 {
        float_pointer := cast(*float) data_pointer;
        sample_index := 0;
        while sample_index < total_samples {
            decoded_samples[sample_index] = float_pointer[sample_index];
            sample_index += 1;
        }
    } else {
        return audio_buffer, false;
    }

    audio_buffer.samples = decoded_samples;
    audio_buffer.channel_count = cast(s64) channel_count;
    audio_buffer.sample_rate = cast(s64) sample_rate;
    audio_buffer.frame_count = cast(s64) (total_samples / cast(u32) channel_count);

    return audio_buffer, true;
}

create_audio_sample_buffer :: (samples: [] float, channel_count: s64 = 2, sample_rate: s64 = DEFAULT_SAMPLE_RATE, root_midi_note: s32 = 60) -> Audio_Sample_Buffer {
    audio_buffer: Audio_Sample_Buffer;
    audio_buffer.samples = samples;
    audio_buffer.channel_count = channel_count;
    audio_buffer.sample_rate = sample_rate;
    audio_buffer.root_midi_note = root_midi_note;

    if channel_count > 0 {
        audio_buffer.frame_count = samples.count / channel_count;
    }

    return audio_buffer;
}

get_sample_from_buffer :: (buffer: *Audio_Sample_Buffer, frame_index: s64, channel_index: s64) -> float {
    if buffer == null || buffer.samples.count == 0 || frame_index < 0 || frame_index >= buffer.frame_count {
        return 0.0;
    }

    if buffer.channel_count == 1 {
        return buffer.samples[frame_index];
    }

    clamped_channel := ifx channel_index >= buffer.channel_count then buffer.channel_count - 1 else channel_index;
    sample_index := frame_index * buffer.channel_count + clamped_channel;
    if sample_index >= buffer.samples.count {
        return 0.0;
    }

    return buffer.samples[sample_index];
}

initialize_sampler_voice :: (voice: *Sampler_Voice, sample_rate: s64 = DEFAULT_SAMPLE_RATE) {
    voice.buffer = null;
    voice.playhead_frame = 0.0;
    voice.playback_speed = 1.0;
    voice.gain = 1.0;
    voice.velocity = 1.0;
    voice.is_active = false;
    voice.is_one_shot = true;
    voice.sample_rate = sample_rate;
    voice.choke_group = 0;
    voice.has_envelope = false;
    voice.is_looping = false;
    voice.loop_start_frame = 0;
    voice.loop_end_frame = 0;
    voice.start_offset_frame = 0;
    voice.is_reversed = false;
    reset_envelope(*voice.envelope);
}

trigger_sampler_note_on :: (voice: *Sampler_Voice, buffer: *Audio_Sample_Buffer, midi_note_number: s32 = 60, velocity: float = 1.0, is_one_shot: bool = true, gain: float = 1.0, choke_group: s32 = 0, envelope_configuration: Envelope_Configuration = .{}, has_envelope: bool = false, is_looping: bool = false, loop_start_frame: s64 = 0, loop_end_frame: s64 = 0, start_offset_frame: s64 = 0, is_reversed: bool = false) {
    voice.buffer = buffer;
    voice.velocity = velocity;
    voice.gain = gain;
    voice.is_one_shot = is_one_shot;
    voice.is_active = true;
    voice.choke_group = choke_group;
    voice.has_envelope = has_envelope;
    voice.is_looping = is_looping;
    voice.loop_start_frame = loop_start_frame;
    voice.loop_end_frame = loop_end_frame;
    voice.start_offset_frame = start_offset_frame;
    voice.is_reversed = is_reversed;

    total_frames: s64 = ifx buffer != null then buffer.frame_count else 0;
    clamped_offset := start_offset_frame;
    if clamped_offset < 0 clamped_offset = 0;
    if total_frames > 0 && clamped_offset >= total_frames clamped_offset = total_frames - 1;

    if is_reversed {
        end_boundary := total_frames;
        if is_looping && loop_end_frame > 0 && loop_end_frame <= total_frames {
            end_boundary = loop_end_frame;
        }
        starting_frame := (end_boundary - 1) - clamped_offset;
        if starting_frame < 0 starting_frame = 0;
        voice.playhead_frame = cast(float64) starting_frame;
    } else {
        voice.playhead_frame = cast(float64) clamped_offset;
    }

    if buffer != null && buffer.sample_rate > 0 && voice.sample_rate > 0 {
        semitone_difference := cast(float64) (midi_note_number - buffer.root_midi_note);
        pitch_ratio := pow(2.0, semitone_difference / 12.0);
        sample_rate_ratio := cast(float64) buffer.sample_rate / cast(float64) voice.sample_rate;
        voice.playback_speed = pitch_ratio * sample_rate_ratio;
    } else {
        voice.playback_speed = 1.0;
    }

    if has_envelope {
        configure_envelope(*voice.envelope, envelope_configuration, voice.sample_rate);
        trigger_attack(*voice.envelope);
    } else {
        reset_envelope(*voice.envelope);
    }
}

trigger_sampler_note_off :: (voice: *Sampler_Voice) {
    if voice.has_envelope {
        trigger_release(*voice.envelope);
    } else if !voice.is_one_shot {
        voice.is_active = false;
    }
}

reset_sampler_voice :: (voice: *Sampler_Voice) {
    voice.is_active = false;
    voice.playhead_frame = 0.0;
    voice.buffer = null;
    voice.choke_group = 0;
    voice.has_envelope = false;
    voice.is_looping = false;
    voice.loop_start_frame = 0;
    voice.loop_end_frame = 0;
    voice.start_offset_frame = 0;
    voice.is_reversed = false;
    reset_envelope(*voice.envelope);
}

is_sampler_voice_active :: (voice: *Sampler_Voice) -> bool {
    if !voice.is_active || voice.buffer == null {
        return false;
    }
    if voice.has_envelope {
        if !is_envelope_active(*voice.envelope) {
            return false;
        }
        if voice.envelope.state == .SUSTAIN && voice.envelope.sustain_level <= 0.0 {
            return false;
        }
    }

    return true;
}

render_sampler_frame :: (voice: *Sampler_Voice) -> float, float {
    if !voice.is_active || voice.buffer == null || voice.buffer.frame_count == 0 {
        return 0.0, 0.0;
    }

    effective_loop_start := voice.loop_start_frame;
    if effective_loop_start < 0 effective_loop_start = 0;

    effective_loop_end := voice.loop_end_frame;
    if effective_loop_end <= 0 || effective_loop_end > voice.buffer.frame_count {
        effective_loop_end = voice.buffer.frame_count;
    }
    if effective_loop_start >= effective_loop_end {
        effective_loop_start = 0;
    }

    if voice.is_looping && effective_loop_end > effective_loop_start {
        loop_length := effective_loop_end - effective_loop_start;
        if voice.is_reversed {
            while voice.playhead_frame < cast(float64) effective_loop_start {
                voice.playhead_frame += cast(float64) loop_length;
            }
        } else {
            while voice.playhead_frame >= cast(float64) effective_loop_end {
                voice.playhead_frame -= cast(float64) loop_length;
            }
        }
    } else {
        if voice.is_reversed {
            if voice.playhead_frame < 0.0 {
                voice.is_active = false;

                return 0.0, 0.0;
            }
        } else {
            if voice.playhead_frame >= cast(float64) voice.buffer.frame_count {
                voice.is_active = false;

                return 0.0, 0.0;
            }
        }
    }

    frame_index_0 := cast(s64) voice.playhead_frame;
    if frame_index_0 < 0 frame_index_0 = 0;
    if frame_index_0 >= voice.buffer.frame_count {
        voice.is_active = false;

        return 0.0, 0.0;
    }

    frame_index_1 := frame_index_0 + 1;
    if voice.is_looping && effective_loop_end > effective_loop_start {
        if frame_index_1 >= effective_loop_end {
            frame_index_1 = effective_loop_start;
        }
    } else {
        if frame_index_1 >= voice.buffer.frame_count {
            frame_index_1 = frame_index_0;
        }
    }

    fractional_part := cast(float) (voice.playhead_frame - cast(float64) frame_index_0);

    sample_0_left := get_sample_from_buffer(voice.buffer, frame_index_0, 0);
    sample_1_left := get_sample_from_buffer(voice.buffer, frame_index_1, 0);
    interpolated_left := sample_0_left + fractional_part * (sample_1_left - sample_0_left);

    sample_0_right := get_sample_from_buffer(voice.buffer, frame_index_0, 1);
    sample_1_right := get_sample_from_buffer(voice.buffer, frame_index_1, 1);
    interpolated_right := sample_0_right + fractional_part * (sample_1_right - sample_0_right);

    envelope_factor: float = 1.0;
    if voice.has_envelope {
        envelope_factor = process_envelope_sample(*voice.envelope);
        if !is_envelope_active(*voice.envelope) || (voice.envelope.state == .SUSTAIN && voice.envelope.sustain_level <= 0.0) {
            voice.is_active = false;
        }
    }

    output_left := interpolated_left * voice.velocity * voice.gain * envelope_factor;
    output_right := interpolated_right * voice.velocity * voice.gain * envelope_factor;

    if voice.is_reversed {
        voice.playhead_frame -= voice.playback_speed;
        if !voice.is_looping && voice.playhead_frame < 0.0 {
            voice.is_active = false;
        }
    } else {
        voice.playhead_frame += voice.playback_speed;
        if !voice.is_looping && voice.playhead_frame >= cast(float64) voice.buffer.frame_count {
            voice.is_active = false;
        }
    }

    return output_left, output_right;
}

render_sampler_sample :: (voice: *Sampler_Voice) -> float {
    left, right := render_sampler_frame(voice);

    return (left + right) * 0.5;
}

render_sampler_block_interleaved :: (voice: *Sampler_Voice, output_buffer: [] float) {
    sample_index := 0;
    while sample_index + 1 < output_buffer.count {
        if !voice.is_active {
            break;
        }

        left, right := render_sampler_frame(voice);
        output_buffer[sample_index] += left;
        output_buffer[sample_index + 1] += right;
        sample_index += 2;
    }
}

calculate_sampler_start_offset_frame :: (configuration: Sampler_Configuration, buffer: *Audio_Sample_Buffer) -> s64 {
    if buffer == null || buffer.frame_count <= 0 {
        return 0;
    }

    if configuration.start_offset_is_percentage {
        offset := cast(s64) (configuration.start_offset_percentage * cast(float) buffer.frame_count);
        if offset < 0 offset = 0;
        if offset >= buffer.frame_count offset = buffer.frame_count - 1;

        return offset;
    }

    if configuration.start_offset_is_milliseconds {
        seconds := configuration.start_offset_milliseconds / 1000.0;
        offset := cast(s64) (seconds * cast(float) buffer.sample_rate);
        if offset < 0 offset = 0;
        if offset >= buffer.frame_count offset = buffer.frame_count - 1;

        return offset;
    }

    offset := configuration.start_offset_frame;
    if offset < 0 offset = 0;
    if offset >= buffer.frame_count offset = buffer.frame_count - 1;

    return offset;
}

Audio_Sample_Buffer :: struct {
    file_path: string;
    samples: [] float;
    channel_count: s64 = 2;
    sample_rate: s64 = DEFAULT_SAMPLE_RATE;
    frame_count: s64 = 0;
    root_midi_note: s32 = 60;
}

Sampler_Voice :: struct {
    buffer: *Audio_Sample_Buffer = null;
    playhead_frame: float64 = 0.0;
    playback_speed: float64 = 1.0;
    gain: float = 1.0;
    velocity: float = 1.0;
    is_active: bool = false;
    is_one_shot: bool = true;
    sample_rate: s64 = DEFAULT_SAMPLE_RATE;
    choke_group: s32 = 0;
    envelope: Envelope_Generator;
    has_envelope: bool = false;
    is_looping: bool = false;
    loop_start_frame: s64 = 0;
    loop_end_frame: s64 = 0;
    start_offset_frame: s64 = 0;
    is_reversed: bool = false;
}
