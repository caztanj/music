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

initialize_studio_reverb :: (reverb: *Studio_Reverb, sample_rate: s64 = DEFAULT_SAMPLE_RATE) {
    reverb.sample_rate = sample_rate;
    reverb.predelay_write_index = 0;
    reverb.predelay_samples = cast(s64) ((10.0 / 1000.0) * cast(float) sample_rate);
    reverb.predelay_milliseconds = 10.0;
    reverb.room_size = 0.5;
    reverb.decay_time_seconds = 1.5;
    reverb.damping = 0.5;
    reverb.stereo_width = 1.0;
    reverb.wet_level = 0.35;
    reverb.dry_level = 1.0;

    if reverb.predelay_buffer_left.count == 0 {
        reverb.predelay_buffer_left = NewArray(MAXIMUM_PREDELAY_FRAMES, float);
        reverb.predelay_buffer_right = NewArray(MAXIMUM_PREDELAY_FRAMES, float);
    }

    sample_rate_scale := cast(float64) sample_rate / 44100.0;

    comb_index := 0;
    while comb_index < REVERB_COMB_COUNT {
        left_samples := cast(s64) (cast(float64) COMB_TUNING_LEFT[comb_index] * sample_rate_scale);
        right_samples := cast(s64) (cast(float64) (COMB_TUNING_LEFT[comb_index] + STEREO_SPREAD_OFFSET) * sample_rate_scale);

        left_comb := *reverb.left_comb_filters[comb_index];
        left_comb.buffer_size = left_samples;
        left_comb.write_index = 0;
        left_comb.filter_state = 0.0;
        if left_comb.buffer.count == 0 {
            left_comb.buffer = NewArray(left_samples + 16, float);
        }

        right_comb := *reverb.right_comb_filters[comb_index];
        right_comb.buffer_size = right_samples;
        right_comb.write_index = 0;
        right_comb.filter_state = 0.0;
        if right_comb.buffer.count == 0 {
            right_comb.buffer = NewArray(right_samples + 16, float);
        }

        comb_index += 1;
    }

    allpass_index := 0;
    while allpass_index < REVERB_ALLPASS_COUNT {
        left_samples := cast(s64) (cast(float64) ALLPASS_TUNING_LEFT[allpass_index] * sample_rate_scale);
        right_samples := cast(s64) (cast(float64) (ALLPASS_TUNING_LEFT[allpass_index] + STEREO_SPREAD_OFFSET) * sample_rate_scale);

        left_allpass := *reverb.left_allpass_filters[allpass_index];
        left_allpass.buffer_size = left_samples;
        left_allpass.write_index = 0;
        left_allpass.feedback = 0.5;
        if left_allpass.buffer.count == 0 {
            left_allpass.buffer = NewArray(left_samples + 16, float);
        }

        right_allpass := *reverb.right_allpass_filters[allpass_index];
        right_allpass.buffer_size = right_samples;
        right_allpass.write_index = 0;
        right_allpass.feedback = 0.5;
        if right_allpass.buffer.count == 0 {
            right_allpass.buffer = NewArray(right_samples + 16, float);
        }

        allpass_index += 1;
    }

    reset_studio_reverb(reverb);
}

