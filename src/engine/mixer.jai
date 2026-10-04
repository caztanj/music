initialize_mixer :: (mixer: *Mixer, sample_rate: s64 = DEFAULT_SAMPLE_RATE) {
    mixer.sample_rate = sample_rate;
    mixer.beats_per_minute = 120.0;

    track_index := 0;
    while track_index < MAXIMUM_TRACKS {
        channel := *mixer.tracks[track_index];
        channel.track_index = track_index + 1;
        channel.name = "";
        channel.gain = 1.0;
        channel.pan = 0.0;
        channel.is_muted = false;
        channel.is_soloed = false;
        channel.output_target = "master";
        channel.sidechain_source_track_index = 0;
        channel.delay_enabled = false;
        channel.reverb_enabled = false;
        channel.equalizer_enabled = false;
        channel.compressor_enabled = false;
        channel.saturation_enabled = false;
        channel.chorus_flanger_enabled = false;
        channel.filter_enabled = false;

        send_index := 0;
        while send_index < MAXIMUM_AUX_TRACKS {
            channel.send_levels[send_index] = 0.0;
            channel.send_pre_fader[send_index] = false;
            send_index += 1;
        }

        initialize_stereo_delay(*channel.stereo_delay, sample_rate);
        initialize_studio_reverb(*channel.reverb, sample_rate);
        initialize_parametric_equalizer(*channel.equalizer, sample_rate);
        initialize_dynamic_compressor(*channel.compressor, sample_rate);
        initialize_saturation_insert(*channel.saturation);
        initialize_chorus_flanger(*channel.chorus_flanger, sample_rate);
        initialize_filter_insert(*channel.filter_insert, sample_rate);

        track_index += 1;
    }

    aux_index := 0;
    while aux_index < MAXIMUM_AUX_TRACKS {
        aux := *mixer.aux_tracks[aux_index];
        aux.aux_index = aux_index + 1;
        aux.name = "";
        aux.gain = 1.0;
        aux.pan = 0.0;
        aux.is_muted = false;
        aux.delay_enabled = false;
        aux.reverb_enabled = false;
        aux.equalizer_enabled = false;
        aux.compressor_enabled = false;
        aux.saturation_enabled = false;
        aux.chorus_flanger_enabled = false;
        aux.filter_enabled = false;

        initialize_stereo_delay(*aux.stereo_delay, sample_rate);
        initialize_studio_reverb(*aux.reverb, sample_rate);
        initialize_parametric_equalizer(*aux.equalizer, sample_rate);
        initialize_dynamic_compressor(*aux.compressor, sample_rate);
        initialize_saturation_insert(*aux.saturation);
        initialize_chorus_flanger(*aux.chorus_flanger, sample_rate);
        initialize_filter_insert(*aux.filter_insert, sample_rate);

        aux_index += 1;
    }

    mixer.master.gain = 1.0;
    mixer.master.reverb_enabled = false;
    initialize_studio_reverb(*mixer.master.reverb, sample_rate);
    mixer.master.equalizer_enabled = false;
    initialize_parametric_equalizer(*mixer.master.equalizer, sample_rate);
    mixer.master.compressor_enabled = false;
    initialize_dynamic_compressor(*mixer.master.compressor, sample_rate);
    mixer.master.saturation_enabled = false;
    initialize_saturation_insert(*mixer.master.saturation);
    mixer.master.chorus_flanger_enabled = false;
    initialize_chorus_flanger(*mixer.master.chorus_flanger, sample_rate);
    mixer.master.limiter_enabled = true;
    initialize_master_limiter(*mixer.master.limiter, sample_rate);
    initialize_loudness_meter(*mixer.loudness_meter, sample_rate);
}

deinitialize_mixer :: (mixer: *Mixer) {
    track_index := 0;
    while track_index < MAXIMUM_TRACKS {
        deinitialize_stereo_delay(*mixer.tracks[track_index].stereo_delay);
        deinitialize_studio_reverb(*mixer.tracks[track_index].reverb);
        deinitialize_chorus_flanger(*mixer.tracks[track_index].chorus_flanger);
        track_index += 1;
    }

    aux_index := 0;
    while aux_index < MAXIMUM_AUX_TRACKS {
        deinitialize_stereo_delay(*mixer.aux_tracks[aux_index].stereo_delay);
        deinitialize_studio_reverb(*mixer.aux_tracks[aux_index].reverb);
        deinitialize_chorus_flanger(*mixer.aux_tracks[aux_index].chorus_flanger);
        aux_index += 1;
    }

    deinitialize_studio_reverb(*mixer.master.reverb);
    deinitialize_chorus_flanger(*mixer.master.chorus_flanger);
    deinitialize_loudness_meter(*mixer.loudness_meter);
}

