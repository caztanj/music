initialize_sequencer_clock :: (clock: *Sequencer_Clock, sample_rate: s64 = DEFAULT_SAMPLE_RATE, beats_per_minute: float = 120.0, total_bars: s64 = 16, time_signature_numerator: s64 = 4, time_signature_denominator: s64 = 4, swing: float = 0.5) {
    clock.current_sample = 0;
    clock.sample_rate = sample_rate;
    clock.beats_per_minute = beats_per_minute;
    clock.total_bars = total_bars;
    clock.time_signature_numerator = time_signature_numerator;
    clock.time_signature_denominator = time_signature_denominator;
    clock.swing = swing;
    clock.is_playing = true;
    clock.is_looping = true;
}


calculate_samples_per_beat :: (sample_rate: s64, beats_per_minute: float) -> float64 {
    if beats_per_minute <= 0.0 {
        return 0.0;
    }

    samples_per_beat := (cast(float64) sample_rate * 60.0) / cast(float64) beats_per_minute;

    return samples_per_beat;
}

calculate_samples_per_step :: (sample_rate: s64, beats_per_minute: float) -> float64 {
    samples_per_beat := calculate_samples_per_beat(sample_rate, beats_per_minute);
    samples_per_step := samples_per_beat / 4.0;

    return samples_per_step;
}

calculate_step_sample_position :: (step_index: s64, samples_per_step: float64, swing_amount: float = 0.5) -> u64 {
    clamped_swing := clamp_swing_value(swing_amount);
    is_odd_step := (step_index % 2) != 0;

    effective_step := cast(float64) step_index;
    if is_odd_step {
        swing_offset := cast(float64) (2.0 * (clamped_swing - 0.5));
        effective_step += swing_offset;
    }

    if effective_step < 0.0 {
        return 0;
    }

    sample_position := cast(u64) (effective_step * samples_per_step + 0.5);

    return sample_position;
}

calculate_step_and_tick_sample_position :: (step_index: s64, tick_offset: s64, samples_per_step: float64, swing_amount: float = 0.5) -> u64 {
    clamped_swing := clamp_swing_value(swing_amount);
    samples_per_tick := samples_per_step / cast(float64) TICKS_PER_STEP;

    is_odd_step := (step_index % 2) != 0;
    effective_step := cast(float64) step_index;
    if is_odd_step {
        swing_offset := cast(float64) (2.0 * (clamped_swing - 0.5));
        effective_step += swing_offset;
    }

    step_sample := effective_step * samples_per_step;
    tick_sample := cast(float64) tick_offset * samples_per_tick;
    total_sample := step_sample + tick_sample;

    if total_sample < 0.0 {
        return 0;
    }

    sample_position := cast(u64) (total_sample + 0.5);

    return sample_position;
}

calculate_pattern_step_and_tick_sample_position :: (pattern: *Pattern_Definition, global_bar_index: s64, step_index: s64, tick_offset: s64, sample_rate: s64, beats_per_minute: float, swing_amount: float = 0.5) -> u64 {
    samples_per_bar := calculate_samples_per_bar(sample_rate, beats_per_minute);
    bar_start_sample := cast(u64) (cast(float64) global_bar_index * samples_per_bar + 0.5);

    if pattern == null || pattern.subdivision == .STANDARD_16TH {
        samples_per_step := calculate_samples_per_step(sample_rate, beats_per_minute);
        in_bar_sample := calculate_step_and_tick_sample_position(step_index, tick_offset, samples_per_step, swing_amount);

        return bar_start_sample + in_bar_sample;
    }

    samples_per_beat := calculate_samples_per_beat(sample_rate, beats_per_minute);
    samples_per_tick := samples_per_beat / cast(float64) TICKS_PER_BEAT;

    triplet_step_ticks: s64 = 24;
    if pattern.subdivision == {
        case .TRIPLET_8TH;
            triplet_step_ticks = 32;

        case .TRIPLET_16TH;
            triplet_step_ticks = 16;

        case .TRIPLET_32ND;
            triplet_step_ticks = 8;
    }

    total_ticks := step_index * triplet_step_ticks + tick_offset;
    if total_ticks < 0 {
        total_ticks = 0;
    }

    in_bar_sample := cast(u64) (cast(float64) total_ticks * samples_per_tick + 0.5);

    return bar_start_sample + in_bar_sample;
}