deinitialize_studio_reverb :: (reverb: *Studio_Reverb) {
    if reverb.predelay_buffer_left.data != null {
        array_free(reverb.predelay_buffer_left);
        reverb.predelay_buffer_left.data = null;
        reverb.predelay_buffer_left.count = 0;
    }

    if reverb.predelay_buffer_right.data != null {
        array_free(reverb.predelay_buffer_right);
        reverb.predelay_buffer_right.data = null;
        reverb.predelay_buffer_right.count = 0;
    }

    comb_index := 0;
    while comb_index < REVERB_COMB_COUNT {
        if reverb.left_comb_filters[comb_index].buffer.data != null {
            array_free(reverb.left_comb_filters[comb_index].buffer);
            reverb.left_comb_filters[comb_index].buffer.data = null;
            reverb.left_comb_filters[comb_index].buffer.count = 0;
        }

        if reverb.right_comb_filters[comb_index].buffer.data != null {
            array_free(reverb.right_comb_filters[comb_index].buffer);
            reverb.right_comb_filters[comb_index].buffer.data = null;
            reverb.right_comb_filters[comb_index].buffer.count = 0;
        }

        comb_index += 1;
    }

    allpass_index := 0;
    while allpass_index < REVERB_ALLPASS_COUNT {
        if reverb.left_allpass_filters[allpass_index].buffer.data != null {
            array_free(reverb.left_allpass_filters[allpass_index].buffer);
            reverb.left_allpass_filters[allpass_index].buffer.data = null;
            reverb.left_allpass_filters[allpass_index].buffer.count = 0;
        }

        if reverb.right_allpass_filters[allpass_index].buffer.data != null {
            array_free(reverb.right_allpass_filters[allpass_index].buffer);
            reverb.right_allpass_filters[allpass_index].buffer.data = null;
            reverb.right_allpass_filters[allpass_index].buffer.count = 0;
        }

        allpass_index += 1;
    }
}

reset_studio_reverb :: (reverb: *Studio_Reverb) {
    reverb.predelay_write_index = 0;

    index := 0;
    while index < reverb.predelay_buffer_left.count {
        reverb.predelay_buffer_left[index] = 0.0;
        reverb.predelay_buffer_right[index] = 0.0;
        index += 1;
    }

    comb_index := 0;
    while comb_index < REVERB_COMB_COUNT {
        left_comb := *reverb.left_comb_filters[comb_index];
        left_comb.write_index = 0;
        left_comb.filter_state = 0.0;
        sample_index := 0;
        while sample_index < left_comb.buffer.count {
            left_comb.buffer[sample_index] = 0.0;
            sample_index += 1;
        }

        right_comb := *reverb.right_comb_filters[comb_index];
        right_comb.write_index = 0;
        right_comb.filter_state = 0.0;
        sample_index = 0;
        while sample_index < right_comb.buffer.count {
            right_comb.buffer[sample_index] = 0.0;
            sample_index += 1;
        }

        comb_index += 1;
    }

    allpass_index := 0;
    while allpass_index < REVERB_ALLPASS_COUNT {
        left_allpass := *reverb.left_allpass_filters[allpass_index];
        left_allpass.write_index = 0;
        sample_index := 0;
        while sample_index < left_allpass.buffer.count {
            left_allpass.buffer[sample_index] = 0.0;
            sample_index += 1;
        }

        right_allpass := *reverb.right_allpass_filters[allpass_index];
        right_allpass.write_index = 0;
        sample_index = 0;
        while sample_index < right_allpass.buffer.count {
            right_allpass.buffer[sample_index] = 0.0;
            sample_index += 1;
        }

        allpass_index += 1;
    }
}

configure_studio_reverb :: (
    reverb: *Studio_Reverb,
    room_size: float = 0.5,
    damping: float = 0.5,
    predelay_milliseconds: float = 10.0,
    wet_level: float = 0.35,
    dry_level: float = 1.0,
    stereo_width: float = 1.0
) {
    reverb.room_size = room_size;
    if reverb.room_size < 0.0 {
        reverb.room_size = 0.0;
    } else if reverb.room_size > 1.0 {
        reverb.room_size = 1.0;
    }

    reverb.damping = damping;
    if reverb.damping < 0.0 {
        reverb.damping = 0.0;
    } else if reverb.damping > 1.0 {
        reverb.damping = 1.0;
    }

    reverb.predelay_milliseconds = predelay_milliseconds;
    if reverb.predelay_milliseconds < 0.0 {
        reverb.predelay_milliseconds = 0.0;
    }

    reverb.predelay_samples = cast(s64) ((reverb.predelay_milliseconds / 1000.0) * cast(float) reverb.sample_rate);
    if reverb.predelay_samples >= MAXIMUM_PREDELAY_FRAMES {
        reverb.predelay_samples = MAXIMUM_PREDELAY_FRAMES - 1;
    }

    reverb.wet_level = wet_level;
    reverb.dry_level = dry_level;
    reverb.stereo_width = stereo_width;
}