configure_mixer_from_definition :: (mixer: *Mixer, mixer_definition: Mixer_Definition, sample_rate: s64 = DEFAULT_SAMPLE_RATE, beats_per_minute: float = 120.0) {
    initialize_mixer(mixer, sample_rate);
    mixer.beats_per_minute = beats_per_minute;

    definition_index := 0;
    while definition_index < mixer_definition.tracks.count {
        track_definition := *mixer_definition.tracks[definition_index];
        channel, channel_found := find_mixer_channel(mixer, track_definition.track_index);
        if channel_found {
            channel.name = track_definition.name;
            channel.gain = track_definition.gain;
            channel.pan = track_definition.pan;
            channel.output_target = track_definition.output_target;
            channel.sidechain_source_track_index = track_definition.sidechain_source_track_index;
            if channel.sidechain_source_track_index == 0 && track_definition.sidechain_source_name.count > 0 {
                other_index := 0;
                while other_index < mixer_definition.tracks.count {
                    other := *mixer_definition.tracks[other_index];
                    if other.name == track_definition.sidechain_source_name {
                        channel.sidechain_source_track_index = other.track_index;
                        break;
                    }

                    other_index += 1;
                }
            }

            if track_definition.delay_time_seconds > 0.0 {
                channel.delay_enabled = true;
                configure_stereo_delay(*channel.stereo_delay, track_definition.delay_time_seconds, track_definition.delay_feedback, wet_level = 0.5, dry_level = 1.0);
            }

            if track_definition.reverb_enabled {
                channel.reverb_enabled = true;
                configure_studio_reverb(
                    *channel.reverb,
                    room_size = track_definition.reverb_room_size,
                    damping = track_definition.reverb_damping,
                    predelay_milliseconds = track_definition.reverb_predelay_milliseconds,
                    wet_level = track_definition.reverb_mix,
                    dry_level = 1.0,
                    stereo_width = 1.0
                );
            }

            if track_definition.equalizer_enabled {
                channel.equalizer_enabled = true;
                configure_parametric_equalizer(
                    *channel.equalizer,
                    track_definition.equalizer_low_gain_decibels,
                    track_definition.equalizer_mid_gain_decibels,
                    track_definition.equalizer_high_gain_decibels,
                    track_definition.equalizer_low_frequency_hertz,
                    track_definition.equalizer_mid_frequency_hertz,
                    track_definition.equalizer_mid_quality_factor,
                    track_definition.equalizer_high_frequency_hertz
                );
            }

            if track_definition.chorus_enabled {
                channel.chorus_flanger_enabled = true;
                configure_chorus_flanger(
                    *channel.chorus_flanger,
                    rate_hertz = track_definition.chorus_rate_hertz,
                    depth_milliseconds = track_definition.chorus_depth_milliseconds,
                    center_delay_milliseconds = track_definition.chorus_center_delay_milliseconds,
                    feedback = track_definition.chorus_feedback,
                    mix = track_definition.chorus_mix,
                    stereo_phase_degrees = track_definition.chorus_stereo_phase_degrees
                );
            }

            if track_definition.compressor_enabled || channel.sidechain_source_track_index > 0 {
                channel.compressor_enabled = true;
                configure_dynamic_compressor(
                    *channel.compressor,
                    threshold_decibels = track_definition.compressor_threshold_decibels,
                    ratio = track_definition.compressor_ratio,
                    attack_milliseconds = track_definition.compressor_attack_milliseconds,
                    release_milliseconds = track_definition.compressor_release_milliseconds,
                    knee_decibels = track_definition.compressor_knee_decibels,
                    makeup_gain_decibels = track_definition.compressor_makeup_gain_decibels,
                    mix = track_definition.compressor_mix,
                    ducking_depth_decibels = track_definition.sidechain_depth_decibels
                );
            }

            if track_definition.saturation_enabled {
                channel.saturation_enabled = true;
                configure_saturation_insert(
                    *channel.saturation,
                    saturation_type = track_definition.saturation_type,
                    drive = track_definition.saturation_drive,
                    mix = track_definition.saturation_mix,
                    output_gain = track_definition.saturation_output_gain
                );
            }

            if track_definition.filter_enabled {
                channel.filter_enabled = true;
                filter_type := track_definition.filter_type;
                if filter_type == .NONE {
                    filter_type = .LOWPASS;
                }
                configure_filter_insert(
                    *channel.filter_insert,
                    filter_type,
                    track_definition.filter_cutoff_frequency_hertz,
                    track_definition.filter_resonance
                );
            }

            send_index := 0;
            while send_index < MAXIMUM_AUX_TRACKS {
                channel.send_levels[send_index] = track_definition.send_levels[send_index];
                channel.send_pre_fader[send_index] = track_definition.send_pre_fader[send_index];
                send_index += 1;
            }
        }

        definition_index += 1;
    }

    aux_definition_index := 0;
    while aux_definition_index < mixer_definition.aux_tracks.count {
        aux_definition := *mixer_definition.aux_tracks[aux_definition_index];
        aux, aux_found := find_mixer_aux_channel(mixer, aux_definition.aux_index);
        if aux_found {
            aux.name = aux_definition.name;
            aux.gain = aux_definition.gain;
            aux.pan = aux_definition.pan;

            if aux_definition.delay_time_seconds > 0.0 {
                aux.delay_enabled = true;
                configure_stereo_delay(*aux.stereo_delay, aux_definition.delay_time_seconds, aux_definition.delay_feedback, wet_level = 1.0, dry_level = 0.0);
            }

            if aux_definition.reverb_enabled {
                aux.reverb_enabled = true;
                configure_studio_reverb(
                    *aux.reverb,
                    room_size = aux_definition.reverb_room_size,
                    damping = aux_definition.reverb_damping,
                    predelay_milliseconds = aux_definition.reverb_predelay_milliseconds,
                    wet_level = aux_definition.reverb_mix,
                    dry_level = 0.0,
                    stereo_width = 1.0
                );
            }

            if aux_definition.equalizer_enabled {
                aux.equalizer_enabled = true;
                configure_parametric_equalizer(
                    *aux.equalizer,
                    aux_definition.equalizer_low_gain_decibels,
                    aux_definition.equalizer_mid_gain_decibels,
                    aux_definition.equalizer_high_gain_decibels,
                    aux_definition.equalizer_low_frequency_hertz,
                    aux_definition.equalizer_mid_frequency_hertz,
                    aux_definition.equalizer_mid_quality_factor,
                    aux_definition.equalizer_high_frequency_hertz
                );
            }

            if aux_definition.chorus_enabled {
                aux.chorus_flanger_enabled = true;
                configure_chorus_flanger(
                    *aux.chorus_flanger,
                    rate_hertz = aux_definition.chorus_rate_hertz,
                    depth_milliseconds = aux_definition.chorus_depth_milliseconds,
                    center_delay_milliseconds = aux_definition.chorus_center_delay_milliseconds,
                    feedback = aux_definition.chorus_feedback,
                    mix = aux_definition.chorus_mix,
                    stereo_phase_degrees = aux_definition.chorus_stereo_phase_degrees
                );
            }

            if aux_definition.compressor_enabled {
                aux.compressor_enabled = true;
                configure_dynamic_compressor(
                    *aux.compressor,
                    threshold_decibels = aux_definition.compressor_threshold_decibels,
                    ratio = aux_definition.compressor_ratio,
                    attack_milliseconds = aux_definition.compressor_attack_milliseconds,
                    release_milliseconds = aux_definition.compressor_release_milliseconds,
                    knee_decibels = aux_definition.compressor_knee_decibels,
                    makeup_gain_decibels = aux_definition.compressor_makeup_gain_decibels,
                    mix = aux_definition.compressor_mix
                );
            }

            if aux_definition.saturation_enabled {
                aux.saturation_enabled = true;
                configure_saturation_insert(
                    *aux.saturation,
                    saturation_type = aux_definition.saturation_type,
                    drive = aux_definition.saturation_drive,
                    mix = aux_definition.saturation_mix,
                    output_gain = aux_definition.saturation_output_gain
                );
            }
        }

        aux_definition_index += 1;
    }

    mixer.master.gain = mixer_definition.master.gain;
    if mixer_definition.master.reverb_enabled {
        mixer.master.reverb_enabled = true;
        configure_studio_reverb(
            *mixer.master.reverb,
            room_size = mixer_definition.master.reverb_room_size,
            damping = mixer_definition.master.reverb_damping,
            predelay_milliseconds = mixer_definition.master.reverb_predelay_milliseconds,
            wet_level = mixer_definition.master.reverb_mix,
            dry_level = 1.0,
            stereo_width = 1.0
        );
    }

    if mixer_definition.master.equalizer_enabled {
        mixer.master.equalizer_enabled = true;
        configure_parametric_equalizer(
            *mixer.master.equalizer,
            mixer_definition.master.equalizer_low_gain_decibels,
            mixer_definition.master.equalizer_mid_gain_decibels,
            mixer_definition.master.equalizer_high_gain_decibels,
            mixer_definition.master.equalizer_low_frequency_hertz,
            mixer_definition.master.equalizer_mid_frequency_hertz,
            mixer_definition.master.equalizer_mid_quality_factor,
            mixer_definition.master.equalizer_high_frequency_hertz
        );
    }

    if mixer_definition.master.compressor_enabled {
        mixer.master.compressor_enabled = true;
        configure_dynamic_compressor(
            *mixer.master.compressor,
            threshold_decibels = mixer_definition.master.compressor_threshold_decibels,
            ratio = mixer_definition.master.compressor_ratio,
            attack_milliseconds = mixer_definition.master.compressor_attack_milliseconds,
            release_milliseconds = mixer_definition.master.compressor_release_milliseconds,
            knee_decibels = mixer_definition.master.compressor_knee_decibels,
            makeup_gain_decibels = mixer_definition.master.compressor_makeup_gain_decibels,
            mix = mixer_definition.master.compressor_mix
        );
    }

    if mixer_definition.master.saturation_enabled {
        mixer.master.saturation_enabled = true;
        configure_saturation_insert(
            *mixer.master.saturation,
            saturation_type = mixer_definition.master.saturation_type,
            drive = mixer_definition.master.saturation_drive,
            mix = mixer_definition.master.saturation_mix,
            output_gain = mixer_definition.master.saturation_output_gain
        );
    }

    if mixer_definition.master.chorus_enabled {
        mixer.master.chorus_flanger_enabled = true;
        configure_chorus_flanger(
            *mixer.master.chorus_flanger,
            rate_hertz = mixer_definition.master.chorus_rate_hertz,
            depth_milliseconds = mixer_definition.master.chorus_depth_milliseconds,
            center_delay_milliseconds = mixer_definition.master.chorus_center_delay_milliseconds,
            feedback = mixer_definition.master.chorus_feedback,
            mix = mixer_definition.master.chorus_mix,
            stereo_phase_degrees = mixer_definition.master.chorus_stereo_phase_degrees
        );
    }

    mixer.master.limiter_enabled = mixer_definition.master.limiter_enabled;
    configure_master_limiter(*mixer.master.limiter, mixer_definition.master.limiter_ceiling_decibels);
}