calculate_samples_per_bar :: (sample_rate: s64, beats_per_minute: float, time_signature_numerator: s64 = 4) -> float64 {
    samples_per_step := calculate_samples_per_step(sample_rate, beats_per_minute);
    samples_per_bar := samples_per_step * cast(float64) (time_signature_numerator * 4);

    return samples_per_bar;
}

calculate_total_clock_samples :: (clock: *Sequencer_Clock) -> u64 {
    samples_per_bar := calculate_samples_per_bar(clock.sample_rate, clock.beats_per_minute, clock.time_signature_numerator);
    total_samples := cast(u64) (samples_per_bar * cast(float64) clock.total_bars);

    return total_samples;
}

get_current_bar_index :: (clock: *Sequencer_Clock) -> s64 {
    samples_per_bar := calculate_samples_per_bar(clock.sample_rate, clock.beats_per_minute, clock.time_signature_numerator);
    if samples_per_bar <= 0.0 {
        return 1;
    }

    bar_index := cast(s64) (cast(float64) clock.current_sample / samples_per_bar) + 1;

    return bar_index;
}

get_current_beat_index :: (clock: *Sequencer_Clock) -> s64 {
    samples_per_beat := calculate_samples_per_beat(clock.sample_rate, clock.beats_per_minute);
    if samples_per_beat <= 0.0 {
        return 1;
    }

    global_beat := cast(s64) (cast(float64) clock.current_sample / samples_per_beat);
    beat_index := (global_beat % clock.time_signature_numerator) + 1;

    return beat_index;
}

get_current_step_index :: (clock: *Sequencer_Clock) -> s64 {
    samples_per_step := calculate_samples_per_step(clock.sample_rate, clock.beats_per_minute);
    if samples_per_step <= 0.0 {
        return 0;
    }

    global_step := cast(s64) (cast(float64) clock.current_sample / samples_per_step);
    step_index := global_step % STEPS_PER_BAR;

    return step_index;
}

get_current_global_step :: (clock: *Sequencer_Clock) -> s64 {
    samples_per_step := calculate_samples_per_step(clock.sample_rate, clock.beats_per_minute);
    if samples_per_step <= 0.0 {
        return 0;
    }

    global_step := cast(s64) (cast(float64) clock.current_sample / samples_per_step);

    return global_step;
}

advance_sequencer_clock :: (clock: *Sequencer_Clock, frame_count: s64) {
    if !clock.is_playing {
        return;
    }

    total_samples := calculate_total_clock_samples(clock);
    new_sample := clock.current_sample + cast(u64) frame_count;

    if total_samples > 0 && new_sample >= total_samples {
        if clock.is_looping {
            clock.current_sample = new_sample % total_samples;
        } else {
            clock.current_sample = total_samples;
            clock.is_playing = false;
        }
    } else {
        clock.current_sample = new_sample;
    }
}

reset_sequencer_clock :: (clock: *Sequencer_Clock) {
    clock.current_sample = 0;
    clock.is_playing = true;
}

seek_sequencer_clock :: (clock: *Sequencer_Clock, sample_position: u64) {
    total_samples := calculate_total_clock_samples(clock);
    if total_samples > 0 && sample_position >= total_samples {
        if clock.is_looping {
            clock.current_sample = sample_position % total_samples;
        } else {
            clock.current_sample = total_samples;
        }
    } else {
        clock.current_sample = sample_position;
    }
}

initialize_sample_pool :: (pool: *Sample_Pool) {
    pool.entry_count = 0;
}

find_sample_in_pool :: (pool: *Sample_Pool, instrument_name: string) -> *Audio_Sample_Buffer, bool {
    index := 0;
    while index < pool.entry_count {
        if pool.entries[index].instrument_name == instrument_name {
            return *pool.entries[index].buffer, true;
        }

        index += 1;
    }

    return null, false;
}

add_sample_to_pool :: (pool: *Sample_Pool, instrument_name: string, buffer: Audio_Sample_Buffer) -> bool {
    existing, found := find_sample_in_pool(pool, instrument_name);
    if found {
        existing.* = buffer;
        return true;
    }

    if pool.entry_count >= MAXIMUM_SAMPLE_POOL_ENTRIES {
        return false;
    }

    pool.entries[pool.entry_count].instrument_name = instrument_name;
    pool.entries[pool.entry_count].buffer = buffer;
    pool.entry_count += 1;

    return true;
}