process_comb_filter :: (comb_filter: *Comb_Filter, input_sample: float, feedback: float, damping_factor: float) -> float {
    output_sample := comb_filter.buffer[comb_filter.write_index];

    comb_filter.filter_state = output_sample * (1.0 - damping_factor) + comb_filter.filter_state * damping_factor;
    if abs(comb_filter.filter_state) < 0.000000000000001 {
        comb_filter.filter_state = 0.0;
    }

    new_sample := input_sample + comb_filter.filter_state * feedback;
    if abs(new_sample) < 0.000000000000001 {
        new_sample = 0.0;
    }

    comb_filter.buffer[comb_filter.write_index] = new_sample;
    comb_filter.write_index = (comb_filter.write_index + 1) % comb_filter.buffer_size;

    return output_sample;
}

process_allpass_filter :: (allpass_filter: *Allpass_Filter, input_sample: float) -> float {
    buffered := allpass_filter.buffer[allpass_filter.write_index];
    output_sample := -input_sample + buffered;

    new_sample := input_sample + buffered * allpass_filter.feedback;
    if abs(new_sample) < 0.000000000000001 {
        new_sample = 0.0;
    }

    allpass_filter.buffer[allpass_filter.write_index] = new_sample;
    allpass_filter.write_index = (allpass_filter.write_index + 1) % allpass_filter.buffer_size;

    if abs(output_sample) < 0.000000000000001 {
        output_sample = 0.0;
    }

    return output_sample;
}

process_studio_reverb :: (reverb: *Studio_Reverb, input_left: float, input_right: float) -> float, float {
    if reverb.wet_level <= 0.0 {
        return input_left * reverb.dry_level, input_right * reverb.dry_level;
    }

    reverb_input_left := input_left;
    reverb_input_right := input_right;

    if reverb.predelay_samples > 0 && reverb.predelay_buffer_left.count > 0 {
        read_index := reverb.predelay_write_index - reverb.predelay_samples;
        if read_index < 0 {
            read_index += reverb.predelay_buffer_left.count;
        }

        reverb_input_left = reverb.predelay_buffer_left[read_index];
        reverb_input_right = reverb.predelay_buffer_right[read_index];

        reverb.predelay_buffer_left[reverb.predelay_write_index] = input_left;
        reverb.predelay_buffer_right[reverb.predelay_write_index] = input_right;

        reverb.predelay_write_index = (reverb.predelay_write_index + 1) % reverb.predelay_buffer_left.count;
    }

    mono_input := (reverb_input_left + reverb_input_right) * 0.015;

    feedback := reverb.room_size * 0.28 + 0.7;
    if feedback > 0.98 {
        feedback = 0.98;
    } else if feedback < 0.0 {
        feedback = 0.0;
    }

    damping_factor := reverb.damping * 0.4;

    comb_sum_left: float = 0.0;
    comb_sum_right: float = 0.0;

    comb_index := 0;
    while comb_index < REVERB_COMB_COUNT {
        comb_sum_left += process_comb_filter(*reverb.left_comb_filters[comb_index], mono_input, feedback, damping_factor);
        comb_sum_right += process_comb_filter(*reverb.right_comb_filters[comb_index], mono_input, feedback, damping_factor);
        comb_index += 1;
    }

    diffuse_left := comb_sum_left;
    diffuse_right := comb_sum_right;

    allpass_index := 0;
    while allpass_index < REVERB_ALLPASS_COUNT {
        diffuse_left = process_allpass_filter(*reverb.left_allpass_filters[allpass_index], diffuse_left);
        diffuse_right = process_allpass_filter(*reverb.right_allpass_filters[allpass_index], diffuse_right);
        allpass_index += 1;
    }

    wet_left := diffuse_left * (1.0 + reverb.stereo_width) * 0.5 + diffuse_right * (1.0 - reverb.stereo_width) * 0.5;
    wet_right := diffuse_right * (1.0 + reverb.stereo_width) * 0.5 + diffuse_left * (1.0 - reverb.stereo_width) * 0.5;

    output_left := input_left * reverb.dry_level + wet_left * reverb.wet_level;
    output_right := input_right * reverb.dry_level + wet_right * reverb.wet_level;

    if output_left > 2.0 {
        output_left = 2.0;
    } else if output_left < -2.0 {
        output_left = -2.0;
    }

    if output_right > 2.0 {
        output_right = 2.0;
    } else if output_right < -2.0 {
        output_right = -2.0;
    }

    return output_left, output_right;
}

