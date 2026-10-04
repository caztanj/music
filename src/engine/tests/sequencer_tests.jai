sequencer_tests :: () {
    test("sequencer clock time calculations", () {
        clock: Sequencer_Clock;
        initialize_sequencer_clock(*clock, sample_rate = 44100, beats_per_minute = 120.0, total_bars = 4);

        samples_per_beat := calculate_samples_per_beat(44100, 120.0);
        expect_near(cast(float) samples_per_beat, 22050.0, 0.01);

        samples_per_step := calculate_samples_per_step(44100, 120.0);
        expect_near(cast(float) samples_per_step, 5512.5, 0.01);

        samples_per_bar := calculate_samples_per_bar(44100, 120.0, 4);
        expect_near(cast(float) samples_per_bar, 88200.0, 0.01);

        total_samples := calculate_total_clock_samples(*clock);
        expect_equals(cast(s64) total_samples, 88200 * 4);

        bar_1 := get_current_bar_index(*clock);
        expect_equals(bar_1, 1);
        beat_1 := get_current_beat_index(*clock);
        expect_equals(beat_1, 1);
        step_1 := get_current_step_index(*clock);
        expect_equals(step_1, 0);

        seek_sequencer_clock(*clock, 88200);
        bar_2 := get_current_bar_index(*clock);
        expect_equals(bar_2, 2);
    });

    test("sequencer clock advance and looping", () {
        clock: Sequencer_Clock;
        initialize_sequencer_clock(*clock, sample_rate = 1000, beats_per_minute = 120.0, total_bars = 1);
        clock.is_looping = true;

        total_samples := calculate_total_clock_samples(*clock);
        advance_sequencer_clock(*clock, cast(s64) total_samples - 10);
        expect_equals(cast(s64) clock.current_sample, cast(s64) total_samples - 10);

        advance_sequencer_clock(*clock, 20);
        expect_equals(cast(s64) clock.current_sample, 10);

        clock.is_looping = false;
        advance_sequencer_clock(*clock, cast(s64) total_samples);
        expect_true(!clock.is_playing);
        expect_equals(clock.current_sample, total_samples);
    });

    test("sequencer collects step tracks events", () {
        specification: Song_Specification;
        specification.project.beats_per_minute = 120.0;
        specification.project.total_bars = 2;

        instrument: Instrument_Definition;
        instrument.name = "kick";
        instrument.type = .SYNTHESIZER;
        array_add(*specification.instruments, instrument);

        routing: Routing_Definition;
        routing.instrument_name = "kick";
        routing.track_index = 1;
        array_add(*specification.routings, routing);

        pattern: Pattern_Definition;
        pattern.name = "drum_pattern";

        step_track: Step_Sequencer_Track;
        step_track.instrument_name = "kick";
        array_add(*step_track.steps, true);
        array_add(*step_track.velocities, 0.9);

        step_index := 1;
        while step_index < 16 {
            array_add(*step_track.steps, false);
            array_add(*step_track.velocities, 0.0);
            step_index += 1;
        }

        array_add(*pattern.step_tracks, step_track);
        array_add(*specification.patterns, pattern);

        clip: Arrangement_Clip;
        clip.pattern_name = "drum_pattern";
        clip.start_bar = 1;
        clip.end_bar = 2;
        array_add(*specification.arrangement.clips, clip);

        sequencer := New(Sequencer);
        defer free(sequencer);
        configure_sequencer_from_song(sequencer, *specification, sample_rate = 44100);

        collect_sequencer_events_for_block(sequencer, *specification, 1000);
        expect_equals(sequencer.event_count, 1);
        expect_equals(sequencer.events[0].instrument_name, "kick");
        expect_equals(sequencer.events[0].sample_offset_in_block, 0);
        expect_near(sequencer.events[0].velocity, 0.9, 0.001);
    });

    test("sequencer piano roll note on and note off scheduling", () {
        specification: Song_Specification;
        specification.project.beats_per_minute = 120.0;
        specification.project.total_bars = 1;

        instrument: Instrument_Definition;
        instrument.name = "lead";
        instrument.type = .SYNTHESIZER;
        array_add(*specification.instruments, instrument);

        routing: Routing_Definition;
        routing.instrument_name = "lead";
        routing.track_index = 1;
        array_add(*specification.routings, routing);

        pattern: Pattern_Definition;
        pattern.name = "lead_pattern";

        piano_note: Piano_Roll_Note;
        piano_note.midi_note_number = 64;
        piano_note.start_step = 0;
        piano_note.step_length = 2;
        piano_note.velocity = 0.8;
        array_add(*pattern.piano_roll_notes, piano_note);
        array_add(*specification.patterns, pattern);

        clip: Arrangement_Clip;
        clip.pattern_name = "lead_pattern";
        clip.start_bar = 1;
        clip.end_bar = 1;
        array_add(*specification.arrangement.clips, clip);

        sequencer := New(Sequencer);
        defer free(sequencer);
        configure_sequencer_from_song(sequencer, *specification, sample_rate = 44100);

        samples_per_step_float := calculate_samples_per_step(44100, 120.0);
        total_frame_count := cast(s64) (samples_per_step_float * 3.0);

        collect_sequencer_events_for_block(sequencer, *specification, total_frame_count);
        expect_equals(sequencer.event_count, 2);

        expect_equals(cast(s64) sequencer.events[0].event_type, cast(s64) Sequencer_Event_Type.NOTE_ON);
        expect_equals(sequencer.events[0].midi_note_number, 64);
        expect_equals(sequencer.events[0].sample_offset_in_block, 0);

        expect_equals(cast(s64) sequencer.events[1].event_type, cast(s64) Sequencer_Event_Type.NOTE_OFF);
        expect_equals(sequencer.events[1].midi_note_number, 64);
        expect_equals(sequencer.events[1].sample_offset_in_block, cast(s64) (2.0 * samples_per_step_float));
    });

    test("sequencer arrangement bounds respect clip bars", () {
        specification: Song_Specification;
        specification.project.beats_per_minute = 120.0;
        specification.project.total_bars = 4;

        instrument: Instrument_Definition;
        instrument.name = "bass";
        instrument.type = .SYNTHESIZER;
        array_add(*specification.instruments, instrument);

        pattern: Pattern_Definition;
        pattern.name = "bass_pattern";
        piano_note: Piano_Roll_Note;
        piano_note.midi_note_number = 36;
        piano_note.start_step = 0;
        piano_note.step_length = 1;
        piano_note.velocity = 0.9;
        array_add(*pattern.piano_roll_notes, piano_note);
        array_add(*specification.patterns, pattern);

        clip: Arrangement_Clip;
        clip.pattern_name = "bass_pattern";
        clip.start_bar = 2;
        clip.end_bar = 3;
        array_add(*specification.arrangement.clips, clip);

        sequencer := New(Sequencer);
        defer free(sequencer);
        configure_sequencer_from_song(sequencer, *specification, sample_rate = 44100);

        collect_sequencer_events_for_block(sequencer, *specification, 1000);
        expect_equals(sequencer.event_count, 0);

        samples_per_bar := cast(u64) calculate_samples_per_bar(44100, 120.0);
        seek_sequencer_clock(*sequencer.clock, samples_per_bar);

        collect_sequencer_events_for_block(sequencer, *specification, 1000);
        expect_true(sequencer.event_count >= 1);
        expect_equals(sequencer.events[0].instrument_name, "bass");
    });

    test("sequencer block rendering produces audio output", () {
        specification: Song_Specification;
        specification.project.beats_per_minute = 120.0;
        specification.project.total_bars = 1;

        instrument: Instrument_Definition;
        instrument.name = "synth";
        instrument.type = .SYNTHESIZER;
        instrument.synthesizer.waveform = .SAWTOOTH;
        instrument.synthesizer.gain = 1.0;
        instrument.synthesizer.envelope.attack_milliseconds = 1.0;
        instrument.synthesizer.envelope.decay_milliseconds = 20.0;
        instrument.synthesizer.envelope.sustain_level = 0.8;
        instrument.synthesizer.envelope.release_milliseconds = 50.0;
        array_add(*specification.instruments, instrument);

        routing: Routing_Definition;
        routing.instrument_name = "synth";
        routing.track_index = 1;
        array_add(*specification.routings, routing);

        track: Mixer_Track_Definition;
        track.track_index = 1;
        track.gain = 1.0;
        array_add(*specification.mixer.tracks, track);

        pattern: Pattern_Definition;
        pattern.name = "synth_melody";
        piano_note: Piano_Roll_Note;
        piano_note.midi_note_number = 69;
        piano_note.start_step = 0;
        piano_note.step_length = 4;
        piano_note.velocity = 1.0;
        array_add(*pattern.piano_roll_notes, piano_note);
        array_add(*specification.patterns, pattern);

        clip: Arrangement_Clip;
        clip.pattern_name = "synth_melody";
        clip.start_bar = 1;
        clip.end_bar = 1;
        array_add(*specification.arrangement.clips, clip);

        sequencer := New(Sequencer);
        defer free(sequencer);
        configure_sequencer_from_song(sequencer, *specification, sample_rate = 44100);

        voice_manager: Voice_Manager;
        initialize_voice_manager(*voice_manager, sample_rate = 44100);

        mixer := New(Mixer);
        defer {
            deinitialize_mixer(mixer);
            free(mixer);
        }
        initialize_mixer(mixer, sample_rate = 44100);

        output_buffer := NewArray(512 * 2, float);
        defer array_free(output_buffer);

        render_sequencer_block(sequencer, *specification, *voice_manager, mixer, output_buffer, 512);

        maximum_amplitude := 0.0;
        sample_index := 0;
        while sample_index < output_buffer.count {
            amplitude := abs(output_buffer[sample_index]);
            if amplitude > maximum_amplitude {
                maximum_amplitude = amplitude;
            }

            sample_index += 1;
        }

        expect_true(maximum_amplitude > 0.01);
    });

    test("calculate_step_sample_position_timing", () {
        samples_per_step := 1000.0;

        step_0_straight := calculate_step_sample_position(0, samples_per_step, 0.50);
        step_0_swung := calculate_step_sample_position(0, samples_per_step, 0.75);
        expect_equals(cast(s64) step_0_straight, 0);
        expect_equals(cast(s64) step_0_swung, 0);

        step_2_straight := calculate_step_sample_position(2, samples_per_step, 0.50);
        step_2_swung := calculate_step_sample_position(2, samples_per_step, 0.75);
        expect_equals(cast(s64) step_2_straight, 2000);
        expect_equals(cast(s64) step_2_swung, 2000);

        step_1_straight := calculate_step_sample_position(1, samples_per_step, 0.50);
        expect_equals(cast(s64) step_1_straight, 1000);

        step_1_subtle := calculate_step_sample_position(1, samples_per_step, 0.58);
        expect_equals(cast(s64) step_1_subtle, 1160);

        step_1_triplet := calculate_step_sample_position(1, samples_per_step, 0.66);
        expect_equals(cast(s64) step_1_triplet, 1320);

        step_1_hard := calculate_step_sample_position(1, samples_per_step, 0.75);
        expect_equals(cast(s64) step_1_hard, 1500);
    });

    test("global_swing_delays_odd_step_events", () {
        specification: Song_Specification;
        specification.project.beats_per_minute = 120.0;
        specification.project.total_bars = 1;
        specification.project.swing = 0.60;

        instrument: Instrument_Definition;
        instrument.name = "hihat";
        instrument.type = .SYNTHESIZER;
        array_add(*specification.instruments, instrument);

        routing: Routing_Definition;
        routing.instrument_name = "hihat";
        routing.track_index = 1;
        array_add(*specification.routings, routing);

        pattern: Pattern_Definition;
        pattern.name = "hat_pattern";

        step_track: Step_Sequencer_Track;
        step_track.instrument_name = "hihat";
        array_add(*step_track.steps, true);
        array_add(*step_track.velocities, 1.0);
        array_add(*step_track.steps, true);
        array_add(*step_track.velocities, 1.0);

        step_index := 2;
        while step_index < 16 {
            array_add(*step_track.steps, false);
            array_add(*step_track.velocities, 0.0);
            step_index += 1;
        }

        array_add(*pattern.step_tracks, step_track);
        array_add(*specification.patterns, pattern);

        clip: Arrangement_Clip;
        clip.pattern_name = "hat_pattern";
        clip.start_bar = 1;
        clip.end_bar = 1;
        array_add(*specification.arrangement.clips, clip);

        sequencer := New(Sequencer);
        defer free(sequencer);
        configure_sequencer_from_song(sequencer, *specification, sample_rate = 44100);

        samples_per_step_float := calculate_samples_per_step(44100, 120.0);
        total_frame_count := cast(s64) (samples_per_step_float * 2.5);

        collect_sequencer_events_for_block(sequencer, *specification, total_frame_count);
        expect_equals(sequencer.event_count, 2);

        expect_equals(sequencer.events[0].sample_offset_in_block, 0);

        expected_odd_offset := cast(s64) ((1.0 + 2.0 * (0.60 - 0.50)) * samples_per_step_float);
        expect_near(cast(float) sequencer.events[1].sample_offset_in_block, cast(float) expected_odd_offset, 2.0);
    });

    test("per_pattern_swing_independent_timing_and_sorting", () {
        specification: Song_Specification;
        specification.project.beats_per_minute = 120.0;
        specification.project.total_bars = 1;
        specification.project.swing = 0.50;

        kick_instrument: Instrument_Definition;
        kick_instrument.name = "kick";
        kick_instrument.type = .SYNTHESIZER;
        array_add(*specification.instruments, kick_instrument);

        hat_instrument: Instrument_Definition;
        hat_instrument.name = "hat";
        hat_instrument.type = .SYNTHESIZER;
        array_add(*specification.instruments, hat_instrument);

        kick_routing: Routing_Definition;
        kick_routing.instrument_name = "kick";
        kick_routing.track_index = 1;
        array_add(*specification.routings, kick_routing);

        hat_routing: Routing_Definition;
        hat_routing.instrument_name = "hat";
        hat_routing.track_index = 2;
        array_add(*specification.routings, hat_routing);

        swing_pattern: Pattern_Definition;
        swing_pattern.name = "swing_kick_pattern";
        swing_pattern.swing = 0.70;

        kick_step_track: Step_Sequencer_Track;
        kick_step_track.instrument_name = "kick";
        array_add(*kick_step_track.steps, false);
        array_add(*kick_step_track.velocities, 0.0);
        array_add(*kick_step_track.steps, true);
        array_add(*kick_step_track.velocities, 1.0);

        step_index := 2;
        while step_index < 16 {
            array_add(*kick_step_track.steps, false);
            array_add(*kick_step_track.velocities, 0.0);
            step_index += 1;
        }

        array_add(*swing_pattern.step_tracks, kick_step_track);
        array_add(*specification.patterns, swing_pattern);

        straight_pattern: Pattern_Definition;
        straight_pattern.name = "straight_hat_pattern";
        straight_pattern.swing = 0.50;

        hat_step_track: Step_Sequencer_Track;
        hat_step_track.instrument_name = "hat";
        array_add(*hat_step_track.steps, false);
        array_add(*hat_step_track.velocities, 0.0);
        array_add(*hat_step_track.steps, true);
        array_add(*hat_step_track.velocities, 0.8);

        step_index = 2;
        while step_index < 16 {
            array_add(*hat_step_track.steps, false);
            array_add(*hat_step_track.velocities, 0.0);
            step_index += 1;
        }

        array_add(*straight_pattern.step_tracks, hat_step_track);
        array_add(*specification.patterns, straight_pattern);

        swing_clip: Arrangement_Clip;
        swing_clip.pattern_name = "swing_kick_pattern";
        swing_clip.start_bar = 1;
        swing_clip.end_bar = 1;
        array_add(*specification.arrangement.clips, swing_clip);

        straight_clip: Arrangement_Clip;
        straight_clip.pattern_name = "straight_hat_pattern";
        straight_clip.start_bar = 1;
        straight_clip.end_bar = 1;
        array_add(*specification.arrangement.clips, straight_clip);

        sequencer := New(Sequencer);
        defer free(sequencer);
        configure_sequencer_from_song(sequencer, *specification, sample_rate = 44100);

        samples_per_step_float := calculate_samples_per_step(44100, 120.0);
        total_frame_count := cast(s64) (samples_per_step_float * 2.5);

        collect_sequencer_events_for_block(sequencer, *specification, total_frame_count);
        expect_equals(sequencer.event_count, 2);

        expect_equals(sequencer.events[0].instrument_name, "hat");
        expected_straight_offset := cast(s64) samples_per_step_float;
        expect_near(cast(float) sequencer.events[0].sample_offset_in_block, cast(float) expected_straight_offset, 2.0);

        expect_equals(sequencer.events[1].instrument_name, "kick");
        expected_swung_offset := cast(s64) ((1.0 + 2.0 * (0.70 - 0.50)) * samples_per_step_float);
        expect_near(cast(float) sequencer.events[1].sample_offset_in_block, cast(float) expected_swung_offset, 2.0);

        expect_true(sequencer.events[0].sample_offset_in_block < sequencer.events[1].sample_offset_in_block);
    });

    test("step and tick sample calculation accuracy", () {
        samples_per_step := calculate_samples_per_step(44100, 120.0);
        samples_per_tick := samples_per_step / cast(float64) TICKS_PER_STEP;

        pos_0 := calculate_step_and_tick_sample_position(0, 0, samples_per_step);
        expect_equals(cast(s64) pos_0, 0);

        pos_32t2 := calculate_step_and_tick_sample_position(0, 8, samples_per_step);
        expected_32t2 := cast(s64) (samples_per_step / 3.0 + 0.5);
        expect_equals(cast(s64) pos_32t2, expected_32t2);

        pos_32t3 := calculate_step_and_tick_sample_position(0, 16, samples_per_step);
        expected_32t3 := cast(s64) (2.0 * samples_per_step / 3.0 + 0.5);
        expect_equals(cast(s64) pos_32t3, expected_32t3);

        pos_16t2 := calculate_step_and_tick_sample_position(0, 16, samples_per_step);
        pos_16t3 := calculate_step_and_tick_sample_position(0, 32, samples_per_step);
        expect_equals(cast(s64) pos_16t3, cast(s64) (4.0 * samples_per_step / 3.0 + 0.5));

        strum_offset_1 := calculate_step_and_tick_sample_position(2, 10, samples_per_step);
        expected_strum := cast(s64) (2.0 * samples_per_step + 10.0 * samples_per_tick + 0.5);
        expect_equals(cast(s64) strum_offset_1, expected_strum);
    });

    test("sequencer schedules bracket roll events with micro timing", () {
        specification: Song_Specification;
        specification.project.beats_per_minute = 120.0;
        specification.project.total_bars = 1;

        instrument: Instrument_Definition;
        instrument.name = "snare";
        instrument.type = .SYNTHESIZER;
        array_add(*specification.instruments, instrument);

        routing: Routing_Definition;
        routing.instrument_name = "snare";
        routing.track_index = 1;
        array_add(*specification.routings, routing);

        pattern: Pattern_Definition;
        pattern.name = "snare_roll";

        step_track: Step_Sequencer_Track;
        step_track.instrument_name = "snare";
        array_add(*step_track.step_events, Step_Event.{step_index = 0, tick_offset = 0, velocity = 0.9});
        array_add(*step_track.step_events, Step_Event.{step_index = 0, tick_offset = 8, velocity = 0.85});
        array_add(*step_track.step_events, Step_Event.{step_index = 0, tick_offset = 16, velocity = 0.95});
        array_add(*pattern.step_tracks, step_track);
        array_add(*specification.patterns, pattern);

        clip: Arrangement_Clip;
        clip.pattern_name = "snare_roll";
        clip.start_bar = 1;
        clip.end_bar = 1;
        array_add(*specification.arrangement.clips, clip);

        sequencer := New(Sequencer);
        defer free(sequencer);
        configure_sequencer_from_song(sequencer, *specification, sample_rate = 44100);

        samples_per_step_float := calculate_samples_per_step(44100, 120.0);
        samples_per_tick := samples_per_step_float / cast(float64) TICKS_PER_STEP;

        collect_sequencer_events_for_block(sequencer, *specification, cast(s64) samples_per_step_float);
        expect_equals(sequencer.event_count, 3);

        expect_equals(sequencer.events[0].sample_offset_in_block, 0);
        expect_equals(sequencer.events[1].sample_offset_in_block, cast(s64) (8.0 * samples_per_tick + 0.5));
        expect_equals(sequencer.events[2].sample_offset_in_block, cast(s64) (16.0 * samples_per_tick + 0.5));
    });

    test("piano roll strum tick offsets scheduling", () {
        specification: Song_Specification;
        specification.project.beats_per_minute = 120.0;
        specification.project.total_bars = 1;

        instrument: Instrument_Definition;
        instrument.name = "guitar";
        instrument.type = .SYNTHESIZER;
        array_add(*specification.instruments, instrument);

        routing: Routing_Definition;
        routing.instrument_name = "guitar";
        routing.track_index = 1;
        array_add(*specification.routings, routing);

        pattern: Pattern_Definition;
        pattern.name = "strum_pattern";

        note_1: Piano_Roll_Note;
        note_1.midi_note_number = 40;
        note_1.start_step = 0;
        note_1.tick_offset = 0;
        note_1.step_length = 2;
        array_add(*pattern.piano_roll_notes, note_1);

        note_2: Piano_Roll_Note;
        note_2.midi_note_number = 47;
        note_2.start_step = 0;
        note_2.tick_offset = 10;
        note_2.step_length = 2;
        array_add(*pattern.piano_roll_notes, note_2);

        note_3: Piano_Roll_Note;
        note_3.midi_note_number = 52;
        note_3.start_step = 0;
        note_3.tick_offset = 20;
        note_3.step_length = 2;
        array_add(*pattern.piano_roll_notes, note_3);

        array_add(*specification.patterns, pattern);

        clip: Arrangement_Clip;
        clip.pattern_name = "strum_pattern";
        clip.start_bar = 1;
        clip.end_bar = 1;
        array_add(*specification.arrangement.clips, clip);

        sequencer := New(Sequencer);
        defer free(sequencer);
        configure_sequencer_from_song(sequencer, *specification, sample_rate = 44100);

        samples_per_step_float := calculate_samples_per_step(44100, 120.0);
        samples_per_tick := samples_per_step_float / cast(float64) TICKS_PER_STEP;

        collect_sequencer_events_for_block(sequencer, *specification, cast(s64) samples_per_step_float);
        expect_equals(sequencer.event_count, 3);

        expect_equals(sequencer.events[0].midi_note_number, 40);
        expect_equals(sequencer.events[0].sample_offset_in_block, 0);

        expect_equals(sequencer.events[1].midi_note_number, 47);
        expect_equals(sequencer.events[1].sample_offset_in_block, cast(s64) (10.0 * samples_per_tick + 0.5));

        expect_equals(sequencer.events[2].midi_note_number, 52);
        expect_equals(sequencer.events[2].sample_offset_in_block, cast(s64) (20.0 * samples_per_tick + 0.5));
    });

    test("triplet grid pattern timing", () {
        specification: Song_Specification;
        specification.project.beats_per_minute = 120.0;
        specification.project.total_bars = 1;

        instrument: Instrument_Definition;
        instrument.name = "hat";
        instrument.type = .SYNTHESIZER;
        array_add(*specification.instruments, instrument);

        routing: Routing_Definition;
        routing.instrument_name = "hat";
        routing.track_index = 1;
        array_add(*specification.routings, routing);

        pattern: Pattern_Definition;
        pattern.name = "triplet_hats";
        pattern.subdivision = .TRIPLET_8TH;
        pattern.step_count = 12;

        step_track: Step_Sequencer_Track;
        step_track.instrument_name = "hat";
        step_index := 0;
        while step_index < 12 {
            array_add(*step_track.steps, true);
            array_add(*step_track.velocities, 0.8);
            step_index += 1;
        }
        array_add(*pattern.step_tracks, step_track);
        array_add(*specification.patterns, pattern);

        clip: Arrangement_Clip;
        clip.pattern_name = "triplet_hats";
        clip.start_bar = 1;
        clip.end_bar = 1;
        array_add(*specification.arrangement.clips, clip);

        sequencer := New(Sequencer);
        defer free(sequencer);
        configure_sequencer_from_song(sequencer, *specification, sample_rate = 44100);

        samples_per_beat := calculate_samples_per_beat(44100, 120.0);
        samples_per_triplet_step := samples_per_beat / 3.0;

        collect_sequencer_events_for_block(sequencer, *specification, cast(s64) (samples_per_beat * 4.0));
        expect_equals(sequencer.event_count, 12);

        i := 0;
        while i < 12 {
            expected_sample := cast(s64) (cast(float64) i * samples_per_triplet_step + 0.5);
            expect_near(cast(float) sequencer.events[i].sample_offset_in_block, cast(float) expected_sample, 1.0);
            i += 1;
        }
    });
}

