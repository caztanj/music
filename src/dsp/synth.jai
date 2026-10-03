initialize_synthesizer_voice :: (voice: *Synthesizer_Voice, configuration: Synthesizer_Configuration, sample_rate: s64 = DEFAULT_SAMPLE_RATE) {
    voice.configuration = configuration;
    voice.sample_rate = sample_rate;
    voice.is_active = false;
    voice.oscillator_phase = 0.0;
    voice.filter_state_1 = 0.0;
    voice.filter_state_2 = 0.0;
    configure_envelope(*voice.amplitude_envelope, configuration.envelope, sample_rate);
}

trigger_synthesizer_note_on :: (voice: *Synthesizer_Voice, midi_note_number: s32, velocity: float = 1.0) {
    voice.midi_note_number = midi_note_number;
    voice.frequency_hertz = midi_to_hertz(midi_note_number);
    voice.velocity = velocity;
    voice.is_active = true;

    trigger_attack(*voice.amplitude_envelope);
}

trigger_synthesizer_note_off :: (voice: *Synthesizer_Voice) {
    trigger_release(*voice.amplitude_envelope);
}

reset_synthesizer_voice :: (voice: *Synthesizer_Voice) {
    voice.is_active = false;
    voice.oscillator_phase = 0.0;
    voice.filter_state_1 = 0.0;
    voice.filter_state_2 = 0.0;
    reset_envelope(*voice.amplitude_envelope);
}

is_synthesizer_voice_active :: (voice: *Synthesizer_Voice) -> bool {
    is_active := voice.is_active && is_envelope_active(*voice.amplitude_envelope);

    return is_active;
}

render_synthesizer_sample :: (voice: *Synthesizer_Voice) -> float {
    if !voice.is_active {
        return 0.0;
    }

    envelope_level := process_envelope_sample(*voice.amplitude_envelope);
    if !is_envelope_active(*voice.amplitude_envelope) {
        voice.is_active = false;

        return 0.0;
    }

    phase_increment := cast(float64) voice.frequency_hertz / cast(float64) voice.sample_rate;
    oscillator_sample := generate_oscillator_sample(voice.configuration.waveform, voice.oscillator_phase, phase_increment);

    voice.oscillator_phase += phase_increment;
    if voice.oscillator_phase >= 1.0 {
        voice.oscillator_phase -= 1.0;
    }

    filtered_sample := oscillator_sample;
    if voice.configuration.filter.type != .NONE {
        coefficients := calculate_biquad_coefficients(voice.configuration.filter.type, voice.configuration.filter.cutoff_frequency_hertz, voice.configuration.filter.resonance, voice.sample_rate);
        filtered_sample = process_biquad_filter(coefficients, oscillator_sample, *voice.filter_state_1, *voice.filter_state_2);
    }

    output_sample := filtered_sample * envelope_level * voice.velocity * voice.configuration.gain;

    if output_sample > 1.0 {
        output_sample = 1.0;
    } else if output_sample < -1.0 {
        output_sample = -1.0;
    }

    return output_sample;
}

render_synthesizer_block :: (voice: *Synthesizer_Voice, output_buffer: [] float) {
    sample_index := 0;
    while sample_index < output_buffer.count {
        output_buffer[sample_index] += render_synthesizer_sample(voice);
        sample_index += 1;
    }
}

generate_oscillator_sample :: (waveform_type: Waveform_Type, phase: float64, phase_increment: float64) -> float {
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

    state_1.* = coefficients.b1 * input_sample - coefficients.a1 * output_sample + state_2.*;
    state_2.* = coefficients.b2 * input_sample - coefficients.a2 * output_sample;

    if abs(state_1.*) < 0.000000000000001 {
        state_1.* = 0.0;
    }

    if abs(state_2.*) < 0.000000000000001 {
        state_2.* = 0.0;
    }

    return output_sample;
}

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
    frequency_hertz: float = 440.0;
    midi_note_number: s32 = 60;
    velocity: float = 1.0;
    amplitude_envelope: Envelope_Generator;
    filter_state_1: float = 0.0;
    filter_state_2: float = 0.0;
    sample_rate: s64 = DEFAULT_SAMPLE_RATE;
    is_active: bool = false;
}