initialize_equalizer_band :: (band: *Equalizer_Band, sample_rate: s64 = DEFAULT_SAMPLE_RATE) {
    band.filter_type = .NONE;
    band.frequency_hertz = 1000.0;
    band.gain_decibels = 0.0;
    band.quality_factor = 0.707;
    band.left_state_1 = 0.0;
    band.left_state_2 = 0.0;
    band.right_state_1 = 0.0;
    band.right_state_2 = 0.0;
    band.coefficients = calculate_biquad_coefficients(.NONE, 1000.0, 0.0, sample_rate);
}

configure_equalizer_band :: (band: *Equalizer_Band, filter_type: Filter_Type, frequency_hertz: float, gain_decibels: float, quality_factor: float, sample_rate: s64) {
    band.filter_type = filter_type;
    band.frequency_hertz = frequency_hertz;
    band.gain_decibels = gain_decibels;
    band.quality_factor = quality_factor;

    band.coefficients = calculate_biquad_coefficients(
        filter_type = filter_type,
        cutoff_frequency_hertz = frequency_hertz,
        resonance = 0.0,
        sample_rate = sample_rate,
        gain_decibels = gain_decibels,
        quality_factor_override = quality_factor
    );
}

reset_equalizer_band :: (band: *Equalizer_Band) {
    band.left_state_1 = 0.0;
    band.left_state_2 = 0.0;
    band.right_state_1 = 0.0;
    band.right_state_2 = 0.0;
}

process_equalizer_band :: (band: *Equalizer_Band, input_left: float, input_right: float) -> float, float {
    if band.filter_type == .NONE || band.gain_decibels == 0.0 {
        return input_left, input_right;
    }

    output_left := process_biquad_filter(band.coefficients, input_left, *band.left_state_1, *band.left_state_2);
    output_right := process_biquad_filter(band.coefficients, input_right, *band.right_state_1, *band.right_state_2);

    return output_left, output_right;
}

initialize_parametric_equalizer :: (equalizer: *Parametric_Equalizer, sample_rate: s64 = DEFAULT_SAMPLE_RATE) {
    equalizer.sample_rate = sample_rate;
    equalizer.enabled = false;

    initialize_equalizer_band(*equalizer.low_band, sample_rate);
    initialize_equalizer_band(*equalizer.mid_band, sample_rate);
    initialize_equalizer_band(*equalizer.high_band, sample_rate);

    configure_parametric_equalizer(equalizer, 0.0, 0.0, 0.0, 120.0, 1200.0, 1.0, 8000.0);
}

configure_parametric_equalizer :: (
    equalizer: *Parametric_Equalizer,
    low_gain_decibels: float,
    mid_gain_decibels: float,
    high_gain_decibels: float,
    low_frequency_hertz: float = 120.0,
    mid_frequency_hertz: float = 1200.0,
    mid_quality_factor: float = 1.0,
    high_frequency_hertz: float = 8000.0
) {
    configure_equalizer_band(*equalizer.low_band, .LOW_SHELF, low_frequency_hertz, low_gain_decibels, 0.707, equalizer.sample_rate);
    configure_equalizer_band(*equalizer.mid_band, .PEAKING, mid_frequency_hertz, mid_gain_decibels, mid_quality_factor, equalizer.sample_rate);
    configure_equalizer_band(*equalizer.high_band, .HIGH_SHELF, high_frequency_hertz, high_gain_decibels, 0.707, equalizer.sample_rate);

    equalizer.enabled = (low_gain_decibels != 0.0) || (mid_gain_decibels != 0.0) || (high_gain_decibels != 0.0);
}