load_samples_for_song :: (pool: *Sample_Pool, song_specification: *Song_Specification) -> bool {
    instrument_index := 0;
    while instrument_index < song_specification.instruments.count {
        instrument := *song_specification.instruments[instrument_index];
        if instrument.type == .SAMPLER {
            buffer, load_success := load_wav_file(instrument.sampler.sample_file_path);
            if load_success {
                buffer.root_midi_note = instrument.sampler.root_midi_note;
                add_sample_to_pool(pool, instrument.name, buffer);
            }
        }

        instrument_index += 1;
    }

    return true;
}

initialize_sequencer :: (sequencer: *Sequencer, sample_rate: s64 = DEFAULT_SAMPLE_RATE) {
    initialize_sequencer_clock(*sequencer.clock, sample_rate);
    initialize_sample_pool(*sequencer.sample_pool);
    sequencer.event_count = 0;
}

configure_sequencer_from_song :: (sequencer: *Sequencer, song_specification: *Song_Specification, sample_rate: s64 = DEFAULT_SAMPLE_RATE) {
    initialize_sequencer_clock(*sequencer.clock, sample_rate, song_specification.project.beats_per_minute, song_specification.project.total_bars, song_specification.project.time_signature_numerator, song_specification.project.time_signature_denominator, song_specification.project.swing);
    initialize_sample_pool(*sequencer.sample_pool);
    load_samples_for_song(*sequencer.sample_pool, song_specification);
    sequencer.event_count = 0;
}


find_instrument_for_pattern :: (song_specification: *Song_Specification, pattern: *Pattern_Definition) -> *Instrument_Definition, bool {
    exact_instrument, exact_found := find_instrument(song_specification, pattern.name);
    if exact_found {
        return exact_instrument, true;
    }

    instrument_index := 0;
    while instrument_index < song_specification.instruments.count {
        candidate := *song_specification.instruments[instrument_index];
        if candidate.name.count > 0 && pattern.name.count >= candidate.name.count {
            prefix: string;
            prefix.data = pattern.name.data;
            prefix.count = candidate.name.count;
            if prefix == candidate.name {
                return candidate, true;
            }
        }

        instrument_index += 1;
    }

    piano_pattern_index := 0;
    current_pattern_index := 0;
    while current_pattern_index < song_specification.patterns.count {
        current_pattern := *song_specification.patterns[current_pattern_index];
        if current_pattern == pattern {
            break;
        }

        if current_pattern.piano_roll_notes.count > 0 {
            piano_pattern_index += 1;
        }

        current_pattern_index += 1;
    }

    synthesizer_counter := 0;
    instrument_index = 0;
    while instrument_index < song_specification.instruments.count {
        candidate := *song_specification.instruments[instrument_index];
        if candidate.type == .SYNTHESIZER {
            if synthesizer_counter == piano_pattern_index {
                return candidate, true;
            }

            synthesizer_counter += 1;
        }

        instrument_index += 1;
    }

    if song_specification.instruments.count > 0 {
        return *song_specification.instruments[0], true;
    }

    return null, false;
}

add_sequencer_event :: (sequencer: *Sequencer, event_type: Sequencer_Event_Type, instrument_name: string, mixer_track_index: s64, midi_note_number: s32, velocity: float, sample_offset_in_block: s64) {
    if sequencer.event_count >= MAXIMUM_SEQUENCER_EVENTS_PER_BLOCK {
        return;
    }

    event := *sequencer.events[sequencer.event_count];
    event.event_type = event_type;
    event.instrument_name = instrument_name;
    event.mixer_track_index = mixer_track_index;
    event.midi_note_number = midi_note_number;
    event.velocity = velocity;
    event.sample_offset_in_block = sample_offset_in_block;

    sequencer.event_count += 1;
}