find_mixer_channel :: (mixer: *Mixer, track_index: s64) -> *Mixer_Channel, bool {
    if track_index < 1 || track_index > MAXIMUM_TRACKS {
        return null, false;
    }

    return *mixer.tracks[track_index - 1], true;
}

find_mixer_aux_channel :: (mixer: *Mixer, aux_index: s64) -> *Aux_Channel, bool {
    if aux_index < 1 || aux_index > MAXIMUM_AUX_TRACKS {
        return null, false;
    }

    return *mixer.aux_tracks[aux_index - 1], true;
}

set_channel_mute :: (mixer: *Mixer, track_index: s64, is_muted: bool) {
    channel, channel_found := find_mixer_channel(mixer, track_index);
    if channel_found {
        channel.is_muted = is_muted;
    }
}

set_channel_solo :: (mixer: *Mixer, track_index: s64, is_soloed: bool) {
    channel, channel_found := find_mixer_channel(mixer, track_index);
    if channel_found {
        channel.is_soloed = is_soloed;
    }
}

has_any_soloed_channel :: (mixer: *Mixer) -> bool {
    track_index := 0;
    while track_index < MAXIMUM_TRACKS {
        if mixer.tracks[track_index].is_soloed {
            return true;
        }

        track_index += 1;
    }

    return false;
}

clear_channel_buffers :: (mixer: *Mixer, frame_count: s64) {
    clamped_frame_count := frame_count;
    if clamped_frame_count > MAXIMUM_BLOCK_SIZE {
        clamped_frame_count = MAXIMUM_BLOCK_SIZE;
    }

    track_index := 0;
    while track_index < MAXIMUM_TRACKS {
        channel := *mixer.tracks[track_index];
        frame_index := 0;
        while frame_index < clamped_frame_count {
            channel.left_buffer[frame_index] = 0.0;
            channel.right_buffer[frame_index] = 0.0;
            frame_index += 1;
        }

        track_index += 1;
    }

    aux_index := 0;
    while aux_index < MAXIMUM_AUX_TRACKS {
        aux := *mixer.aux_tracks[aux_index];
        frame_index := 0;
        while frame_index < clamped_frame_count {
            aux.left_buffer[frame_index] = 0.0;
            aux.right_buffer[frame_index] = 0.0;
            frame_index += 1;
        }

        aux_index += 1;
    }

    frame_index := 0;
    while frame_index < clamped_frame_count {
        mixer.master.left_buffer[frame_index] = 0.0;
        mixer.master.right_buffer[frame_index] = 0.0;
        frame_index += 1;
    }
}

