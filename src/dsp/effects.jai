initialize_stereo_delay :: (stereo_delay: *Stereo_Delay, sample_rate: s64 = DEFAULT_SAMPLE_RATE) {
    stereo_delay.sample_rate = sample_rate;
    stereo_delay.write_index = 0;
    stereo_delay.delay_time_seconds = 0.25;
    stereo_delay.feedback = 0.35;
    stereo_delay.dry_level = 1.0;
    stereo_delay.wet_level = 0.5;

    if stereo_delay.left_delay_buffer.count == 0 {
        stereo_delay.left_delay_buffer = NewArray(MAXIMUM_DELAY_FRAMES, float);
        stereo_delay.right_delay_buffer = NewArray(MAXIMUM_DELAY_FRAMES, float);
    }

    reset_stereo_delay(stereo_delay);
}

configure_stereo_delay :: (stereo_delay: *Stereo_Delay, delay_time_seconds: float, feedback: float, wet_level: float = 0.5, dry_level: float = 1.0) {
    stereo_delay.delay_time_seconds = delay_time_seconds;
    stereo_delay.feedback = feedback;
    stereo_delay.wet_level = wet_level;
    stereo_delay.dry_level = dry_level;

    if stereo_delay.feedback > 0.95 {
        stereo_delay.feedback = 0.95;
    } else if stereo_delay.feedback < 0.0 {
        stereo_delay.feedback = 0.0;
    }
}

reset_stereo_delay :: (stereo_delay: *Stereo_Delay) {
    stereo_delay.write_index = 0;
    frame_index := 0;
    while frame_index < stereo_delay.left_delay_buffer.count {
        stereo_delay.left_delay_buffer[frame_index] = 0.0;
        stereo_delay.right_delay_buffer[frame_index] = 0.0;
        frame_index += 1;
    }
}

deinitialize_stereo_delay :: (stereo_delay: *Stereo_Delay) {
    if stereo_delay.left_delay_buffer.data != null {
        array_free(stereo_delay.left_delay_buffer);
        stereo_delay.left_delay_buffer.data = null;
        stereo_delay.left_delay_buffer.count = 0;
    }

    if stereo_delay.right_delay_buffer.data != null {
        array_free(stereo_delay.right_delay_buffer);
        stereo_delay.right_delay_buffer.data = null;
        stereo_delay.right_delay_buffer.count = 0;
    }
}

process_stereo_delay :: (stereo_delay: *Stereo_Delay, input_left: float, input_right: float) -> float, float {
    if stereo_delay.left_delay_buffer.count == 0 {
        return input_left, input_right;
    }

    delay_samples := cast(s64) (stereo_delay.delay_time_seconds * cast(float) stereo_delay.sample_rate);
    if delay_samples < 1 {
        delay_samples = 1;
    } else if delay_samples >= stereo_delay.left_delay_buffer.count {
        delay_samples = stereo_delay.left_delay_buffer.count - 1;
    }

    read_index := stereo_delay.write_index - delay_samples;
    if read_index < 0 {
        read_index += stereo_delay.left_delay_buffer.count;
    }


    delayed_left := stereo_delay.left_delay_buffer[read_index];
    delayed_right := stereo_delay.right_delay_buffer[read_index];

    new_left := input_left + delayed_left * stereo_delay.feedback;
    new_right := input_right + delayed_right * stereo_delay.feedback;

    if abs(new_left) < 0.000000000000001 {
        new_left = 0.0;
    }

    if abs(new_right) < 0.000000000000001 {
        new_right = 0.0;
    }

    stereo_delay.left_delay_buffer[stereo_delay.write_index] = new_left;
    stereo_delay.right_delay_buffer[stereo_delay.write_index] = new_right;

    stereo_delay.write_index = (stereo_delay.write_index + 1) % stereo_delay.left_delay_buffer.count;

    output_left := input_left * stereo_delay.dry_level + delayed_left * stereo_delay.wet_level;
    output_right := input_right * stereo_delay.dry_level + delayed_right * stereo_delay.wet_level;

    return output_left, output_right;
}

initialize_filter_insert :: (filter_insert: *Filter_Insert, sample_rate: s64 = DEFAULT_SAMPLE_RATE) {
    filter_insert.sample_rate = sample_rate;
    filter_insert.filter_type = .NONE;
    filter_insert.cutoff_frequency_hertz = 20000.0;
    filter_insert.resonance = 0.0;
    reset_filter_insert(filter_insert);
}