collect_events_at_step :: (sequencer: *Sequencer, song_specification: *Song_Specification, global_step_index: s64, range_start_sample: u64, range_end_sample: u64, base_offset: s64, samples_per_step: float64) {
    bar_index := (global_step_index / STEPS_PER_BAR) + 1;
    step_in_bar := global_step_index % STEPS_PER_BAR;

    clip_index := 0;
    while clip_index < song_specification.arrangement.clips.count {
        clip := *song_specification.arrangement.clips[clip_index];
        if bar_index >= clip.start_bar && bar_index <= clip.end_bar {
            pattern, pattern_found := find_pattern(song_specification, clip.pattern_name);
            if pattern_found && !is_triplet_subdivision(pattern.subdivision) {
                pattern_swing := get_pattern_effective_swing(song_specification, pattern);
                step_sample := calculate_step_sample_position(global_step_index, samples_per_step, pattern_swing);

                note_index := 0;
                while note_index < pattern.piano_roll_notes.count {
                    note := *pattern.piano_roll_notes[note_index];
                    instrument, instrument_found := find_instrument_for_pattern(song_specification, pattern);
                    if instrument_found {
                        routing, routing_found := find_routing_for_instrument(song_specification, instrument.name);
                        track_index := ifx routing_found then routing.track_index else 1;

                        if note.start_step == step_in_bar {
                            note_on_sample := calculate_step_and_tick_sample_position(global_step_index, note.tick_offset, samples_per_step, pattern_swing);
                            if note_on_sample >= range_start_sample && note_on_sample < range_end_sample {
                                sample_offset_in_block := base_offset + cast(s64) (note_on_sample - range_start_sample);
                                add_sequencer_event(sequencer, .NOTE_ON, instrument.name, track_index, note.midi_note_number, note.velocity, sample_offset_in_block);
                            }
                        }

                        duration_ticks := ifx note.length_ticks > 0 then note.length_ticks else note.step_length * TICKS_PER_STEP;
                        total_note_ticks := note.start_step * TICKS_PER_STEP + note.tick_offset + duration_ticks;
                        end_step := total_note_ticks / TICKS_PER_STEP;
                        end_tick := total_note_ticks % TICKS_PER_STEP;

                        if end_step % STEPS_PER_BAR == step_in_bar {
                            global_end_step := (bar_index - 1) * STEPS_PER_BAR + end_step;
                            note_off_sample := calculate_step_and_tick_sample_position(global_end_step, end_tick, samples_per_step, pattern_swing);
                            if note_off_sample >= range_start_sample && note_off_sample < range_end_sample {
                                sample_offset_in_block := base_offset + cast(s64) (note_off_sample - range_start_sample);
                                add_sequencer_event(sequencer, .NOTE_OFF, instrument.name, track_index, note.midi_note_number, 0.0, sample_offset_in_block);
                            }
                        }
                    }

                    note_index += 1;
                }

                track_index := 0;
                while track_index < pattern.step_tracks.count {
                    step_track := *pattern.step_tracks[track_index];
                    routing, routing_found := find_routing_for_instrument(song_specification, step_track.instrument_name);
                    mixer_track := ifx routing_found then routing.track_index else 1;
                    root_note: s32 = 60;
                    target_instrument, target_found := find_instrument(song_specification, step_track.instrument_name);
                    if target_found && target_instrument.type == .SAMPLER {
                        root_note = target_instrument.sampler.root_midi_note;
                    }

                    if step_track.step_events.count > 0 {
                        event_index := 0;
                        while event_index < step_track.step_events.count {
                            event := *step_track.step_events[event_index];
                            if event.step_index == step_in_bar {
                                event_sample := calculate_step_and_tick_sample_position(global_step_index, event.tick_offset, samples_per_step, pattern_swing);
                                if event_sample >= range_start_sample && event_sample < range_end_sample {
                                    sample_offset_in_block := base_offset + cast(s64) (event_sample - range_start_sample);
                                    add_sequencer_event(sequencer, .NOTE_ON, step_track.instrument_name, mixer_track, root_note, event.velocity, sample_offset_in_block);
                                }
                            }
                            event_index += 1;
                        }
                    } else if step_in_bar < step_track.steps.count && step_track.steps[step_in_bar] {
                        if step_sample >= range_start_sample && step_sample < range_end_sample {
                            velocity := ifx step_in_bar < step_track.velocities.count then step_track.velocities[step_in_bar] else 1.0;
                            sample_offset_in_block := base_offset + cast(s64) (step_sample - range_start_sample);
                            add_sequencer_event(sequencer, .NOTE_ON, step_track.instrument_name, mixer_track, root_note, velocity, sample_offset_in_block);
                        }
                    }

                    track_index += 1;
                }
            }
        }

        clip_index += 1;
    }
}