mix_channels_to_master :: (mixer: *Mixer, frame_count: s64) {
    clamped_frame_count := frame_count;
    if clamped_frame_count > MAXIMUM_BLOCK_SIZE {
        clamped_frame_count = MAXIMUM_BLOCK_SIZE;
    }

    any_soloed := has_any_soloed_channel(mixer);

    track_index := 0;
    while track_index < MAXIMUM_TRACKS {
        channel := *mixer.tracks[track_index];

        should_play := ifx any_soloed then channel.is_soloed else !channel.is_muted;
        if should_play {
            normalized_pan := (channel.pan + 1.0) * 0.5;
            if normalized_pan < 0.0 {
                normalized_pan = 0.0;
            } else if normalized_pan > 1.0 {
                normalized_pan = 1.0;
            }

            pan_angle := cast(float64) normalized_pan * (PI * 0.5);
            pan_gain_left := cast(float) cos(pan_angle) * channel.gain;
            pan_gain_right := cast(float) sin(pan_angle) * channel.gain;

            has_sidechain := channel.sidechain_source_track_index > 0 &&
                             channel.sidechain_source_track_index <= MAXIMUM_TRACKS &&
                             channel.sidechain_source_track_index != (track_index + 1);

            source_channel: *Mixer_Channel = null;
            if has_sidechain {
                source_channel = *mixer.tracks[channel.sidechain_source_track_index - 1];
            }

            frame_index := 0;
            while frame_index < clamped_frame_count {
                left_sample := channel.left_buffer[frame_index];
                right_sample := channel.right_buffer[frame_index];

                if channel.equalizer_enabled {
                    left_sample, right_sample = process_parametric_equalizer(*channel.equalizer, left_sample, right_sample);
                }

                if channel.compressor_enabled {
                    sidechain_left: float = 0.0;
                    sidechain_right: float = 0.0;
                    if has_sidechain && source_channel != null {
                        sidechain_left = source_channel.left_buffer[frame_index];
                        sidechain_right = source_channel.right_buffer[frame_index];
                    }

                    left_sample, right_sample = process_dynamic_compressor(
                        *channel.compressor,
                        left_sample,
                        right_sample,
                        sidechain_left = sidechain_left,
                        sidechain_right = sidechain_right,
                        use_sidechain = has_sidechain
                    );
                }

                if channel.saturation_enabled {
                    left_sample, right_sample = process_saturation_insert(*channel.saturation, left_sample, right_sample);
                }

                if channel.filter_enabled {
                    left_sample, right_sample = process_filter_insert(*channel.filter_insert, left_sample, right_sample);
                }

                if channel.chorus_flanger_enabled {
                    left_sample, right_sample = process_chorus_flanger(*channel.chorus_flanger, left_sample, right_sample);
                }

                if channel.delay_enabled {
                    left_sample, right_sample = process_stereo_delay(*channel.stereo_delay, left_sample, right_sample);
                }

                if channel.reverb_enabled {
                    left_sample, right_sample = process_studio_reverb(*channel.reverb, left_sample, right_sample);
                }

                mixer.master.left_buffer[frame_index] += left_sample * pan_gain_left;
                mixer.master.right_buffer[frame_index] += right_sample * pan_gain_right;

                send_index := 0;
                while send_index < MAXIMUM_AUX_TRACKS {
                    send_level := channel.send_levels[send_index];
                    if send_level > 0.0 {
                        send_gain := send_level;
                        if !channel.send_pre_fader[send_index] {
                            send_gain *= channel.gain;
                        }

                        mixer.aux_tracks[send_index].left_buffer[frame_index] += left_sample * send_gain;
                        mixer.aux_tracks[send_index].right_buffer[frame_index] += right_sample * send_gain;
                    }

                    send_index += 1;
                }

                frame_index += 1;
            }
        }

        track_index += 1;
    }

    aux_index := 0;
    while aux_index < MAXIMUM_AUX_TRACKS {
        aux := *mixer.aux_tracks[aux_index];
        if !aux.is_muted {
            normalized_pan := (aux.pan + 1.0) * 0.5;
            if normalized_pan < 0.0 {
                normalized_pan = 0.0;
            } else if normalized_pan > 1.0 {
                normalized_pan = 1.0;
            }

            pan_angle := cast(float64) normalized_pan * (PI * 0.5);
            pan_gain_left := cast(float) cos(pan_angle) * aux.gain;
            pan_gain_right := cast(float) sin(pan_angle) * aux.gain;

            frame_index := 0;
            while frame_index < clamped_frame_count {
                left_sample := aux.left_buffer[frame_index];
                right_sample := aux.right_buffer[frame_index];

                if aux.equalizer_enabled {
                    left_sample, right_sample = process_parametric_equalizer(*aux.equalizer, left_sample, right_sample);
                }

                if aux.compressor_enabled {
                    left_sample, right_sample = process_dynamic_compressor(*aux.compressor, left_sample, right_sample);
                }

                if aux.saturation_enabled {
                    left_sample, right_sample = process_saturation_insert(*aux.saturation, left_sample, right_sample);
                }

                if aux.filter_enabled {
                    left_sample, right_sample = process_filter_insert(*aux.filter_insert, left_sample, right_sample);
                }

                if aux.chorus_flanger_enabled {
                    left_sample, right_sample = process_chorus_flanger(*aux.chorus_flanger, left_sample, right_sample);
                }

                if aux.delay_enabled {
                    left_sample, right_sample = process_stereo_delay(*aux.stereo_delay, left_sample, right_sample);
                }

                if aux.reverb_enabled {
                    left_sample, right_sample = process_studio_reverb(*aux.reverb, left_sample, right_sample);
                }

                mixer.master.left_buffer[frame_index] += left_sample * pan_gain_left;
                mixer.master.right_buffer[frame_index] += right_sample * pan_gain_right;

                frame_index += 1;
            }
        }

        aux_index += 1;
    }

    frame_index := 0;
    while frame_index < clamped_frame_count {
        master_left := mixer.master.left_buffer[frame_index] * mixer.master.gain;
        master_right := mixer.master.right_buffer[frame_index] * mixer.master.gain;

        if mixer.master.equalizer_enabled {
            master_left, master_right = process_parametric_equalizer(*mixer.master.equalizer, master_left, master_right);
        }

        if mixer.master.compressor_enabled {
            master_left, master_right = process_dynamic_compressor(*mixer.master.compressor, master_left, master_right);
        }

        if mixer.master.saturation_enabled {
            master_left, master_right = process_saturation_insert(*mixer.master.saturation, master_left, master_right);
        }

        if mixer.master.chorus_flanger_enabled {
            master_left, master_right = process_chorus_flanger(*mixer.master.chorus_flanger, master_left, master_right);
        }

        if mixer.master.reverb_enabled {
            master_left, master_right = process_studio_reverb(*mixer.master.reverb, master_left, master_right);
        }

        if mixer.master.limiter_enabled {
            master_left, master_right = process_master_limiter(*mixer.master.limiter, master_left, master_right);
        }

        mixer.master.left_buffer[frame_index] = master_left;
        mixer.master.right_buffer[frame_index] = master_right;

        frame_index += 1;
    }

    process_loudness_meter_block(*mixer.loudness_meter, mixer.master.left_buffer, mixer.master.right_buffer, clamped_frame_count);
}

