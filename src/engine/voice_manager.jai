initialize_voice_manager :: (voice_manager: *Voice_Manager, sample_rate: s64 = DEFAULT_SAMPLE_RATE) {
    voice_manager.sample_rate = sample_rate;
    voice_manager.total_rendered_samples = 0;

    voice_index := 0;
    while voice_index < MAXIMUM_VOICES {
        slot := *voice_manager.voices[voice_index];
        reset_voice_slot(slot);
        voice_index += 1;
    }
}

trigger_synthesizer_note :: (voice_manager: *Voice_Manager, instrument_name: string, mixer_track_index: s64, configuration: Synthesizer_Configuration, midi_note_number: s32, velocity: float = 1.0) -> *Voice_Slot {
    slot := find_available_voice_slot(voice_manager);
    slot.kind = .SYNTHESIZER;
    slot.instrument_name = instrument_name;
    slot.mixer_track_index = mixer_track_index;
    slot.midi_note_number = midi_note_number;
    slot.velocity = velocity;
    slot.age_samples = 0;

    initialize_synthesizer_voice(*slot.synthesizer_voice, configuration, voice_manager.sample_rate);
    trigger_synthesizer_note_on(*slot.synthesizer_voice, midi_note_number, velocity);

    return slot;
}

trigger_sampler_note :: (voice_manager: *Voice_Manager, instrument_name: string, mixer_track_index: s64, buffer: *Audio_Sample_Buffer, midi_note_number: s32 = 60, velocity: float = 1.0, is_one_shot: bool = true, gain: float = 1.0) -> *Voice_Slot {
    slot := find_available_voice_slot(voice_manager);
    slot.kind = .SAMPLER;
    slot.instrument_name = instrument_name;
    slot.mixer_track_index = mixer_track_index;
    slot.midi_note_number = midi_note_number;
    slot.velocity = velocity;
    slot.age_samples = 0;

    initialize_sampler_voice(*slot.sampler_voice, voice_manager.sample_rate);
    trigger_sampler_note_on(*slot.sampler_voice, buffer, midi_note_number, velocity, is_one_shot, gain);

    return slot;
}

trigger_note_off :: (voice_manager: *Voice_Manager, instrument_name: string, midi_note_number: s32) {
    voice_index := 0;
    while voice_index < MAXIMUM_VOICES {
        slot := *voice_manager.voices[voice_index];
        if slot.kind != .INACTIVE && slot.instrument_name == instrument_name && slot.midi_note_number == midi_note_number && is_voice_active(slot) {
            if slot.kind == {
                case .SYNTHESIZER;
                    trigger_synthesizer_note_off(*slot.synthesizer_voice);

                case .SAMPLER;
                    trigger_sampler_note_off(*slot.sampler_voice);

                case;
            }
        }

        voice_index += 1;
    }
}

stop_all_voices :: (voice_manager: *Voice_Manager) {
    voice_index := 0;
    while voice_index < MAXIMUM_VOICES {
        slot := *voice_manager.voices[voice_index];
        reset_voice_slot(slot);
        voice_index += 1;
    }
}

count_active_voices :: (voice_manager: *Voice_Manager) -> s64 {
    active_count: s64 = 0;
    voice_index := 0;
    while voice_index < MAXIMUM_VOICES {
        slot := *voice_manager.voices[voice_index];
        if slot.kind != .INACTIVE && is_voice_active(slot) {
            active_count += 1;
        }

        voice_index += 1;
    }

    return active_count;
}

render_voice_sample :: (slot: *Voice_Slot) -> float, float {
    if slot.kind == {
        case .SYNTHESIZER;
            sample := render_synthesizer_sample(*slot.synthesizer_voice);
            slot.age_samples += 1;
            if !is_synthesizer_voice_active(*slot.synthesizer_voice) {
                slot.kind = .INACTIVE;
            }

            return sample, sample;

        case .SAMPLER;
            left_sample, right_sample := render_sampler_frame(*slot.sampler_voice);
            slot.age_samples += 1;
            if !is_sampler_voice_active(*slot.sampler_voice) {
                slot.kind = .INACTIVE;
            }

            return left_sample, right_sample;

        case;
            return 0.0, 0.0;
    }
}

render_voices_into_buffer :: (voice_manager: *Voice_Manager, output_left_buffer: [] float, output_right_buffer: [] float) {
    sample_count := output_left_buffer.count;
    if output_right_buffer.count < sample_count {
        sample_count = output_right_buffer.count;
    }

    voice_index := 0;
    while voice_index < MAXIMUM_VOICES {
        slot := *voice_manager.voices[voice_index];
        if slot.kind != .INACTIVE && is_voice_active(slot) {
            sample_index := 0;
            while sample_index < sample_count {
                left_sample, right_sample := render_voice_sample(slot);
                output_left_buffer[sample_index] += left_sample;
                output_right_buffer[sample_index] += right_sample;
                if slot.kind == .INACTIVE {
                    break;
                }
                sample_index += 1;
            }
        }

        voice_index += 1;
    }

    voice_manager.total_rendered_samples += cast(u64) sample_count;
}