reset_parametric_equalizer :: (equalizer: *Parametric_Equalizer) {
    reset_equalizer_band(*equalizer.low_band);
    reset_equalizer_band(*equalizer.mid_band);
    reset_equalizer_band(*equalizer.high_band);
}

process_parametric_equalizer :: (equalizer: *Parametric_Equalizer, input_left: float, input_right: float) -> float, float {
    if !equalizer.enabled {
        return input_left, input_right;
    }

    current_left := input_left;
    current_right := input_right;

    current_left, current_right = process_equalizer_band(*equalizer.low_band, current_left, current_right);
    current_left, current_right = process_equalizer_band(*equalizer.mid_band, current_left, current_right);
    current_left, current_right = process_equalizer_band(*equalizer.high_band, current_left, current_right);

    return current_left, current_right;
}

initialize_chorus_flanger :: (chorus_flanger: *Chorus_Flanger, sample_rate: s64 = DEFAULT_SAMPLE_RATE) {
    chorus_flanger.sample_rate = sample_rate;
    chorus_flanger.enabled = false;
    chorus_flanger.write_index = 0;
    chorus_flanger.phase = 0.0;
    chorus_flanger.rate_hertz = 1.0;
    chorus_flanger.depth_milliseconds = 2.0;
    chorus_flanger.center_delay_milliseconds = 7.0;
    chorus_flanger.feedback = 0.0;
    chorus_flanger.mix = 0.5;
    chorus_flanger.stereo_phase_degrees = 90.0;
    chorus_flanger.buffer_size = MAXIMUM_CHORUS_DELAY_FRAMES;

    if chorus_flanger.left_delay_buffer.count == 0 {
        chorus_flanger.left_delay_buffer = NewArray(MAXIMUM_CHORUS_DELAY_FRAMES, float);
        chorus_flanger.right_delay_buffer = NewArray(MAXIMUM_CHORUS_DELAY_FRAMES, float);
    }

    reset_chorus_flanger(chorus_flanger);
}

configure_chorus_flanger :: (
    chorus_flanger: *Chorus_Flanger,
    rate_hertz: float = 1.0,
    depth_milliseconds: float = 2.0,
    center_delay_milliseconds: float = 7.0,
    feedback: float = 0.0,
    mix: float = 0.5,
    stereo_phase_degrees: float = 90.0
) {
    chorus_flanger.rate_hertz = rate_hertz;
    if chorus_flanger.rate_hertz < 0.01 {
        chorus_flanger.rate_hertz = 0.01;
    } else if chorus_flanger.rate_hertz > 20.0 {
        chorus_flanger.rate_hertz = 20.0;
    }

    chorus_flanger.depth_milliseconds = depth_milliseconds;
    if chorus_flanger.depth_milliseconds < 0.0 {
        chorus_flanger.depth_milliseconds = 0.0;
    } else if chorus_flanger.depth_milliseconds > 15.0 {
        chorus_flanger.depth_milliseconds = 15.0;
    }

    chorus_flanger.center_delay_milliseconds = center_delay_milliseconds;
    if chorus_flanger.center_delay_milliseconds < 0.5 {
        chorus_flanger.center_delay_milliseconds = 0.5;
    } else if chorus_flanger.center_delay_milliseconds > 30.0 {
        chorus_flanger.center_delay_milliseconds = 30.0;
    }

    chorus_flanger.feedback = feedback;
    if chorus_flanger.feedback < -0.95 {
        chorus_flanger.feedback = -0.95;
    } else if chorus_flanger.feedback > 0.95 {
        chorus_flanger.feedback = 0.95;
    }

    chorus_flanger.mix = mix;
    if chorus_flanger.mix < 0.0 {
        chorus_flanger.mix = 0.0;
    } else if chorus_flanger.mix > 1.0 {
        chorus_flanger.mix = 1.0;
    }

    chorus_flanger.stereo_phase_degrees = stereo_phase_degrees;
    chorus_flanger.enabled = chorus_flanger.mix > 0.0;
}

