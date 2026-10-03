initialize_synthesizer_voice :: (voice: *Synthesizer_Voice, configuration: Synthesizer_Configuration, sample_rate: s64 = DEFAULT_SAMPLE_RATE) {
    voice.configuration = configuration;
    voice.sample_rate = sample_rate;
    voice.is_active = false;
    voice.oscillator_phase = 0.0;
    voice.oscillator_2_phase = 0.0;
    voice.noise_seed = 1234567;
    voice.pink_noise_state_0 = 0.0;
    voice.pink_noise_state_1 = 0.0;
    voice.pink_noise_state_2 = 0.0;
    voice.filter_state_1 = 0.0;
    voice.filter_state_2 = 0.0;
    voice.filter_right_state_1 = 0.0;
    voice.filter_right_state_2 = 0.0;

    unison_index := 0;
    while unison_index < MAXIMUM_UNISON_VOICES {
        voice.unison_phases[unison_index] = 0.0;
        voice.unison_oscillator_2_phases[unison_index] = 0.0;
        unison_index += 1;
    }

    configure_envelope(*voice.amplitude_envelope, configuration.envelope, sample_rate);
    configure_envelope(*voice.filter_envelope, configuration.filter.envelope, sample_rate);
}

trigger_synthesizer_note_on :: (voice: *Synthesizer_Voice, midi_note_number: s32, velocity: float = 1.0) {
    voice.midi_note_number = midi_note_number;
    voice.frequency_hertz = midi_to_hertz(midi_note_number);
    voice.velocity = velocity;
    voice.is_active = true;
    voice.noise_seed ^= cast(u32) (midi_note_number * 104729 + 19);

    golden_ratio_fraction := 0.618033988749895;
    unison_index := 0;
    while unison_index < MAXIMUM_UNISON_VOICES {
        initial_phase := cast(float64) unison_index * golden_ratio_fraction;
        voice.unison_phases[unison_index] = initial_phase - cast(float64) cast(s64) initial_phase;
        initial_phase_2 := cast(float64) (unison_index + 3) * golden_ratio_fraction;
        voice.unison_oscillator_2_phases[unison_index] = initial_phase_2 - cast(float64) cast(s64) initial_phase_2;
        unison_index += 1;
    }

    voice.oscillator_phase = voice.unison_phases[0];
    voice.oscillator_2_phase = voice.unison_oscillator_2_phases[0];

    trigger_attack(*voice.amplitude_envelope);
    trigger_attack(*voice.filter_envelope);
}

trigger_synthesizer_note_off :: (voice: *Synthesizer_Voice) {
    trigger_release(*voice.amplitude_envelope);
    trigger_release(*voice.filter_envelope);
}

reset_synthesizer_voice :: (voice: *Synthesizer_Voice) {
    voice.is_active = false;
    voice.oscillator_phase = 0.0;
    voice.oscillator_2_phase = 0.0;
    voice.pink_noise_state_0 = 0.0;
    voice.pink_noise_state_1 = 0.0;
    voice.pink_noise_state_2 = 0.0;
    voice.filter_state_1 = 0.0;
    voice.filter_state_2 = 0.0;
    voice.filter_right_state_1 = 0.0;
    voice.filter_right_state_2 = 0.0;

    unison_index := 0;
    while unison_index < MAXIMUM_UNISON_VOICES {
        voice.unison_phases[unison_index] = 0.0;
        voice.unison_oscillator_2_phases[unison_index] = 0.0;
        unison_index += 1;
    }

    reset_envelope(*voice.amplitude_envelope);
    reset_envelope(*voice.filter_envelope);
}

is_synthesizer_voice_active :: (voice: *Synthesizer_Voice) -> bool {
    is_active := voice.is_active && is_envelope_active(*voice.amplitude_envelope);

    return is_active;
}

calculate_detuned_frequency :: (base_frequency_hertz: float, semitones: s32, cents: float) -> float {
    if semitones == 0 && cents == 0.0 {
        return base_frequency_hertz;
    }

    total_semitones := cast(float64) semitones + (cast(float64) cents / 100.0);
    frequency_multiplier := pow(2.0, total_semitones / 12.0);
    detuned_frequency := cast(float) (cast(float64) base_frequency_hertz * frequency_multiplier);

    return detuned_frequency;
}

generate_white_noise_sample :: (noise_seed: *u32) -> float {
    noise_seed.* = noise_seed.* * 1664525 + 1013904223;
    normalized_value := cast(float) (noise_seed.* & 0x00FFFFFF) / 16777215.0;
    sample_value := normalized_value * 2.0 - 1.0;

    return sample_value;
}