collect_triplet_pattern_events_for_bar :: (sequencer: *Sequencer, song_specification: *Song_Specification, pattern: *Pattern_Definition, bar_index: s64, range_start_sample: u64, range_end_sample: u64, base_offset: s64) {
    track_index := 0;
    while track_index < pattern.step_tracks.count {
        step_track := *pattern.step_tracks[track_index];
        routing, routing_found := find_routing_for_instrument(song_specification, step_track.instrument_name);
        mixer_track := ifx routing_found then routing.track_index else 1;
        root_note: s32 = 60;
        target_instrument, target_found := find_instrument(song_specification, step_track.instrument_name);
        if target_found && target_instrument.type == .SAMPLER {
            root_note = target_instrument.sampler.root_midi_note;
        }

        if step_track.step_events.count > 0 {
            event_index := 0;
            while event_index < step_track.step_events.count {
                event := *step_track.step_events[event_index];
                event_sample := calculate_pattern_step_and_tick_sample_position(pattern, bar_index - 1, event.step_index, event.tick_offset, sequencer.clock.sample_rate, sequencer.clock.beats_per_minute);
                if event_sample >= range_start_sample && event_sample < range_end_sample {
                    sample_offset_in_block := base_offset + cast(s64) (event_sample - range_start_sample);
                    add_sequencer_event(sequencer, .NOTE_ON, step_track.instrument_name, mixer_track, root_note, event.velocity, sample_offset_in_block);
                }
                event_index += 1;
            }
        } else {
            step_index := 0;
            while step_index < step_track.steps.count {
                if step_track.steps[step_index] {
                    velocity := ifx step_index < step_track.velocities.count then step_track.velocities[step_index] else 1.0;
                    step_sample := calculate_pattern_step_and_tick_sample_position(pattern, bar_index - 1, step_index, 0, sequencer.clock.sample_rate, sequencer.clock.beats_per_minute);
                    if step_sample >= range_start_sample && step_sample < range_end_sample {
                        sample_offset_in_block := base_offset + cast(s64) (step_sample - range_start_sample);
                        add_sequencer_event(sequencer, .NOTE_ON, step_track.instrument_name, mixer_track, root_note, velocity, sample_offset_in_block);
                    }
                }
                step_index += 1;
            }
        }

        track_index += 1;
    }

    note_index := 0;
    while note_index < pattern.piano_roll_notes.count {
        note := *pattern.piano_roll_notes[note_index];
        instrument, instrument_found := find_instrument_for_pattern(song_specification, pattern);
        if instrument_found {
            routing, routing_found := find_routing_for_instrument(song_specification, instrument.name);
            mixer_track := ifx routing_found then routing.track_index else 1;

            note_on_sample := calculate_pattern_step_and_tick_sample_position(pattern, bar_index - 1, note.start_step, note.tick_offset, sequencer.clock.sample_rate, sequencer.clock.beats_per_minute);
            if note_on_sample >= range_start_sample && note_on_sample < range_end_sample {
                sample_offset_in_block := base_offset + cast(s64) (note_on_sample - range_start_sample);
                add_sequencer_event(sequencer, .NOTE_ON, instrument.name, mixer_track, note.midi_note_number, note.velocity, sample_offset_in_block);
            }

            duration_ticks := ifx note.length_ticks > 0 then note.length_ticks else note.step_length * 16;
            note_off_sample := calculate_pattern_step_and_tick_sample_position(pattern, bar_index - 1, note.start_step, note.tick_offset + duration_ticks, sequencer.clock.sample_rate, sequencer.clock.beats_per_minute);
            if note_off_sample >= range_start_sample && note_off_sample < range_end_sample {
                sample_offset_in_block := base_offset + cast(s64) (note_off_sample - range_start_sample);
                add_sequencer_event(sequencer, .NOTE_OFF, instrument.name, mixer_track, note.midi_note_number, 0.0, sample_offset_in_block);
            }
        }
        note_index += 1;
    }
}