reset_chorus_flanger :: (chorus_flanger: *Chorus_Flanger) {
    chorus_flanger.write_index = 0;
    chorus_flanger.phase = 0.0;

    frame_index := 0;
    while frame_index < chorus_flanger.left_delay_buffer.count {
        chorus_flanger.left_delay_buffer[frame_index] = 0.0;
        chorus_flanger.right_delay_buffer[frame_index] = 0.0;
        frame_index += 1;
    }
}

deinitialize_chorus_flanger :: (chorus_flanger: *Chorus_Flanger) {
    if chorus_flanger.left_delay_buffer.data != null {
        array_free(chorus_flanger.left_delay_buffer);
        chorus_flanger.left_delay_buffer.data = null;
        chorus_flanger.left_delay_buffer.count = 0;
    }

    if chorus_flanger.right_delay_buffer.data != null {
        array_free(chorus_flanger.right_delay_buffer);
        chorus_flanger.right_delay_buffer.data = null;
        chorus_flanger.right_delay_buffer.count = 0;
    }
}

process_chorus_flanger :: (chorus_flanger: *Chorus_Flanger, input_left: float, input_right: float) -> float, float {
    if !chorus_flanger.enabled || chorus_flanger.left_delay_buffer.count == 0 {
        return input_left, input_right;
    }

    stereo_phase_offset_radians := cast(float64) (chorus_flanger.stereo_phase_degrees * PI / 180.0);

    left_modulation := sin(chorus_flanger.phase);
    right_modulation := sin(chorus_flanger.phase + stereo_phase_offset_radians);

    left_delay_milliseconds := chorus_flanger.center_delay_milliseconds + chorus_flanger.depth_milliseconds * cast(float) left_modulation;
    if left_delay_milliseconds < 0.1 {
        left_delay_milliseconds = 0.1;
    }

    right_delay_milliseconds := chorus_flanger.center_delay_milliseconds + chorus_flanger.depth_milliseconds * cast(float) right_modulation;
    if right_delay_milliseconds < 0.1 {
        right_delay_milliseconds = 0.1;
    }

    left_delay_samples := left_delay_milliseconds * 0.001 * cast(float) chorus_flanger.sample_rate;
    right_delay_samples := right_delay_milliseconds * 0.001 * cast(float) chorus_flanger.sample_rate;

    maximum_allowed_delay_samples := cast(float) (chorus_flanger.buffer_size - 2);
    if left_delay_samples > maximum_allowed_delay_samples {
        left_delay_samples = maximum_allowed_delay_samples;
    }
    if right_delay_samples > maximum_allowed_delay_samples {
        right_delay_samples = maximum_allowed_delay_samples;
    }

    left_read_position := cast(float64) chorus_flanger.write_index - cast(float64) left_delay_samples;
    while left_read_position < 0.0 {
        left_read_position += cast(float64) chorus_flanger.buffer_size;
    }

    left_index_previous := (cast(s64) floor(left_read_position)) % chorus_flanger.buffer_size;
    left_index_next := (left_index_previous + 1) % chorus_flanger.buffer_size;
    left_fraction := cast(float) (left_read_position - floor(left_read_position));
    delayed_left := chorus_flanger.left_delay_buffer[left_index_previous] * (1.0 - left_fraction) + chorus_flanger.left_delay_buffer[left_index_next] * left_fraction;

    right_read_position := cast(float64) chorus_flanger.write_index - cast(float64) right_delay_samples;
    while right_read_position < 0.0 {
        right_read_position += cast(float64) chorus_flanger.buffer_size;
    }

    right_index_previous := (cast(s64) floor(right_read_position)) % chorus_flanger.buffer_size;
    right_index_next := (right_index_previous + 1) % chorus_flanger.buffer_size;
    right_fraction := cast(float) (right_read_position - floor(right_read_position));
    delayed_right := chorus_flanger.right_delay_buffer[right_index_previous] * (1.0 - right_fraction) + chorus_flanger.right_delay_buffer[right_index_next] * right_fraction;

    chorus_flanger.left_delay_buffer[chorus_flanger.write_index] = input_left + delayed_left * chorus_flanger.feedback;
    chorus_flanger.right_delay_buffer[chorus_flanger.write_index] = input_right + delayed_right * chorus_flanger.feedback;

    chorus_flanger.write_index += 1;
    if chorus_flanger.write_index >= chorus_flanger.buffer_size {
        chorus_flanger.write_index = 0;
    }

    chorus_flanger.phase += 2.0 * PI * cast(float64) chorus_flanger.rate_hertz / cast(float64) chorus_flanger.sample_rate;
    if chorus_flanger.phase >= 2.0 * PI {
        chorus_flanger.phase -= 2.0 * PI;
    }

    output_left := input_left * (1.0 - chorus_flanger.mix) + delayed_left * chorus_flanger.mix;
    output_right := input_right * (1.0 - chorus_flanger.mix) + delayed_right * chorus_flanger.mix;

    return output_left, output_right;
}

