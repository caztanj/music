configure_envelope :: (envelope_generator: *Envelope_Generator, configuration: Envelope_Configuration, sample_rate: s64 = DEFAULT_SAMPLE_RATE) {
    envelope_generator.sample_rate = sample_rate;
    envelope_generator.sustain_level = configuration.sustain_level;

    if envelope_generator.sustain_level < 0.0 {
        envelope_generator.sustain_level = 0.0;
    } else if envelope_generator.sustain_level > 1.0 {
        envelope_generator.sustain_level = 1.0;
    }

    envelope_generator.attack_samples = cast(s64) ((configuration.attack_milliseconds / 1000.0) * cast(float) sample_rate);
    envelope_generator.decay_samples = cast(s64) ((configuration.decay_milliseconds / 1000.0) * cast(float) sample_rate);
    envelope_generator.release_samples = cast(s64) ((configuration.release_milliseconds / 1000.0) * cast(float) sample_rate);

    if envelope_generator.attack_samples < 1 {
        envelope_generator.attack_samples = 1;
    }

    if envelope_generator.decay_samples < 1 {
        envelope_generator.decay_samples = 1;
    }

    if envelope_generator.release_samples < 1 {
        envelope_generator.release_samples = 1;
    }

    envelope_generator.attack_step = 1.0 / cast(float) envelope_generator.attack_samples;
    envelope_generator.decay_step = (1.0 - envelope_generator.sustain_level) / cast(float) envelope_generator.decay_samples;
    envelope_generator.release_multiplier = cast(float) pow(0.001, 1.0 / cast(float64) envelope_generator.release_samples);
}

trigger_attack :: (envelope_generator: *Envelope_Generator) {
    envelope_generator.state = .ATTACK;
    envelope_generator.samples_in_current_stage = 0;

    if envelope_generator.current_level < 0.0 {
        envelope_generator.current_level = 0.0;
    } else if envelope_generator.current_level > 1.0 {
        envelope_generator.current_level = 1.0;
    }

    remaining_level := 1.0 - envelope_generator.current_level;
    if envelope_generator.attack_samples > 0 {
        envelope_generator.attack_step = remaining_level / cast(float) envelope_generator.attack_samples;
    } else {
        envelope_generator.current_level = 1.0;
        envelope_generator.state = .DECAY;
    }
}

trigger_release :: (envelope_generator: *Envelope_Generator) {
    if envelope_generator.state == .IDLE {
        return;
    }

    envelope_generator.state = .RELEASE;
    envelope_generator.samples_in_current_stage = 0;

    if envelope_generator.release_samples <= 0 {
        envelope_generator.current_level = 0.0;
        envelope_generator.state = .IDLE;
    }
}

reset_envelope :: (envelope_generator: *Envelope_Generator) {
    envelope_generator.state = .IDLE;
    envelope_generator.current_level = 0.0;
    envelope_generator.samples_in_current_stage = 0;
}

process_envelope_sample :: (envelope_generator: *Envelope_Generator) -> float {
    if envelope_generator.state == {
        case .IDLE;
            return 0.0;

        case .ATTACK;
            envelope_generator.current_level += envelope_generator.attack_step;
            envelope_generator.samples_in_current_stage += 1;

            if envelope_generator.samples_in_current_stage >= envelope_generator.attack_samples || envelope_generator.current_level >= 1.0 {
                envelope_generator.current_level = 1.0;
                envelope_generator.state = .DECAY;
                envelope_generator.samples_in_current_stage = 0;
            }

            return envelope_generator.current_level;

        case .DECAY;
            envelope_generator.current_level -= envelope_generator.decay_step;
            envelope_generator.samples_in_current_stage += 1;

            if envelope_generator.samples_in_current_stage >= envelope_generator.decay_samples || envelope_generator.current_level <= envelope_generator.sustain_level {
                envelope_generator.current_level = envelope_generator.sustain_level;
                envelope_generator.state = .SUSTAIN;
                envelope_generator.samples_in_current_stage = 0;
            }

            return envelope_generator.current_level;

        case .SUSTAIN;
            return envelope_generator.current_level;

        case .RELEASE;
            envelope_generator.current_level *= envelope_generator.release_multiplier;
            envelope_generator.samples_in_current_stage += 1;

            if envelope_generator.current_level <= 0.0001 || envelope_generator.samples_in_current_stage >= envelope_generator.release_samples {
                envelope_generator.current_level = 0.0;
                envelope_generator.state = .IDLE;
                envelope_generator.samples_in_current_stage = 0;
            }

            return envelope_generator.current_level;

        case;
            return 0.0;
    }
}

is_envelope_active :: (envelope_generator: *Envelope_Generator) -> bool {
    is_active := envelope_generator.state != .IDLE;

    return is_active;
}

Envelope_State :: enum {
    IDLE;
    ATTACK;
    DECAY;
    SUSTAIN;
    RELEASE;
}

Envelope_Generator :: struct {
    state: Envelope_State = .IDLE;
    current_level: float = 0.0;
    sustain_level: float = 0.7;
    attack_step: float = 0.0;
    decay_step: float = 0.0;
    release_multiplier: float = 0.0;
    attack_samples: s64 = 0;
    decay_samples: s64 = 0;
    release_samples: s64 = 0;
    samples_in_current_stage: s64 = 0;
    sample_rate: s64 = DEFAULT_SAMPLE_RATE;
}