generate_pink_noise_sample :: (noise_seed: *u32, state_0: *float, state_1: *float, state_2: *float) -> float {
    white_sample := generate_white_noise_sample(noise_seed);

    state_0.* = 0.99886 * state_0.* + white_sample * 0.0555179;
    state_1.* = 0.99332 * state_1.* + white_sample * 0.0750759;
    state_2.* = 0.96900 * state_2.* + white_sample * 0.1538520;

    pink_sample := (state_0.* + state_1.* + state_2.* + white_sample * 0.5362) * 0.11;

    return pink_sample;
}

render_synthesizer_frame :: (voice: *Synthesizer_Voice) -> float, float {
    if !voice.is_active {
        return 0.0, 0.0;
    }

    envelope_level := process_envelope_sample(*voice.amplitude_envelope);
    if !is_envelope_active(*voice.amplitude_envelope) {
        voice.is_active = false;

        return 0.0, 0.0;
    }

    filter_envelope_level := process_envelope_sample(*voice.filter_envelope);

    unison_voice_count := voice.configuration.unison_voices;
    if unison_voice_count < 1 {
        unison_voice_count = 1;
    } else if unison_voice_count > MAXIMUM_UNISON_VOICES {
        unison_voice_count = MAXIMUM_UNISON_VOICES;
    }

    effective_detune_cents := voice.configuration.unison_detune;
    if effective_detune_cents > 0.0 && effective_detune_cents <= 1.0 {
        effective_detune_cents *= 50.0;
    }

    left_accumulator := 0.0;
    right_accumulator := 0.0;

    unison_index := 0;
    while unison_index < unison_voice_count {
        cents_offset := 0.0;
        pan_factor := 0.0;

        if unison_voice_count > 1 {
            normalized_spread := -1.0 + 2.0 * (cast(float) unison_index) / cast(float) (unison_voice_count - 1);
            cents_offset = normalized_spread * effective_detune_cents;
            pan_factor = normalized_spread * voice.configuration.unison_spread;
        }

        voice_frequency := calculate_detuned_frequency(voice.frequency_hertz, 0, cents_offset);
        phase_increment := cast(float64) voice_frequency / cast(float64) voice.sample_rate;
        current_phase := voice.unison_phases[unison_index];

        oscillator_sample := generate_oscillator_sample(
            voice.configuration.waveform,
            current_phase,
            phase_increment,
            *voice.noise_seed,
            *voice.pink_noise_state_0,
            *voice.pink_noise_state_1,
            *voice.pink_noise_state_2
        );

        current_phase += phase_increment;
        if current_phase >= 1.0 {
            current_phase -= 1.0;
        }
        voice.unison_phases[unison_index] = current_phase;

        if voice.configuration.oscillator_2_enabled {
            frequency_2 := calculate_detuned_frequency(
                voice_frequency,
                voice.configuration.oscillator_2_semitones,
                voice.configuration.oscillator_2_cents
            );
            phase_increment_2 := cast(float64) frequency_2 / cast(float64) voice.sample_rate;
            current_phase_2 := voice.unison_oscillator_2_phases[unison_index];

            oscillator_2_sample := generate_oscillator_sample(
                voice.configuration.oscillator_2_waveform,
                current_phase_2,
                phase_increment_2,
                *voice.noise_seed,
                *voice.pink_noise_state_0,
                *voice.pink_noise_state_1,
                *voice.pink_noise_state_2
            );

            current_phase_2 += phase_increment_2;
            if current_phase_2 >= 1.0 {
                current_phase_2 -= 1.0;
            }
            voice.unison_oscillator_2_phases[unison_index] = current_phase_2;

            oscillator_sample = (1.0 - voice.configuration.oscillator_mix) * oscillator_sample + voice.configuration.oscillator_mix * oscillator_2_sample;
        }

        if pan_factor < -1.0 {
            pan_factor = -1.0;
        } else if pan_factor > 1.0 {
            pan_factor = 1.0;
        }

        pan_left_gain := ifx pan_factor <= 0.0 then 1.0 else (1.0 - pan_factor);
        pan_right_gain := ifx pan_factor >= 0.0 then 1.0 else (1.0 + pan_factor);

        left_accumulator += oscillator_sample * pan_left_gain;
        right_accumulator += oscillator_sample * pan_right_gain;

        unison_index += 1;
    }

    voice.oscillator_phase = voice.unison_phases[0];
    voice.oscillator_2_phase = voice.unison_oscillator_2_phases[0];

    unison_normalization := ifx unison_voice_count > 1 then (1.0 / sqrt(cast(float) unison_voice_count)) else 1.0;
    left_oscillator := left_accumulator * unison_normalization;
    right_oscillator := right_accumulator * unison_normalization;

    if voice.configuration.noise_level > 0.0 {
        noise_sample := generate_oscillator_sample(
            voice.configuration.noise_type,
            0.0,
            0.0,
            *voice.noise_seed,
            *voice.pink_noise_state_0,
            *voice.pink_noise_state_1,
            *voice.pink_noise_state_2
        );
        noise_contribution := noise_sample * voice.configuration.noise_level;
        left_oscillator += noise_contribution;
        right_oscillator += noise_contribution;
    }

    left_filtered := left_oscillator;
    right_filtered := right_oscillator;

    if voice.configuration.filter.type != .NONE {
        effective_cutoff := voice.configuration.filter.cutoff_frequency_hertz;
        if voice.configuration.filter.envelope_amount != 0.0 {
            modulation_amount := voice.configuration.filter.envelope_amount;
            if modulation_amount > 1.0 || modulation_amount < -1.0 {
                modulation_amount /= 100.0;
            }

            octave_range := 5.0;
            cutoff_multiplier := cast(float) pow(2.0, cast(float64) (filter_envelope_level * modulation_amount * octave_range));
            effective_cutoff *= cutoff_multiplier;
        }

        if effective_cutoff < 60.0 {
            effective_cutoff = 60.0;
        }

        coefficients := calculate_biquad_coefficients(
            voice.configuration.filter.type,
            effective_cutoff,
            voice.configuration.filter.resonance,
            voice.sample_rate
        );
        left_filtered = process_biquad_filter(coefficients, left_oscillator, *voice.filter_state_1, *voice.filter_state_2);
        right_filtered = process_biquad_filter(coefficients, right_oscillator, *voice.filter_right_state_1, *voice.filter_right_state_2);
    }

    gain_scaling := envelope_level * voice.velocity * voice.configuration.gain;
    left_output := left_filtered * gain_scaling;
    right_output := right_filtered * gain_scaling;

    if left_output > 1.0 {
        left_output = 1.0;
    } else if left_output < -1.0 {
        left_output = -1.0;
    }

    if right_output > 1.0 {
        right_output = 1.0;
    } else if right_output < -1.0 {
        right_output = -1.0;
    }

    return left_output, right_output;
}

