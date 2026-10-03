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
}