initialize_saturation_insert :: (saturation: *Saturation_Insert) {
    saturation.enabled = false;
    saturation.saturation_type = .TANH;
    saturation.drive = 1.0;
    saturation.mix = 1.0;
    saturation.output_gain = 1.0;
}

configure_saturation_insert :: (
    saturation: *Saturation_Insert,
    saturation_type: Saturation_Type = .TANH,
    drive: float = 1.0,
    mix: float = 1.0,
    output_gain: float = 1.0
) {
    saturation.saturation_type = saturation_type;
    saturation.drive = drive;
    if saturation.drive < 0.1 {
        saturation.drive = 0.1;
    } else if saturation.drive > 50.0 {
        saturation.drive = 50.0;
    }

    saturation.mix = mix;
    if saturation.mix < 0.0 {
        saturation.mix = 0.0;
    } else if saturation.mix > 1.0 {
        saturation.mix = 1.0;
    }

    saturation.output_gain = output_gain;
    if saturation.output_gain < 0.0 {
        saturation.output_gain = 0.0;
    } else if saturation.output_gain > 10.0 {
        saturation.output_gain = 10.0;
    }

    saturation.enabled = (saturation_type != .NONE) && (saturation.mix > 0.0);
}

reset_saturation_insert :: (saturation: *Saturation_Insert) {
}

process_saturation_sample :: (saturation: *Saturation_Insert, input_sample: float) -> float {
    if !saturation.enabled || saturation.saturation_type == .NONE {
        return input_sample;
    }

    driven_sample := cast(float64) (input_sample * saturation.drive);
    saturated_sample: float64 = 0.0;

    if saturation.saturation_type == {
        case .TANH;
            if driven_sample > 20.0 {
                saturated_sample = 1.0;
            } else if driven_sample < -20.0 {
                saturated_sample = -1.0;
            } else {
                exponential := exp(2.0 * driven_sample);
                saturated_sample = (exponential - 1.0) / (exponential + 1.0);
            }

        case .CUBIC;
            if driven_sample > 1.5 {
                saturated_sample = 1.0;
            } else if driven_sample < -1.5 {
                saturated_sample = -1.0;
            } else {
                normalized_cubic := driven_sample / 1.5;
                saturated_sample = 1.5 * (normalized_cubic - (normalized_cubic * normalized_cubic * normalized_cubic) / 3.0);
            }

        case .HARD_CLIP;
            if driven_sample > 1.0 {
                saturated_sample = 1.0;
            } else if driven_sample < -1.0 {
                saturated_sample = -1.0;
            } else {
                saturated_sample = driven_sample;
            }

        case;
            saturated_sample = driven_sample;
    }

    processed_sample := cast(float) saturated_sample * saturation.output_gain;
    final_sample := input_sample * (1.0 - saturation.mix) + processed_sample * saturation.mix;

    return final_sample;
}