render_mixer_master_block_interleaved :: (mixer: *Mixer, output_buffer: [] float, frame_count: s64) {
    clamped_frame_count := frame_count;
    maximum_output_frames := output_buffer.count / 2;
    if clamped_frame_count > maximum_output_frames {
        clamped_frame_count = maximum_output_frames;
    }

    frame_index := 0;
    while frame_index < clamped_frame_count {
        output_buffer[frame_index * 2] = mixer.master.left_buffer[frame_index];
        output_buffer[frame_index * 2 + 1] = mixer.master.right_buffer[frame_index];
        frame_index += 1;
    }
}

initialize_biquad_coefficients_k_weighting :: (sample_rate: s64, stage_1: *Biquad_Filter_Coefficients, stage_2: *Biquad_Filter_Coefficients) {
    if sample_rate == 48000 {
        stage_1.b0 = 1.53512485958697;
        stage_1.b1 = -2.69169618940638;
        stage_1.b2 = 1.19839281085285;
        stage_1.a1 = -1.69065929318241;
        stage_1.a2 = 0.73248077421585;

        stage_2.b0 = 1.0;
        stage_2.b1 = -2.0;
        stage_2.b2 = 1.0;
        stage_2.a1 = -1.99004745483398;
        stage_2.a2 = 0.99007225036621;
    } else if sample_rate == 44100 {
        stage_1.b0 = 1.53090250011199;
        stage_1.b1 = -2.65096954203799;
        stage_1.b2 = 1.16906704192600;
        stage_1.a1 = -1.66367311145151;
        stage_1.a2 = 0.71267311145151;

        stage_2.b0 = 1.0;
        stage_2.b1 = -2.0;
        stage_2.b2 = 1.0;
        stage_2.a1 = -1.98916967912440;
        stage_2.a2 = 0.98919934379301;
    } else {
        rate := cast(float64) sample_rate;

        pre_frequency := 1681.974450955533;
        pre_tangent := tan(PI * pre_frequency / rate);
        pre_gain := 1.58489319246111;
        pre_denominator := 1.0 + sqrt(2.0) * pre_tangent + pre_tangent * pre_tangent;

        stage_1.b0 = (pre_gain + sqrt(2.0 * pre_gain) * pre_tangent + pre_tangent * pre_tangent) / pre_denominator;
        stage_1.b1 = 2.0 * (pre_tangent * pre_tangent - pre_gain) / pre_denominator;
        stage_1.b2 = (pre_gain - sqrt(2.0 * pre_gain) * pre_tangent + pre_tangent * pre_tangent) / pre_denominator;
        stage_1.a1 = 2.0 * (pre_tangent * pre_tangent - 1.0) / pre_denominator;
        stage_1.a2 = (1.0 - sqrt(2.0) * pre_tangent + pre_tangent * pre_tangent) / pre_denominator;

        highpass_frequency := 38.13547087602444;
        highpass_tangent := tan(PI * highpass_frequency / rate);
        highpass_quality := 0.5003270373253953;
        highpass_denominator := 1.0 + highpass_tangent / highpass_quality + highpass_tangent * highpass_tangent;

        stage_2.b0 = 1.0 / highpass_denominator;
        stage_2.b1 = -2.0 / highpass_denominator;
        stage_2.b2 = 1.0 / highpass_denominator;
        stage_2.a1 = 2.0 * (highpass_tangent * highpass_tangent - 1.0) / highpass_denominator;
        stage_2.a2 = (1.0 - highpass_tangent / highpass_quality + highpass_tangent * highpass_tangent) / highpass_denominator;
    }
}

process_biquad_filter :: (state: *Biquad_Filter_State, coefficients: Biquad_Filter_Coefficients, input_sample: float64) -> float64 {
    output_sample := coefficients.b0 * input_sample + coefficients.b1 * state.x1 + coefficients.b2 * state.x2 - coefficients.a1 * state.y1 - coefficients.a2 * state.y2;
    state.x2 = state.x1;
    state.x1 = input_sample;
    state.y2 = state.y1;
    state.y1 = output_sample;

    return output_sample;
}

initialize_true_peak_detector :: (detector: *True_Peak_Detector) {
    center := (cast(float) (TRUE_PEAK_FILTER_TAPS_PER_PHASE - 1)) * 0.5;

    phase := 0;
    while phase < TRUE_PEAK_OVERSAMPLING_FACTOR {
        fraction := (cast(float) phase) / cast(float) TRUE_PEAK_OVERSAMPLING_FACTOR;
        phase_sum: float = 0.0;
        tap := 0;
        while tap < TRUE_PEAK_FILTER_TAPS_PER_PHASE {
            time_offset := (cast(float) tap) - center - fraction;
            sinc_argument := cast(float64) (PI * time_offset);
            sinc_value: float = 1.0;
            if abs(sinc_argument) > 0.000001 {
                sinc_value = cast(float) (sin(sinc_argument) / sinc_argument);
            }

            angle := (2.0 * PI * cast(float64) tap) / cast(float64) (TRUE_PEAK_FILTER_TAPS_PER_PHASE - 1);
            window_value := cast(float) (0.42 - 0.5 * cos(angle) + 0.08 * cos(2.0 * angle));
            coefficient := sinc_value * window_value;
            detector.polyphase_coefficients[phase][tap] = coefficient;
            phase_sum += coefficient;

            tap += 1;
        }

        tap = 0;
        while tap < TRUE_PEAK_FILTER_TAPS_PER_PHASE {
            detector.polyphase_coefficients[phase][tap] /= phase_sum;
            tap += 1;
        }

        phase += 1;
    }

    reset_true_peak_detector(detector);
}

reset_true_peak_detector :: (detector: *True_Peak_Detector) {
    tap := 0;
    while tap < TRUE_PEAK_FILTER_TAPS_PER_PHASE {
        detector.left_history[tap] = 0.0;
        detector.right_history[tap] = 0.0;
        tap += 1;
    }

    detector.current_true_peak_linear = 0.0;
    detector.maximum_true_peak_linear = 0.0;
}