render_synthesizer_sample :: (voice: *Synthesizer_Voice) -> float {
    left_sample, right_sample := render_synthesizer_frame(voice);
    mono_sample := (left_sample + right_sample) * 0.5;

    return mono_sample;
}

render_synthesizer_block :: (voice: *Synthesizer_Voice, output_buffer: [] float) {
    sample_index := 0;
    while sample_index < output_buffer.count {
        output_buffer[sample_index] += render_synthesizer_sample(voice);
        sample_index += 1;
    }
}

generate_oscillator_sample :: (
    waveform_type: Waveform_Type,
    phase: float64,
    phase_increment: float64,
    noise_seed: *u32 = null,
    pink_state_0: *float = null,
    pink_state_1: *float = null,
    pink_state_2: *float = null
) -> float {
    if waveform_type == {
        case .SINE;
            return cast(float) sin(phase * 2.0 * PI);

        case .SAWTOOTH;
            naive_sample := cast(float) (2.0 * phase - 1.0);
            correction := polyblep_residual(phase, phase_increment);

            return naive_sample - correction;

        case .SQUARE;
            naive_sample := ifx phase < 0.5 then 1.0 else -1.0;
            correction_start := polyblep_residual(phase, phase_increment);
            phase_half := phase + 0.5;
            if phase_half >= 1.0 {
                phase_half -= 1.0;
            }
            correction_middle := polyblep_residual(phase_half, phase_increment);

            return naive_sample + correction_start - correction_middle;

        case .TRIANGLE;
            naive_sample := ifx phase < 0.5 then cast(float)(4.0 * phase - 1.0) else cast(float)(3.0 - 4.0 * phase);

            return naive_sample;

        case .WHITE_NOISE;
            local_seed: u32 = 1234567;
            effective_seed := ifx noise_seed != null then noise_seed else *local_seed;

            return generate_white_noise_sample(effective_seed);

        case .PINK_NOISE;
            local_seed: u32 = 1234567;
            local_state_0: float = 0.0;
            local_state_1: float = 0.0;
            local_state_2: float = 0.0;
            effective_seed := ifx noise_seed != null then noise_seed else *local_seed;
            effective_state_0 := ifx pink_state_0 != null then pink_state_0 else *local_state_0;
            effective_state_1 := ifx pink_state_1 != null then pink_state_1 else *local_state_1;
            effective_state_2 := ifx pink_state_2 != null then pink_state_2 else *local_state_2;

            return generate_pink_noise_sample(effective_seed, effective_state_0, effective_state_1, effective_state_2);

        case;
            return 0.0;
    }
}

polyblep_residual :: (phase: float64, phase_increment: float64) -> float {
    if phase < phase_increment {
        ratio := phase / phase_increment;

        return cast(float) (2.0 * ratio - ratio * ratio - 1.0);
    } else if phase > 1.0 - phase_increment {
        ratio := (phase - 1.0) / phase_increment;

        return cast(float) (ratio * ratio + 2.0 * ratio + 1.0);
    }

    return 0.0;
}