configure_filter_insert :: (filter_insert: *Filter_Insert, filter_type: Filter_Type, cutoff_frequency_hertz: float, resonance: float) {
    filter_insert.filter_type = filter_type;
    filter_insert.cutoff_frequency_hertz = cutoff_frequency_hertz;
    filter_insert.resonance = resonance;

    filter_insert.coefficients = calculate_biquad_coefficients(filter_type, cutoff_frequency_hertz, resonance, filter_insert.sample_rate);
}

reset_filter_insert :: (filter_insert: *Filter_Insert) {
    filter_insert.left_state_1 = 0.0;
    filter_insert.left_state_2 = 0.0;
    filter_insert.right_state_1 = 0.0;
    filter_insert.right_state_2 = 0.0;
}

process_filter_insert :: (filter_insert: *Filter_Insert, input_left: float, input_right: float) -> float, float {
    if filter_insert.filter_type == .NONE {
        return input_left, input_right;
    }

    output_left := process_biquad_filter(filter_insert.coefficients, input_left, *filter_insert.left_state_1, *filter_insert.left_state_2);
    output_right := process_biquad_filter(filter_insert.coefficients, input_right, *filter_insert.right_state_1, *filter_insert.right_state_2);

    return output_left, output_right;
}

initialize_master_limiter :: (master_limiter: *Master_Limiter, sample_rate: s64 = DEFAULT_SAMPLE_RATE) {
    master_limiter.sample_rate = sample_rate;
    master_limiter.envelope_follower = 0.0;
    configure_master_limiter(master_limiter, -0.1, 50.0);
}

configure_master_limiter :: (master_limiter: *Master_Limiter, ceiling_decibels: float = -0.1, release_milliseconds: float = 50.0) {
    master_limiter.ceiling_decibels = ceiling_decibels;
    master_limiter.ceiling_linear = decibels_to_linear(ceiling_decibels);

    release_samples := (release_milliseconds / 1000.0) * cast(float) master_limiter.sample_rate;
    if release_samples < 1.0 {
        release_samples = 1.0;
    }

    master_limiter.release_multiplier = cast(float) pow(0.001, 1.0 / cast(float64) release_samples);
}

reset_master_limiter :: (master_limiter: *Master_Limiter) {
    master_limiter.envelope_follower = 0.0;
}

process_master_limiter :: (master_limiter: *Master_Limiter, input_left: float, input_right: float) -> float, float {
    peak_level := abs(input_left);
    right_absolute := abs(input_right);
    if right_absolute > peak_level {
        peak_level = right_absolute;
    }

    if peak_level > master_limiter.envelope_follower {
        master_limiter.envelope_follower = peak_level;
    } else {
        master_limiter.envelope_follower *= master_limiter.release_multiplier;
        if master_limiter.envelope_follower < 0.00001 {
            master_limiter.envelope_follower = 0.0;
        }
    }

    gain_reduction := 1.0;
    if master_limiter.envelope_follower > master_limiter.ceiling_linear {
        gain_reduction = master_limiter.ceiling_linear / master_limiter.envelope_follower;
    }

    output_left := input_left * gain_reduction;
    output_right := input_right * gain_reduction;

    if output_left > master_limiter.ceiling_linear {
        output_left = master_limiter.ceiling_linear;
    } else if output_left < -master_limiter.ceiling_linear {
        output_left = -master_limiter.ceiling_linear;
    }

    if output_right > master_limiter.ceiling_linear {
        output_right = master_limiter.ceiling_linear;
    } else if output_right < -master_limiter.ceiling_linear {
        output_right = -master_limiter.ceiling_linear;
    }

    return output_left, output_right;
}

MAXIMUM_DELAY_FRAMES :: 96000;

Stereo_Delay :: struct {
    left_delay_buffer: [] float;
    right_delay_buffer: [] float;
    write_index: s64 = 0;
    delay_time_seconds: float = 0.25;
    feedback: float = 0.35;
    dry_level: float = 1.0;
    wet_level: float = 0.5;
    sample_rate: s64 = DEFAULT_SAMPLE_RATE;
}

Filter_Insert :: struct {
    filter_type: Filter_Type = .NONE;
    cutoff_frequency_hertz: float = 20000.0;
    resonance: float = 0.0;
    coefficients: Biquad_Coefficients;
    left_state_1: float = 0.0;
    left_state_2: float = 0.0;
    right_state_1: float = 0.0;
    right_state_2: float = 0.0;
    sample_rate: s64 = DEFAULT_SAMPLE_RATE;
}

Master_Limiter :: struct {
    ceiling_decibels: float = -0.1;
    ceiling_linear: float = 0.98855;
    release_multiplier: float = 0.999;
    envelope_follower: float = 0.0;
    sample_rate: s64 = DEFAULT_SAMPLE_RATE;
}