process_saturation_insert :: (saturation: *Saturation_Insert, input_left: float, input_right: float) -> float, float {
    if !saturation.enabled || saturation.saturation_type == .NONE {
        return input_left, input_right;
    }

    output_left := process_saturation_sample(saturation, input_left);
    output_right := process_saturation_sample(saturation, input_right);

    return output_left, output_right;
}

MAXIMUM_DELAY_FRAMES :: 96000;
MAXIMUM_PREDELAY_FRAMES :: 24000;
REVERB_COMB_COUNT :: 8;
REVERB_ALLPASS_COUNT :: 4;
STEREO_SPREAD_OFFSET :: 23;
COMB_TUNING_LEFT: [8] s64 : .[1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617];
ALLPASS_TUNING_LEFT: [4] s64 : .[556, 441, 341, 225];

Comb_Filter :: struct {
    buffer: [] float;
    buffer_size: s64 = 0;
    write_index: s64 = 0;
    filter_state: float = 0.0;
}

Allpass_Filter :: struct {
    buffer: [] float;
    buffer_size: s64 = 0;
    write_index: s64 = 0;
    feedback: float = 0.5;
}

Studio_Reverb :: struct {
    predelay_buffer_left: [] float;
    predelay_buffer_right: [] float;
    predelay_write_index: s64 = 0;
    predelay_samples: s64 = 0;
    predelay_milliseconds: float = 10.0;
    left_comb_filters: [REVERB_COMB_COUNT] Comb_Filter;
    right_comb_filters: [REVERB_COMB_COUNT] Comb_Filter;
    left_allpass_filters: [REVERB_ALLPASS_COUNT] Allpass_Filter;
    right_allpass_filters: [REVERB_ALLPASS_COUNT] Allpass_Filter;
    room_size: float = 0.5;
    decay_time_seconds: float = 1.5;
    damping: float = 0.5;
    stereo_width: float = 1.0;
    wet_level: float = 0.35;
    dry_level: float = 1.0;
    sample_rate: s64 = DEFAULT_SAMPLE_RATE;
}

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

Equalizer_Band :: struct {
    filter_type: Filter_Type = .NONE;
    frequency_hertz: float = 1000.0;
    gain_decibels: float = 0.0;
    quality_factor: float = 0.707;
    coefficients: Biquad_Coefficients;
    left_state_1: float = 0.0;
    left_state_2: float = 0.0;
    right_state_1: float = 0.0;
    right_state_2: float = 0.0;
}

Parametric_Equalizer :: struct {
    enabled: bool = false;
    low_band: Equalizer_Band;
    mid_band: Equalizer_Band;
    high_band: Equalizer_Band;
    sample_rate: s64 = DEFAULT_SAMPLE_RATE;
}

MAXIMUM_CHORUS_DELAY_FRAMES :: 8192;

Chorus_Flanger :: struct {
    enabled: bool = false;
    left_delay_buffer: [] float;
    right_delay_buffer: [] float;
    buffer_size: s64 = MAXIMUM_CHORUS_DELAY_FRAMES;
    write_index: s64 = 0;
    phase: float64 = 0.0;
    rate_hertz: float = 1.0;
    depth_milliseconds: float = 2.0;
    center_delay_milliseconds: float = 7.0;
    feedback: float = 0.0;
    mix: float = 0.5;
    stereo_phase_degrees: float = 90.0;
    sample_rate: s64 = DEFAULT_SAMPLE_RATE;
}

Saturation_Insert :: struct {
    enabled: bool = false;
    saturation_type: Saturation_Type = .TANH;
    drive: float = 1.0;
    mix: float = 1.0;
    output_gain: float = 1.0;
}