calculate_biquad_coefficients :: (filter_type: Filter_Type, cutoff_frequency_hertz: float, resonance: float, sample_rate: s64) -> Biquad_Coefficients {
    coefficients: Biquad_Coefficients;

    if filter_type == .NONE || sample_rate <= 0 {
        return coefficients;
    }

    nyquist_frequency := cast(float) sample_rate * 0.49;
    clamped_cutoff := cutoff_frequency_hertz;
    if clamped_cutoff < 20.0 {
        clamped_cutoff = 20.0;
    } else if clamped_cutoff > nyquist_frequency {
        clamped_cutoff = nyquist_frequency;
    }

    quality_factor := 0.707 + cast(float64) resonance * 4.0;
    angular_frequency := 2.0 * PI * cast(float64) clamped_cutoff / cast(float64) sample_rate;
    sine_value := sin(angular_frequency);
    cosine_value := cos(angular_frequency);
    alpha := sine_value / (2.0 * quality_factor);

    raw_b0: float64 = 0.0;
    raw_b1: float64 = 0.0;
    raw_b2: float64 = 0.0;
    raw_a0 := 1.0 + alpha;
    raw_a1 := -2.0 * cosine_value;
    raw_a2 := 1.0 - alpha;

    if filter_type == {
        case .LOWPASS;
            raw_b0 = (1.0 - cosine_value) * 0.5;
            raw_b1 = 1.0 - cosine_value;
            raw_b2 = (1.0 - cosine_value) * 0.5;

        case .HIGHPASS;
            raw_b0 = (1.0 + cosine_value) * 0.5;
            raw_b1 = -(1.0 + cosine_value);
            raw_b2 = (1.0 + cosine_value) * 0.5;

        case .BANDPASS;
            raw_b0 = alpha;
            raw_b1 = 0.0;
            raw_b2 = -alpha;

        case;
            return coefficients;
    }

    inverse_a0 := 1.0 / raw_a0;
    coefficients.b0 = cast(float) (raw_b0 * inverse_a0);
    coefficients.b1 = cast(float) (raw_b1 * inverse_a0);
    coefficients.b2 = cast(float) (raw_b2 * inverse_a0);
    coefficients.a1 = cast(float) (raw_a1 * inverse_a0);
    coefficients.a2 = cast(float) (raw_a2 * inverse_a0);

    return coefficients;
}

process_biquad_filter :: (coefficients: Biquad_Coefficients, input_sample: float, state_1: *float, state_2: *float) -> float {
    output_sample := coefficients.b0 * input_sample + state_1.*;

    if output_sample > 2.0 {
        output_sample = 2.0;
    } else if output_sample < -2.0 {
        output_sample = -2.0;
    }

    state_1.* = coefficients.b1 * input_sample - coefficients.a1 * output_sample + state_2.*;
    state_2.* = coefficients.b2 * input_sample - coefficients.a2 * output_sample;

    if state_1.* > 2.0 {
        state_1.* = 2.0;
    } else if state_1.* < -2.0 {
        state_1.* = -2.0;
    }

    if state_2.* > 2.0 {
        state_2.* = 2.0;
    } else if state_2.* < -2.0 {
        state_2.* = -2.0;
    }

    if abs(state_1.*) < 0.000000000000001 {
        state_1.* = 0.0;
    }

    if abs(state_2.*) < 0.000000000000001 {
        state_2.* = 0.0;
    }

    return output_sample;
}

MAXIMUM_UNISON_VOICES :: 8;

Biquad_Coefficients :: struct {
    b0: float = 1.0;
    b1: float = 0.0;
    b2: float = 0.0;
    a1: float = 0.0;
    a2: float = 0.0;
}

Synthesizer_Voice :: struct {
    configuration: Synthesizer_Configuration;
    oscillator_phase: float64 = 0.0;
    oscillator_2_phase: float64 = 0.0;
    unison_phases: [MAXIMUM_UNISON_VOICES] float64;
    unison_oscillator_2_phases: [MAXIMUM_UNISON_VOICES] float64;
    frequency_hertz: float = 440.0;
    midi_note_number: s32 = 60;
    velocity: float = 1.0;
    amplitude_envelope: Envelope_Generator;
    filter_envelope: Envelope_Generator;
    filter_state_1: float = 0.0;
    filter_state_2: float = 0.0;
    filter_right_state_1: float = 0.0;
    filter_right_state_2: float = 0.0;
    sample_rate: s64 = DEFAULT_SAMPLE_RATE;
    is_active: bool = false;
    noise_seed: u32 = 1234567;
    pink_noise_state_0: float = 0.0;
    pink_noise_state_1: float = 0.0;
    pink_noise_state_2: float = 0.0;
}
