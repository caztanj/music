song_model_tests :: () {
    test("project configuration defaults", () {
        configuration: Project_Configuration;
        expect_equals(configuration.name, "Untitled");
        expect_equals(configuration.beats_per_minute, 120.0);
        expect_equals(configuration.time_signature_numerator, 4);
        expect_equals(configuration.time_signature_denominator, 4);
        expect_equals(configuration.total_bars, 16);
    });

    test("waveform type conversions", () {
        sawtooth_type, sawtooth_success := string_to_waveform_type("saw");
        expect_true(sawtooth_success);
        expect_equals(sawtooth_type, Waveform_Type.SAWTOOTH);

        square_type, square_success := string_to_waveform_type("square");
        expect_true(square_success);
        expect_equals(square_type, Waveform_Type.SQUARE);

        sine_type, sine_success := string_to_waveform_type("sine");
        expect_true(sine_success);
        expect_equals(sine_type, Waveform_Type.SINE);

        triangle_type, triangle_success := string_to_waveform_type("triangle");
        expect_true(triangle_success);
        expect_equals(triangle_type, Waveform_Type.TRIANGLE);

        invalid_type, invalid_success := string_to_waveform_type("unknown");
        expect_true(!invalid_success);

        expect_equals(waveform_type_to_string(Waveform_Type.SAWTOOTH), "sawtooth");
        expect_equals(waveform_type_to_string(Waveform_Type.SQUARE), "square");
        expect_equals(waveform_type_to_string(Waveform_Type.SINE), "sine");
        expect_equals(waveform_type_to_string(Waveform_Type.TRIANGLE), "triangle");
    });

    test("filter type conversions", () {
        lowpass_type, lowpass_success := string_to_filter_type("lowpass");
        expect_true(lowpass_success);
        expect_equals(lowpass_type, Filter_Type.LOWPASS);

        highpass_type, highpass_success := string_to_filter_type("highpass");
        expect_true(highpass_success);
        expect_equals(highpass_type, Filter_Type.HIGHPASS);

        bandpass_type, bandpass_success := string_to_filter_type("bandpass");
        expect_true(bandpass_success);
        expect_equals(bandpass_type, Filter_Type.BANDPASS);

        expect_equals(filter_type_to_string(Filter_Type.LOWPASS), "lowpass");
        expect_equals(filter_type_to_string(Filter_Type.HIGHPASS), "highpass");
        expect_equals(filter_type_to_string(Filter_Type.BANDPASS), "bandpass");
        expect_equals(filter_type_to_string(Filter_Type.NONE), "none");
    });

    test("calculate total steps and duration", () {
        song_specification: Song_Specification;
        song_specification.project.total_bars = 8;
        song_specification.project.beats_per_minute = 120.0;
        song_specification.project.time_signature_numerator = 4;

        total_steps := calculate_total_steps(*song_specification);
        expect_equals(total_steps, 128);

        duration_seconds := calculate_song_duration_seconds(*song_specification);
        expect_near(cast(float) duration_seconds, 16.0, 0.001);
    });

    test("find elements in song specification", () {
        song_specification: Song_Specification;

        instrument: Instrument_Definition;
        instrument.name = "kick";
        instrument.type = .SAMPLER;
        array_add(*song_specification.instruments, instrument);

        found_instrument, instrument_success := find_instrument(*song_specification, "kick");
        expect_true(instrument_success);
        expect_equals(found_instrument.name, "kick");

        missing_instrument, missing_instrument_success := find_instrument(*song_specification, "snare");
        expect_true(!missing_instrument_success);

        pattern: Pattern_Definition;
        pattern.name = "drums_main";
        array_add(*song_specification.patterns, pattern);

        found_pattern, pattern_success := find_pattern(*song_specification, "drums_main");
        expect_true(pattern_success);
        expect_equals(found_pattern.name, "drums_main");

        missing_pattern, missing_pattern_success := find_pattern(*song_specification, "bass_loop");
        expect_true(!missing_pattern_success);

        track: Mixer_Track_Definition;
        track.track_index = 2;
        track.name = "bass";
        array_add(*song_specification.mixer.tracks, track);

        found_track, track_success := find_mixer_track(*song_specification, 2);
        expect_true(track_success);
        expect_equals(found_track.name, "bass");

        missing_track, missing_track_success := find_mixer_track(*song_specification, 9);
        expect_true(!missing_track_success);

        routing: Routing_Definition;
        routing.instrument_name = "kick";
        routing.track_index = 1;
        array_add(*song_specification.routings, routing);

        found_routing, routing_success := find_routing_for_instrument(*song_specification, "kick");
        expect_true(routing_success);
        expect_equals(found_routing.track_index, 1);

        missing_routing, missing_routing_success := find_routing_for_instrument(*song_specification, "lead");
        expect_true(!missing_routing_success);
    });
}