collect_triplet_pattern_events_in_range :: (sequencer: *Sequencer, song_specification: *Song_Specification, range_start_sample: u64, range_end_sample: u64, base_offset: s64) {
    samples_per_bar := calculate_samples_per_bar(sequencer.clock.sample_rate, sequencer.clock.beats_per_minute, sequencer.clock.time_signature_numerator);
    if samples_per_bar <= 0.0 {
        return;
    }

    first_bar := cast(s64) (cast(float64) range_start_sample / samples_per_bar) + 1;
    if first_bar < 1 {
        first_bar = 1;
    }
    last_bar := cast(s64) (cast(float64) range_end_sample / samples_per_bar) + 1;

    clip_index := 0;
    while clip_index < song_specification.arrangement.clips.count {
        clip := *song_specification.arrangement.clips[clip_index];
        pattern, pattern_found := find_pattern(song_specification, clip.pattern_name);
        if pattern_found && is_triplet_subdivision(pattern.subdivision) {
            bar_index := first_bar;
            while bar_index <= last_bar {
                if bar_index >= clip.start_bar && bar_index <= clip.end_bar {
                    collect_triplet_pattern_events_for_bar(sequencer, song_specification, pattern, bar_index, range_start_sample, range_end_sample, base_offset);
                }
                bar_index += 1;
            }
        }
        clip_index += 1;
    }
}

collect_events_in_range :: (sequencer: *Sequencer, song_specification: *Song_Specification, range_start_sample: u64, range_end_sample: u64, base_offset: s64) {
    samples_per_step := calculate_samples_per_step(sequencer.clock.sample_rate, sequencer.clock.beats_per_minute);
    if samples_per_step <= 0.0 {
        return;
    }

    first_step := cast(s64) (cast(float64) range_start_sample / samples_per_step) - 1;
    if first_step < 0 {
        first_step = 0;
    }

    last_step := cast(s64) (cast(float64) range_end_sample / samples_per_step) + 2;

    step_index := first_step;
    while step_index <= last_step {
        collect_events_at_step(sequencer, song_specification, step_index, range_start_sample, range_end_sample, base_offset, samples_per_step);
        step_index += 1;
    }

    collect_triplet_pattern_events_in_range(sequencer, song_specification, range_start_sample, range_end_sample, base_offset);
}

sort_sequencer_events :: (sequencer: *Sequencer) {
    index := 1;
    while index < sequencer.event_count {
        current_event := sequencer.events[index];
        hole := index;

        while hole > 0 && sequencer.events[hole - 1].sample_offset_in_block > current_event.sample_offset_in_block {
            sequencer.events[hole] = sequencer.events[hole - 1];
            hole -= 1;
        }

        sequencer.events[hole] = current_event;
        index += 1;
    }
}

collect_sequencer_events_for_block :: (sequencer: *Sequencer, song_specification: *Song_Specification, frame_count: s64) {
    sequencer.event_count = 0;

    if !sequencer.clock.is_playing {
        return;
    }

    total_samples := calculate_total_clock_samples(*sequencer.clock);
    block_start_sample := sequencer.clock.current_sample;
    block_end_sample := block_start_sample + cast(u64) frame_count;

    if total_samples > 0 && sequencer.clock.is_looping && block_end_sample > total_samples {
        samples_before_wrap := total_samples - block_start_sample;
        collect_events_in_range(sequencer, song_specification, block_start_sample, total_samples, 0);
        samples_after_wrap := block_end_sample - total_samples;
        collect_events_in_range(sequencer, song_specification, 0, samples_after_wrap, cast(s64) samples_before_wrap);
    } else {
        collect_events_in_range(sequencer, song_specification, block_start_sample, block_end_sample, 0);
    }

    sort_sequencer_events(sequencer);
}


dispatch_sequencer_event :: (event: *Sequencer_Event, song_specification: *Song_Specification, voice_manager: *Voice_Manager, sample_pool: *Sample_Pool = null) {
    if event.event_type == {
        case .NOTE_ON;
            instrument, instrument_found := find_instrument(song_specification, event.instrument_name);
            if instrument_found {
                if instrument.type == {
                    case .SYNTHESIZER;
                        trigger_synthesizer_note(voice_manager, event.instrument_name, event.mixer_track_index, instrument.synthesizer, event.midi_note_number, event.velocity);

                    case .SAMPLER;
                        if sample_pool != null {
                            buffer, buffer_found := find_sample_in_pool(sample_pool, event.instrument_name);
                            if buffer_found {
                                trigger_sampler_note(voice_manager, event.instrument_name, event.mixer_track_index, buffer, instrument.sampler, event.midi_note_number, event.velocity);
                            }
                        }

                    case;
                }
            }

        case .NOTE_OFF;
            trigger_note_off(voice_manager, event.instrument_name, event.midi_note_number);
    }
}