initialize_loudness_meter :: (meter: *Loudness_Meter, sample_rate: s64 = DEFAULT_SAMPLE_RATE) {
    meter.sample_rate = sample_rate;

    initialize_biquad_coefficients_k_weighting(sample_rate, *meter.k_weighting_filter.stage_1_coefficients, *meter.k_weighting_filter.stage_2_coefficients);
    initialize_true_peak_detector(*meter.true_peak_detector);

    samples_in_momentary_window := cast(s64) (cast(float64) sample_rate * 0.4);
    if samples_in_momentary_window < 1 {
        samples_in_momentary_window = 1;
    }

    if meter.momentary_power_buffer.count != samples_in_momentary_window {
        if meter.momentary_power_buffer.data != null {
            free(meter.momentary_power_buffer.data);
        }
        meter.momentary_power_buffer = NewArray(samples_in_momentary_window, float);
    }

    reset_loudness_meter(meter);
}

deinitialize_loudness_meter :: (meter: *Loudness_Meter) {
    if meter.momentary_power_buffer.data != null {
        free(meter.momentary_power_buffer.data);
        meter.momentary_power_buffer.data = null;
        meter.momentary_power_buffer.count = 0;
    }

    array_reset(*meter.integrated_blocks);
}

reset_loudness_meter :: (meter: *Loudness_Meter) {
    meter.k_weighting_filter.left_stage_1_state = .{};
    meter.k_weighting_filter.left_stage_2_state = .{};
    meter.k_weighting_filter.right_stage_1_state = .{};
    meter.k_weighting_filter.right_stage_2_state = .{};

    reset_true_peak_detector(*meter.true_peak_detector);

    index := 0;
    while index < meter.momentary_power_buffer.count {
        meter.momentary_power_buffer[index] = 0.0;
        index += 1;
    }

    meter.momentary_buffer_index = 0;
    meter.momentary_buffer_count = 0;
    meter.momentary_power_sum = 0.0;

    index = 0;
    while index < SHORT_TERM_SUB_BLOCK_COUNT {
        meter.short_term_sub_blocks[index] = 0.0;
        index += 1;
    }

    meter.short_term_sub_block_index = 0;
    meter.short_term_sub_block_count = 0;
    meter.current_sub_block_samples = 0;
    meter.current_sub_block_power_sum = 0.0;

    meter.integrated_blocks.count = 0;
}

process_loudness_meter_block :: (meter: *Loudness_Meter, left_buffer: [] float, right_buffer: [] float, frame_count: s64) {
    if meter.momentary_power_buffer.count == 0 {
        initialize_loudness_meter(meter, meter.sample_rate);
    }

    clamped_frames := frame_count;
    if clamped_frames > left_buffer.count {
        clamped_frames = left_buffer.count;
    }
    if clamped_frames > right_buffer.count {
        clamped_frames = right_buffer.count;
    }

    meter.true_peak_detector.current_true_peak_linear = 0.0;

    sub_block_target_samples := cast(s64) (cast(float64) meter.sample_rate * 0.1);
    if sub_block_target_samples < 1 {
        sub_block_target_samples = 1;
    }

    momentary_capacity := meter.momentary_power_buffer.count;

    frame_index := 0;
    while frame_index < clamped_frames {
        left_input := left_buffer[frame_index];
        right_input := right_buffer[frame_index];

        tap := TRUE_PEAK_FILTER_TAPS_PER_PHASE - 1;
        while tap > 0 {
            meter.true_peak_detector.left_history[tap] = meter.true_peak_detector.left_history[tap - 1];
            meter.true_peak_detector.right_history[tap] = meter.true_peak_detector.right_history[tap - 1];
            tap -= 1;
        }
        meter.true_peak_detector.left_history[0] = left_input;
        meter.true_peak_detector.right_history[0] = right_input;

        phase_index := 0;
        while phase_index < TRUE_PEAK_OVERSAMPLING_FACTOR {
            interpolated_left: float = 0.0;
            interpolated_right: float = 0.0;
            filter_tap := 0;
            while filter_tap < TRUE_PEAK_FILTER_TAPS_PER_PHASE {
                coefficient := meter.true_peak_detector.polyphase_coefficients[phase_index][filter_tap];
                interpolated_left += coefficient * meter.true_peak_detector.left_history[filter_tap];
                interpolated_right += coefficient * meter.true_peak_detector.right_history[filter_tap];
                filter_tap += 1;
            }

            magnitude_left := abs(interpolated_left);
            magnitude_right := abs(interpolated_right);

            if magnitude_left > meter.true_peak_detector.current_true_peak_linear {
                meter.true_peak_detector.current_true_peak_linear = magnitude_left;
            }
            if magnitude_right > meter.true_peak_detector.current_true_peak_linear {
                meter.true_peak_detector.current_true_peak_linear = magnitude_right;
            }
            if magnitude_left > meter.true_peak_detector.maximum_true_peak_linear {
                meter.true_peak_detector.maximum_true_peak_linear = magnitude_left;
            }
            if magnitude_right > meter.true_peak_detector.maximum_true_peak_linear {
                meter.true_peak_detector.maximum_true_peak_linear = magnitude_right;
            }

            phase_index += 1;
        }

        left_filtered := process_biquad_filter(*meter.k_weighting_filter.left_stage_1_state, meter.k_weighting_filter.stage_1_coefficients, cast(float64) left_input);
        left_filtered = process_biquad_filter(*meter.k_weighting_filter.left_stage_2_state, meter.k_weighting_filter.stage_2_coefficients, left_filtered);

        right_filtered := process_biquad_filter(*meter.k_weighting_filter.right_stage_1_state, meter.k_weighting_filter.stage_1_coefficients, cast(float64) right_input);
        right_filtered = process_biquad_filter(*meter.k_weighting_filter.right_stage_2_state, meter.k_weighting_filter.stage_2_coefficients, right_filtered);

        sample_power := left_filtered * left_filtered + right_filtered * right_filtered;

        if momentary_capacity > 0 {
            if meter.momentary_buffer_count < momentary_capacity {
                meter.momentary_power_buffer[meter.momentary_buffer_index] = cast(float) sample_power;
                meter.momentary_power_sum += sample_power;
                meter.momentary_buffer_count += 1;
                meter.momentary_buffer_index = (meter.momentary_buffer_index + 1) % momentary_capacity;
            } else {
                old_sample_power := cast(float64) meter.momentary_power_buffer[meter.momentary_buffer_index];
                meter.momentary_power_buffer[meter.momentary_buffer_index] = cast(float) sample_power;
                meter.momentary_power_sum += sample_power - old_sample_power;
                if meter.momentary_power_sum < 0.0 {
                    meter.momentary_power_sum = 0.0;
                }
                meter.momentary_buffer_index = (meter.momentary_buffer_index + 1) % momentary_capacity;
            }
        }

        meter.current_sub_block_power_sum += sample_power;
        meter.current_sub_block_samples += 1;

        if meter.current_sub_block_samples >= sub_block_target_samples {
            sub_block_mean := meter.current_sub_block_power_sum / cast(float64) meter.current_sub_block_samples;
            meter.short_term_sub_blocks[meter.short_term_sub_block_index] = sub_block_mean;
            meter.short_term_sub_block_index = (meter.short_term_sub_block_index + 1) % SHORT_TERM_SUB_BLOCK_COUNT;
            if meter.short_term_sub_block_count < SHORT_TERM_SUB_BLOCK_COUNT {
                meter.short_term_sub_block_count += 1;
            }

            if meter.short_term_sub_block_count >= 4 {
                block_power_sum: float64 = 0.0;
                offset_step := 1;
                while offset_step <= 4 {
                    lookup_index := (meter.short_term_sub_block_index - offset_step + SHORT_TERM_SUB_BLOCK_COUNT) % SHORT_TERM_SUB_BLOCK_COUNT;
                    block_power_sum += meter.short_term_sub_blocks[lookup_index];
                    offset_step += 1;
                }

                block_power_mean := block_power_sum * 0.25;
                array_add(*meter.integrated_blocks, block_power_mean);
            }

            meter.current_sub_block_samples = 0;
            meter.current_sub_block_power_sum = 0.0;
        }

        frame_index += 1;
    }
}

