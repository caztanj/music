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
    sample_rate: s64 = DEFAULT_SAMPLE_RATE;
    beats_per_minute: float = 120.0;
}