render_sequencer_block :: (sequencer: *Sequencer, song_specification: *Song_Specification, voice_manager: *Voice_Manager, mixer: *Mixer, output_buffer: [] float, frame_count: s64) {
    voice_manager.beats_per_minute = song_specification.project.beats_per_minute;
    clear_channel_buffers(mixer, frame_count);
    collect_sequencer_events_for_block(sequencer, song_specification, frame_count);

    if sequencer.event_count == 0 {
        track_index := 0;
        while track_index < MAXIMUM_TRACKS {
            channel := *mixer.tracks[track_index];
            left_slice: [] float;
            left_slice.data = channel.left_buffer.data;
            left_slice.count = frame_count;
            right_slice: [] float;
            right_slice.data = channel.right_buffer.data;
            right_slice.count = frame_count;

            render_track_voices_into_buffer(voice_manager, channel.track_index, left_slice, right_slice);
            track_index += 1;
        }
    } else {
        current_block_offset: s64 = 0;
        event_cursor: s64 = 0;

        while current_block_offset < frame_count {
            next_event_offset := frame_count;
            if event_cursor < sequencer.event_count {
                next_event_offset = sequencer.events[event_cursor].sample_offset_in_block;
                if next_event_offset > frame_count {
                    next_event_offset = frame_count;
                }
            }

            chunk_frames := next_event_offset - current_block_offset;
            if chunk_frames > 0 {
                track_index := 0;
                while track_index < MAXIMUM_TRACKS {
                    channel := *mixer.tracks[track_index];
                    left_slice: [] float;
                    left_slice.data = channel.left_buffer.data + current_block_offset;
                    left_slice.count = chunk_frames;
                    right_slice: [] float;
                    right_slice.data = channel.right_buffer.data + current_block_offset;
                    right_slice.count = chunk_frames;

                    render_track_voices_into_buffer(voice_manager, channel.track_index, left_slice, right_slice);
                    track_index += 1;
                }

                current_block_offset = next_event_offset;
            }

            while event_cursor < sequencer.event_count && sequencer.events[event_cursor].sample_offset_in_block == current_block_offset {
                dispatch_sequencer_event(*sequencer.events[event_cursor], song_specification, voice_manager, *sequencer.sample_pool);
                event_cursor += 1;
            }
        }
    }

    mix_channels_to_master(mixer, frame_count);
    render_mixer_master_block_interleaved(mixer, output_buffer, frame_count);
    advance_sequencer_clock(*sequencer.clock, frame_count);
}

MAXIMUM_SEQUENCER_EVENTS_PER_BLOCK :: 512;
MAXIMUM_SAMPLE_POOL_ENTRIES :: 64;

Sequencer_Event_Type :: enum {
    NOTE_OFF;
    NOTE_ON;
}

Sequencer_Event :: struct {
    event_type: Sequencer_Event_Type = .NOTE_ON;
    instrument_name: string;
    mixer_track_index: s64 = 1;
    midi_note_number: s32 = 60;
    velocity: float = 1.0;
    sample_offset_in_block: s64 = 0;
}

Sequencer_Clock :: struct {
    current_sample: u64 = 0;
    sample_rate: s64 = DEFAULT_SAMPLE_RATE;
    beats_per_minute: float = 120.0;
    time_signature_numerator: s64 = 4;
    time_signature_denominator: s64 = 4;
    total_bars: s64 = 16;
    swing: float = 0.5;
    is_playing: bool = true;
    is_looping: bool = true;
}


Sample_Pool_Entry :: struct {
    instrument_name: string;
    buffer: Audio_Sample_Buffer;
}

Sample_Pool :: struct {
    entries: [MAXIMUM_SAMPLE_POOL_ENTRIES] Sample_Pool_Entry;
    entry_count: s64 = 0;
}

Sequencer :: struct {
    clock: Sequencer_Clock;
    sample_pool: Sample_Pool;
    events: [MAXIMUM_SEQUENCER_EVENTS_PER_BLOCK] Sequencer_Event;
    event_count: s64 = 0;
}