process_loudness_meter_interleaved :: (meter: *Loudness_Meter, interleaved_buffer: [] float, frame_count: s64) {
    temporary_left := NewArray(frame_count, float);
    defer free(temporary_left.data);

    temporary_right := NewArray(frame_count, float);
    defer free(temporary_right.data);

    frame_index := 0;
    while frame_index < frame_count {
        temporary_left[frame_index] = interleaved_buffer[frame_index * 2];
        temporary_right[frame_index] = interleaved_buffer[frame_index * 2 + 1];
        frame_index += 1;
    }

    process_loudness_meter_block(meter, temporary_left, temporary_right, frame_count);
}

get_momentary_loudness_lufs :: (meter: *Loudness_Meter) -> float {
    if meter.momentary_buffer_count == 0 {
        return -70.0;
    }

    mean_power := meter.momentary_power_sum / cast(float64) meter.momentary_buffer_count;
    if mean_power <= 0.0000000001 {
        return -70.0;
    }

    lufs := -0.691 + 4.342944819032518 * log(mean_power);
    if lufs < -70.0 {
        return -70.0;
    }

    return cast(float) lufs;
}

get_short_term_loudness_lufs :: (meter: *Loudness_Meter) -> float {
    if meter.short_term_sub_block_count == 0 {
        return get_momentary_loudness_lufs(meter);
    }

    power_sum: float64 = 0.0;
    index := 0;
    while index < meter.short_term_sub_block_count {
        power_sum += meter.short_term_sub_blocks[index];
        index += 1;
    }

    mean_power := power_sum / cast(float64) meter.short_term_sub_block_count;
    if mean_power <= 0.0000000001 {
        return -70.0;
    }

    lufs := -0.691 + 4.342944819032518 * log(mean_power);
    if lufs < -70.0 {
        return -70.0;
    }

    return cast(float) lufs;
}

get_integrated_loudness_lufs :: (meter: *Loudness_Meter) -> float {
    if meter.integrated_blocks.count == 0 {
        return get_momentary_loudness_lufs(meter);
    }

    absolute_sum: float64 = 0.0;
    absolute_count: s64 = 0;
    block_index := 0;
    while block_index < meter.integrated_blocks.count {
        block_power := meter.integrated_blocks[block_index];
        if block_power > 0.0000000001 {
            block_lufs := -0.691 + 4.342944819032518 * log(block_power);
            if block_lufs >= -70.0 {
                absolute_sum += block_power;
                absolute_count += 1;
            }
        }
        block_index += 1;
    }

    if absolute_count == 0 {
        return -70.0;
    }

    absolute_mean_power := absolute_sum / cast(float64) absolute_count;
    gamma_absolute := -0.691 + 4.342944819032518 * log(absolute_mean_power);
    relative_threshold := gamma_absolute - 10.0;

    relative_sum: float64 = 0.0;
    relative_count: s64 = 0;
    block_index = 0;
    while block_index < meter.integrated_blocks.count {
        block_power := meter.integrated_blocks[block_index];
        if block_power > 0.0000000001 {
            block_lufs := -0.691 + 4.342944819032518 * log(block_power);
            if block_lufs >= relative_threshold && block_lufs >= -70.0 {
                relative_sum += block_power;
                relative_count += 1;
            }
        }
        block_index += 1;
    }

    if relative_count == 0 {
        return -70.0;
    }

    relative_mean_power := relative_sum / cast(float64) relative_count;
    gated_lufs := -0.691 + 4.342944819032518 * log(relative_mean_power);

    return cast(float) gated_lufs;
}

get_true_peak_linear :: (meter: *Loudness_Meter) -> float {
    return meter.true_peak_detector.current_true_peak_linear;
}

get_true_peak_decibels :: (meter: *Loudness_Meter) -> float {
    linear_peak := meter.true_peak_detector.current_true_peak_linear;
    if linear_peak <= 0.00001 {
        return -100.0;
    }

    decibels := cast(float) (8.685889638 * cast(float64) log(linear_peak));

    return decibels;
}

get_maximum_true_peak_decibels :: (meter: *Loudness_Meter) -> float {
    linear_peak := meter.true_peak_detector.maximum_true_peak_linear;
    if linear_peak <= 0.00001 {
        return -100.0;
    }

    decibels := cast(float) (8.685889638 * cast(float64) log(linear_peak));

    return decibels;
}