render_track_voices_into_buffer :: (voice_manager: *Voice_Manager, target_track_index: s64, output_left_buffer: [] float, output_right_buffer: [] float) {
    sample_count := output_left_buffer.count;
    if output_right_buffer.count < sample_count {
        sample_count = output_right_buffer.count;
    }

    voice_index := 0;
    while voice_index < MAXIMUM_VOICES {
        slot := *voice_manager.voices[voice_index];
        if slot.kind != .INACTIVE && slot.mixer_track_index == target_track_index && is_voice_active(slot) {
            sample_index := 0;
            while sample_index < sample_count {
                left_sample, right_sample := render_voice_sample(slot);
                output_left_buffer[sample_index] += left_sample;
                output_right_buffer[sample_index] += right_sample;
                if slot.kind == .INACTIVE {
                    break;
                }
                sample_index += 1;
            }
        }

        voice_index += 1;
    }
}

is_voice_active :: (slot: *Voice_Slot) -> bool {
    if slot.kind == {
        case .SYNTHESIZER;
            return is_synthesizer_voice_active(*slot.synthesizer_voice);

        case .SAMPLER;
            return is_sampler_voice_active(*slot.sampler_voice);

        case;
            return false;
    }
}

find_available_voice_slot :: (voice_manager: *Voice_Manager) -> *Voice_Slot {
    voice_index := 0;
    while voice_index < MAXIMUM_VOICES {
        slot := *voice_manager.voices[voice_index];
        if slot.kind == .INACTIVE || !is_voice_active(slot) {
            reset_voice_slot(slot);

            return slot;
        }

        voice_index += 1;
    }

    best_releasing_slot: *Voice_Slot = null;
    lowest_releasing_level: float = 1000.0;

    best_playing_slot: *Voice_Slot = null;
    lowest_effective_volume: float = 1000.0;
    oldest_playing_age: u64 = 0;

    voice_index = 0;
    while voice_index < MAXIMUM_VOICES {
        slot := *voice_manager.voices[voice_index];

        if slot.kind == .SYNTHESIZER && slot.synthesizer_voice.amplitude_envelope.state == .RELEASE {
            current_level := slot.synthesizer_voice.amplitude_envelope.current_level;
            if current_level < lowest_releasing_level {
                lowest_releasing_level = current_level;
                best_releasing_slot = slot;
            }
        }

        effective_volume := slot.velocity;
        if slot.kind == .SYNTHESIZER {
            effective_volume *= slot.synthesizer_voice.amplitude_envelope.current_level;
        }

        if effective_volume < lowest_effective_volume || (effective_volume == lowest_effective_volume && slot.age_samples > oldest_playing_age) {
            lowest_effective_volume = effective_volume;
            oldest_playing_age = slot.age_samples;
            best_playing_slot = slot;
        }

        voice_index += 1;
    }

    if best_releasing_slot != null {
        reset_voice_slot(best_releasing_slot);

        return best_releasing_slot;
    }

    if best_playing_slot != null {
        reset_voice_slot(best_playing_slot);

        return best_playing_slot;
    }

    fallback_slot := *voice_manager.voices[0];
    reset_voice_slot(fallback_slot);

    return fallback_slot;
}

reset_voice_slot :: (slot: *Voice_Slot) {
    if slot.kind == {
        case .SYNTHESIZER;
            reset_synthesizer_voice(*slot.synthesizer_voice);

        case .SAMPLER;
            reset_sampler_voice(*slot.sampler_voice);

        case;
    }

    slot.kind = .INACTIVE;
    slot.age_samples = 0;
    slot.instrument_name = "";
    slot.mixer_track_index = 1;
    slot.midi_note_number = 60;
    slot.velocity = 1.0;
}

MAXIMUM_VOICES :: 128;

Voice_Kind :: enum {
    INACTIVE;
    SYNTHESIZER;
    SAMPLER;
}

Voice_Slot :: struct {
    kind: Voice_Kind = .INACTIVE;
    instrument_name: string;
    mixer_track_index: s64 = 1;
    midi_note_number: s32 = 60;
    velocity: float = 1.0;
    age_samples: u64 = 0;
    synthesizer_voice: Synthesizer_Voice;
    sampler_voice: Sampler_Voice;
}

Voice_Manager :: struct {
    voices: [MAXIMUM_VOICES] Voice_Slot;
    sample_rate: s64 = DEFAULT_SAMPLE_RATE;
    total_rendered_samples: u64 = 0;
}