analyze_audio_loudness :: (interleaved_samples: [] float, sample_rate: s64 = DEFAULT_SAMPLE_RATE) -> (integrated_lufs: float, short_term_lufs: float, momentary_lufs: float, true_peak_decibels: float) {
    meter: Loudness_Meter;
    initialize_loudness_meter(*meter, sample_rate);
    defer deinitialize_loudness_meter(*meter);

    frame_count := interleaved_samples.count / 2;
    block_size: s64 = 512;
    rendered_frames: s64 = 0;

    temporary_left := NewArray(block_size, float);
    defer free(temporary_left.data);

    temporary_right := NewArray(block_size, float);
    defer free(temporary_right.data);

    while rendered_frames < frame_count {
        frames_this_step := frame_count - rendered_frames;
        if frames_this_step > block_size {
            frames_this_step = block_size;
        }

        step_index := 0;
        while step_index < frames_this_step {
            source_index := (rendered_frames + step_index) * 2;
            temporary_left[step_index] = interleaved_samples[source_index];
            temporary_right[step_index] = interleaved_samples[source_index + 1];
            step_index += 1;
        }

        process_loudness_meter_block(*meter, temporary_left, temporary_right, frames_this_step);
        rendered_frames += frames_this_step;
    }

    integrated := get_integrated_loudness_lufs(*meter);
    short_term := get_short_term_loudness_lufs(*meter);
    momentary := get_momentary_loudness_lufs(*meter);
    peak := get_maximum_true_peak_decibels(*meter);

    return integrated, short_term, momentary, peak;
}

format_loudness_meter_status :: (meter: *Loudness_Meter) -> string {
    integrated_lufs := get_integrated_loudness_lufs(meter);
    true_peak_decibels := get_maximum_true_peak_decibels(meter);

    result := sprint("Loudness: % LUFS | True Peak: % dBFS", formatFloat(integrated_lufs, trailing_width = 1, zero_removal = .NO), formatFloat(true_peak_decibels, trailing_width = 1, zero_removal = .NO));

    return result;
}

TRUE_PEAK_OVERSAMPLING_FACTOR :: 4;
TRUE_PEAK_FILTER_TAPS_PER_PHASE :: 12;
SHORT_TERM_SUB_BLOCK_COUNT :: 30;

Biquad_Filter_Coefficients :: struct {
    b0: float64 = 1.0;
    b1: float64 = 0.0;
    b2: float64 = 0.0;
    a1: float64 = 0.0;
    a2: float64 = 0.0;
}

Biquad_Filter_State :: struct {
    x1: float64 = 0.0;
    x2: float64 = 0.0;
    y1: float64 = 0.0;
    y2: float64 = 0.0;
}

K_Weighting_Filter :: struct {
    stage_1_coefficients: Biquad_Filter_Coefficients;
    stage_2_coefficients: Biquad_Filter_Coefficients;
    left_stage_1_state: Biquad_Filter_State;
    left_stage_2_state: Biquad_Filter_State;
    right_stage_1_state: Biquad_Filter_State;
    right_stage_2_state: Biquad_Filter_State;
}

True_Peak_Detector :: struct {
    polyphase_coefficients: [4][12] float;
    left_history: [12] float;
    right_history: [12] float;
    current_true_peak_linear: float = 0.0;
    maximum_true_peak_linear: float = 0.0;
}

Loudness_Meter :: struct {
    sample_rate: s64 = DEFAULT_SAMPLE_RATE;
    k_weighting_filter: K_Weighting_Filter;
    true_peak_detector: True_Peak_Detector;
    momentary_power_buffer: [] float;
    momentary_buffer_index: s64 = 0;
    momentary_buffer_count: s64 = 0;
    momentary_power_sum: float64 = 0.0;
    short_term_sub_blocks: [30] float64;
    short_term_sub_block_index: s64 = 0;
    short_term_sub_block_count: s64 = 0;
    current_sub_block_samples: s64 = 0;
    current_sub_block_power_sum: float64 = 0.0;
    integrated_blocks: [..] float64;
}

Aux_Channel :: struct {
    aux_index: s64 = 1;
    name: string;
    gain: float = 1.0;
    pan: float = 0.0;
    is_muted: bool = false;
    equalizer: Parametric_Equalizer;
    equalizer_enabled: bool = false;
    compressor: Dynamic_Compressor;
    compressor_enabled: bool = false;
    saturation: Saturation_Insert;
    saturation_enabled: bool = false;
    chorus_flanger: Chorus_Flanger;
    chorus_flanger_enabled: bool = false;
    stereo_delay: Stereo_Delay;
    delay_enabled: bool = false;
    reverb: Studio_Reverb;
    reverb_enabled: bool = false;
    filter_insert: Filter_Insert;
    filter_enabled: bool = false;
    left_buffer: [MAXIMUM_BLOCK_SIZE] float;
    right_buffer: [MAXIMUM_BLOCK_SIZE] float;
}

Mixer_Channel :: struct {
    track_index: s64 = 1;
    name: string;
    gain: float = 1.0;
    pan: float = 0.0;
    is_muted: bool = false;
    is_soloed: bool = false;
    output_target: string = "master";
    sidechain_source_track_index: s64 = 0;
    send_levels: [MAXIMUM_AUX_TRACKS] float;
    send_pre_fader: [MAXIMUM_AUX_TRACKS] bool;
    equalizer: Parametric_Equalizer;
    equalizer_enabled: bool = false;
    compressor: Dynamic_Compressor;
    compressor_enabled: bool = false;
    saturation: Saturation_Insert;
    saturation_enabled: bool = false;
    chorus_flanger: Chorus_Flanger;
    chorus_flanger_enabled: bool = false;
    stereo_delay: Stereo_Delay;
    delay_enabled: bool = false;
    reverb: Studio_Reverb;
    reverb_enabled: bool = false;
    filter_insert: Filter_Insert;
    filter_enabled: bool = false;
    left_buffer: [MAXIMUM_BLOCK_SIZE] float;
    right_buffer: [MAXIMUM_BLOCK_SIZE] float;
}

Master_Channel :: struct {
    gain: float = 1.0;
    equalizer: Parametric_Equalizer;
    equalizer_enabled: bool = false;
    compressor: Dynamic_Compressor;
    compressor_enabled: bool = false;
    saturation: Saturation_Insert;
    saturation_enabled: bool = false;
    chorus_flanger: Chorus_Flanger;
    chorus_flanger_enabled: bool = false;
    reverb: Studio_Reverb;
    reverb_enabled: bool = false;
    limiter: Master_Limiter;
    limiter_enabled: bool = true;
    left_buffer: [MAXIMUM_BLOCK_SIZE] float;
    right_buffer: [MAXIMUM_BLOCK_SIZE] float;
}

Mixer :: struct {
    tracks: [MAXIMUM_TRACKS] Mixer_Channel;
    aux_tracks: [MAXIMUM_AUX_TRACKS] Aux_Channel;
    master: Master_Channel;
    loudness_meter: Loudness_Meter;
    sample_rate: s64 = DEFAULT_SAMPLE_RATE;
    beats_per_minute: float = 120.0;
}
