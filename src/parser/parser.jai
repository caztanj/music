parse_song_from_file :: (file_path: string, check_samples_on_disk: bool = true) -> Song_Specification, bool, string {
    file_content, read_success := read_entire_file(file_path);
    if !read_success {
        error_message := sprint("Could not read file '%'", file_path);
        empty_song: Song_Specification;

        return empty_song, false, error_message;
    }
    song_specification, parse_success, error_message := parse_song(file_content, file_path, check_samples_on_disk);

    return song_specification, parse_success, error_message;
}


parse_song :: (source_text: string, filename: string = "", check_samples_on_disk: bool = true) -> Song_Specification, bool, string {
    song_specification: Song_Specification;
    tokens, tokenize_success, tokenize_error := tokenize(source_text, filename);

    if !tokenize_success {
        return song_specification, false, tokenize_error;
    }

    parser: Parser;
    parser.filename = filename;
    parser.tokens = tokens;
    parser.current_token_index = 0;
    parser.check_samples_on_disk = check_samples_on_disk;

    parse_success := parse_entire_song(*parser, *song_specification);
    if !parse_success {
        return song_specification, false, parser.error_message;
    }

    validation_success := validate_song_specification(*parser, *song_specification);
    if !validation_success {
        return song_specification, false, parser.error_message;
    }

    return song_specification, true, "";
}

parse_entire_song :: (parser: *Parser, song_specification: *Song_Specification) -> bool {
    while !parser.has_error && parser.current_token_index < parser.tokens.count {
        skip_newlines(parser);
        token := current_token(parser);

        if token.type == .END_OF_FILE {
            break;
        }

        if token.type != .OPEN_BRACKET {
            set_error(parser, token.location, sprint("Expected section header starting with '[', got '%'", token.text));
            return false;
        }

        advance_token(parser);
        section_token := current_token(parser);

        if section_token.type != .IDENTIFIER {
            set_error(parser, section_token.location, "Expected section name inside brackets");
            return false;
        }

        section_name := section_token.text;
        advance_token(parser);

        if section_name == "project" {
            close_token, close_success := consume_token(parser, .CLOSE_BRACKET, "Expected ']' after project section header");
            if !close_success return false;

            success := parse_project_section(parser, song_specification);
            if !success return false;
        } else if section_name == "instruments" {
            close_token, close_success := consume_token(parser, .CLOSE_BRACKET, "Expected ']' after instruments section header");
            if !close_success return false;

            success := parse_instruments_section(parser, song_specification);
            if !success return false;
        } else if section_name == "pattern" {
            pattern_name_token := current_token(parser);
            if pattern_name_token.type != .IDENTIFIER {
                set_error(parser, pattern_name_token.location, "Expected pattern name after 'pattern'");
                return false;
            }

            pattern_name := pattern_name_token.text;
            advance_token(parser);

            close_token, close_success := consume_token(parser, .CLOSE_BRACKET, "Expected ']' after pattern name");
            if !close_success return false;

            success := parse_pattern_section(parser, pattern_name, pattern_name_token.location, song_specification);
            if !success return false;
        } else if section_name == "mixer" {
            close_token, close_success := consume_token(parser, .CLOSE_BRACKET, "Expected ']' after mixer section header");
            if !close_success return false;

            success := parse_mixer_section(parser, song_specification);
            if !success return false;
        } else if section_name == "channel_routing" {
            close_token, close_success := consume_token(parser, .CLOSE_BRACKET, "Expected ']' after channel_routing section header");
            if !close_success return false;

            success := parse_channel_routing_section(parser, song_specification);
            if !success return false;
        } else if section_name == "arrangement" {
            close_token, close_success := consume_token(parser, .CLOSE_BRACKET, "Expected ']' after arrangement section header");
            if !close_success return false;

            success := parse_arrangement_section(parser, song_specification);
            if !success return false;
        } else {
            set_error(parser, section_token.location, sprint("Unknown section '[%]'", section_name));
            return false;
        }
    }

    return true;
}

parse_project_section :: (parser: *Parser, song_specification: *Song_Specification) -> bool {
    while !parser.has_error && parser.current_token_index < parser.tokens.count {
        skip_newlines(parser);
        token := current_token(parser);

        if token.type == .OPEN_BRACKET || token.type == .END_OF_FILE {
            break;
        }

        if token.type != .IDENTIFIER {
            set_error(parser, token.location, sprint("Expected property name in [project], got '%'", token.text));
            return false;
        }

        property_name := token.text;
        song_specification.project.location = token.location;
        advance_token(parser);

        equals_token, equals_success := consume_token(parser, .EQUALS, "Expected '=' after property name");
        if !equals_success return false;

        if property_name == "name" {
            value_token, value_success := consume_token(parser, .STRING, "Expected string for project name");
            if !value_success return false;
            song_specification.project.name = value_token.string_value;
        } else if property_name == "bpm" || property_name == "beats_per_minute" {
            number_value, number_success := parse_number(parser);
            if !number_success return false;
            song_specification.project.beats_per_minute = cast(float) number_value;
        } else if property_name == "bars" || property_name == "total_bars" {
            value_token, value_success := consume_token(parser, .INTEGER, "Expected integer for total bars");
            if !value_success return false;
            song_specification.project.total_bars = value_token.integer_value;
        } else if property_name == "time_signature" {
            numerator_token, numerator_success := consume_token(parser, .INTEGER, "Expected numerator for time signature");
            if !numerator_success return false;

            slash_token, slash_success := consume_token(parser, .SLASH, "Expected '/' in time signature");
            if !slash_success return false;

            denominator_token, denominator_success := consume_token(parser, .INTEGER, "Expected denominator for time signature");
            if !denominator_success return false;

            song_specification.project.time_signature_numerator = numerator_token.integer_value;
            song_specification.project.time_signature_denominator = denominator_token.integer_value;
        } else {
            set_error(parser, token.location, sprint("Unknown project property '%'", property_name));
            return false;
        }
    }

    return true;
}

parse_instruments_section :: (parser: *Parser, song_specification: *Song_Specification) -> bool {
    while !parser.has_error && parser.current_token_index < parser.tokens.count {
        skip_newlines(parser);
        token := current_token(parser);

        if token.type == .OPEN_BRACKET || token.type == .END_OF_FILE {
            break;
        }

        if token.type != .IDENTIFIER {
            set_error(parser, token.location, sprint("Expected instrument name in [instruments], got '%'", token.text));
            return false;
        }

        instrument_name := token.text;
        instrument_location := token.location;
        advance_token(parser);

        equals_token, equals_success := consume_token(parser, .EQUALS, "Expected '=' after instrument name");
        if !equals_success return false;

        type_token := current_token(parser);
        if type_token.type != .IDENTIFIER {
            set_error(parser, type_token.location, "Expected instrument type ('sampler' or 'synth')");
            return false;
        }

        instrument_type_name := type_token.text;
        advance_token(parser);

        open_parenthesis_token, open_success := consume_token(parser, .OPEN_PARENTHESIS, "Expected '(' after instrument type");
        if !open_success return false;

        instrument: Instrument_Definition;
        instrument.name = instrument_name;
        instrument.location = instrument_location;

        if instrument_type_name == "sampler" {
            instrument.type = .SAMPLER;
            success := parse_sampler_arguments(parser, *instrument.sampler);
            if !success return false;
        } else if instrument_type_name == "synth" || instrument_type_name == "synthesizer" {
            instrument.type = .SYNTHESIZER;
            success := parse_synthesizer_arguments(parser, *instrument.synthesizer);
            if !success return false;
        } else {
            set_error(parser, type_token.location, sprint("Unknown instrument type '%'", instrument_type_name));
            return false;
        }

        close_parenthesis_token, close_success := consume_token(parser, .CLOSE_PARENTHESIS, "Expected ')' at end of instrument declaration");
        if !close_success return false;

        array_add(*song_specification.instruments, instrument);
    }

    return true;
}

parse_sampler_arguments :: (parser: *Parser, sampler_configuration: *Sampler_Configuration) -> bool {
    first_argument := true;

    while !parser.has_error && parser.current_token_index < parser.tokens.count {
        token := current_token(parser);

        if token.type == .CLOSE_PARENTHESIS {
            break;
        }

        if !first_argument {
            comma_token, comma_success := consume_token(parser, .COMMA, "Expected ',' between sampler arguments");
            if !comma_success return false;
        }

        first_argument = false;
        argument_token := current_token(parser);

        if argument_token.type == .STRING && sampler_configuration.sample_file_path.count == 0 {
            sampler_configuration.sample_file_path = argument_token.string_value;
            advance_token(parser);
            continue;
        }

        if argument_token.type != .IDENTIFIER {
            set_error(parser, argument_token.location, "Expected parameter name or sample file path");
            return false;
        }

        parameter_name := argument_token.text;
        advance_token(parser);

        equals_token, equals_success := consume_token(parser, .EQUALS, "Expected '=' after parameter name");
        if !equals_success return false;

        if parameter_name == "path" || parameter_name == "file" {
            path_token, path_success := consume_token(parser, .STRING, "Expected string for sample file path");
            if !path_success return false;
            sampler_configuration.sample_file_path = path_token.string_value;
        } else if parameter_name == "gain" || parameter_name == "volume" {
            gain_value, gain_success := parse_number(parser);
            if !gain_success return false;
            sampler_configuration.gain = cast(float) gain_value;
        } else if parameter_name == "root" || parameter_name == "root_note" {
            root_token := current_token(parser);
            if root_token.type == .INTEGER {
                sampler_configuration.root_midi_note = cast(s32) root_token.integer_value;
                advance_token(parser);
            } else if root_token.type == .IDENTIFIER || root_token.type == .STRING {
                note_name := ifx root_token.type == .STRING then root_token.string_value else root_token.text;
                midi_number := note_to_midi(note_name);
                if midi_number < 0 {
                    set_error(parser, root_token.location, sprint("Invalid root note '%'", note_name));
                    return false;
                }
                sampler_configuration.root_midi_note = midi_number;
                advance_token(parser);
            } else {
                set_error(parser, root_token.location, "Expected note name or MIDI note number for root");
                return false;
            }
        } else {
            set_error(parser, argument_token.location, sprint("Unknown sampler parameter '%'", parameter_name));
            return false;
        }
    }

    return true;
}

parse_synthesizer_arguments :: (parser: *Parser, synthesizer_configuration: *Synthesizer_Configuration) -> bool {
    first_argument := true;

    while !parser.has_error && parser.current_token_index < parser.tokens.count {
        token := current_token(parser);

        if token.type == .CLOSE_PARENTHESIS {
            break;
        }

        if !first_argument {
            comma_token, comma_success := consume_token(parser, .COMMA, "Expected ',' between synthesizer arguments");
            if !comma_success return false;
        }

        first_argument = false;
        parameter_token := current_token(parser);

        if parameter_token.type != .IDENTIFIER {
            set_error(parser, parameter_token.location, "Expected parameter name in synthesizer definition");
            return false;
        }

        parameter_name := parameter_token.text;
        advance_token(parser);

        equals_token, equals_success := consume_token(parser, .EQUALS, "Expected '=' after parameter name");
        if !equals_success return false;

        if parameter_name == "wave" || parameter_name == "waveform" {
            wave_token := current_token(parser);
            wave_name := ifx wave_token.type == .STRING then wave_token.string_value else wave_token.text;
            waveform_type, waveform_success := string_to_waveform_type(wave_name);
            if !waveform_success {
                set_error(parser, wave_token.location, sprint("Unknown waveform '%'", wave_name));
                return false;
            }
            synthesizer_configuration.waveform = waveform_type;
            advance_token(parser);
        } else if parameter_name == "filter" {
            filter_token := current_token(parser);
            filter_name := ifx filter_token.type == .STRING then filter_token.string_value else filter_token.text;
            filter_type, filter_success := string_to_filter_type(filter_name);
            if !filter_success {
                set_error(parser, filter_token.location, sprint("Unknown filter type '%'", filter_name));
                return false;
            }
            synthesizer_configuration.filter.type = filter_type;
            advance_token(parser);
        } else if parameter_name == "cutoff" {
            cutoff_value, cutoff_success := parse_number(parser);
            if !cutoff_success return false;
            synthesizer_configuration.filter.cutoff_frequency_hertz = cast(float) cutoff_value;
        } else if parameter_name == "res" || parameter_name == "resonance" {
            resonance_value, resonance_success := parse_number(parser);
            if !resonance_success return false;
            synthesizer_configuration.filter.resonance = cast(float) resonance_value;
        } else if parameter_name == "attack" {
            attack_value, attack_success := parse_number(parser);
            if !attack_success return false;
            synthesizer_configuration.envelope.attack_milliseconds = cast(float) attack_value;
        } else if parameter_name == "decay" {
            decay_value, decay_success := parse_number(parser);
            if !decay_success return false;
            synthesizer_configuration.envelope.decay_milliseconds = cast(float) decay_value;
        } else if parameter_name == "sustain" {
            sustain_value, sustain_success := parse_number(parser);
            if !sustain_success return false;
            synthesizer_configuration.envelope.sustain_level = cast(float) sustain_value;
        } else if parameter_name == "release" {
            release_value, release_success := parse_number(parser);
            if !release_success return false;
            synthesizer_configuration.envelope.release_milliseconds = cast(float) release_value;
        } else if parameter_name == "gain" || parameter_name == "volume" {
            gain_value, gain_success := parse_number(parser);
            if !gain_success return false;
            synthesizer_configuration.gain = cast(float) gain_value;
        } else {
            set_error(parser, parameter_token.location, sprint("Unknown synthesizer parameter '%'", parameter_name));
            return false;
        }
    }

    return true;
}

parse_pattern_section :: (parser: *Parser, pattern_name: string, location: Source_Location, song_specification: *Song_Specification) -> bool {
    pattern: Pattern_Definition;
    pattern.name = pattern_name;
    pattern.location = location;

    while !parser.has_error && parser.current_token_index < parser.tokens.count {
        skip_newlines(parser);
        token := current_token(parser);

        if token.type == .OPEN_BRACKET || token.type == .END_OF_FILE {
            break;
        }

        if token.type != .IDENTIFIER {
            set_error(parser, token.location, sprint("Expected note name or instrument in pattern, got '%'", token.text));
            return false;
        }

        next_token_peek := peek_token(parser, 1);
        if next_token_peek.type == .PIPE {
            success := parse_step_sequencer_row(parser, *pattern);
            if !success return false;
        } else {
            success := parse_piano_roll_row(parser, *pattern);
            if !success return false;
        }
    }

    array_add(*song_specification.patterns, pattern);

    return true;
}

parse_step_sequencer_row :: (parser: *Parser, pattern: *Pattern_Definition) -> bool {
    instrument_token := current_token(parser);
    instrument_name := instrument_token.text;
    advance_token(parser);

    pipe_token, pipe_success := consume_token(parser, .PIPE, "Expected '|' to begin step grid");
    if !pipe_success return false;

    track: Step_Sequencer_Track;
    track.instrument_name = instrument_name;
    track.location = instrument_token.location;

    while !parser.has_error && parser.current_token_index < parser.tokens.count {
        step_token := current_token(parser);

        if step_token.type == .PIPE {
            advance_token(parser);
            break;
        }

        if step_token.type == .NEWLINE || step_token.type == .END_OF_FILE {
            set_error(parser, step_token.location, "Unterminated step sequencer row (missing closing '|')");
            return false;
        }

        if step_token.type == .STEP_HIT {
            array_add(*track.steps, true);
            array_add(*track.velocities, 1.0);
            advance_token(parser);
        } else if step_token.type == .DOT {
            array_add(*track.steps, false);
            array_add(*track.velocities, 0.0);
            advance_token(parser);
        } else if step_token.type == .INTEGER {
            velocity_value := cast(float) step_token.integer_value / 10.0;
            if velocity_value > 1.0 velocity_value = 1.0;
            array_add(*track.steps, true);
            array_add(*track.velocities, velocity_value);
            advance_token(parser);
        } else {
            set_error(parser, step_token.location, sprint("Invalid step character '%'", step_token.text));
            return false;
        }
    }

    if track.steps.count > pattern.step_count {
        pattern.step_count = track.steps.count;
    }

    array_add(*pattern.step_tracks, track);

    return true;
}

parse_piano_roll_row :: (parser: *Parser, pattern: *Pattern_Definition) -> bool {
    note_token := current_token(parser);
    note_name := note_token.text;
    advance_token(parser);

    midi_number := note_to_midi(note_name);
    if midi_number < 0 {
        set_error(parser, note_token.location, sprint("Invalid note name '%'", note_name));
        return false;
    }

    piano_roll_note: Piano_Roll_Note;
    piano_roll_note.midi_note_number = midi_number;
    piano_roll_note.location = note_token.location;

    while !parser.has_error && parser.current_token_index < parser.tokens.count {
        token := current_token(parser);

        if token.type == .NEWLINE || token.type == .OPEN_BRACKET || token.type == .END_OF_FILE {
            break;
        }

        if token.type != .IDENTIFIER {
            set_error(parser, token.location, sprint("Expected note parameter name, got '%'", token.text));
            return false;
        }

        parameter_name := token.text;
        advance_token(parser);

        equals_token, equals_success := consume_token(parser, .EQUALS, "Expected '=' after note parameter name");
        if !equals_success return false;

        if parameter_name == "step" || parameter_name == "start" {
            step_token, step_success := consume_token(parser, .INTEGER, "Expected integer for note start step");
            if !step_success return false;
            piano_roll_note.start_step = step_token.integer_value;
        } else if parameter_name == "len" || parameter_name == "length" {
            length_token, length_success := consume_token(parser, .INTEGER, "Expected integer for note step length");
            if !length_success return false;
            piano_roll_note.step_length = length_token.integer_value;
        } else if parameter_name == "vel" || parameter_name == "velocity" {
            velocity_value, velocity_success := parse_number(parser);
            if !velocity_success return false;
            piano_roll_note.velocity = cast(float) velocity_value;
        } else {
            set_error(parser, token.location, sprint("Unknown note parameter '%'", parameter_name));
            return false;
        }
    }

    array_add(*pattern.piano_roll_notes, piano_roll_note);

    return true;
}

parse_mixer_section :: (parser: *Parser, song_specification: *Song_Specification) -> bool {
    while !parser.has_error && parser.current_token_index < parser.tokens.count {
        skip_newlines(parser);
        token := current_token(parser);

        if token.type == .OPEN_BRACKET || token.type == .END_OF_FILE {
            break;
        }

        if token.type != .IDENTIFIER {
            set_error(parser, token.location, sprint("Expected 'track' or 'master' in mixer section, got '%'", token.text));
            return false;
        }

        if token.text == "track" {
            advance_token(parser);
            track_index_token, track_index_success := consume_token(parser, .INTEGER, "Expected track index number after 'track'");
            if !track_index_success return false;

            track: Mixer_Track_Definition;
            track.track_index = track_index_token.integer_value;
            track.location = token.location;

            if current_token(parser).type == .OPEN_PARENTHESIS {
                advance_token(parser);
                name_token := current_token(parser);
                if name_token.type == .IDENTIFIER || name_token.type == .STRING {
                    track.name = ifx name_token.type == .STRING then name_token.string_value else name_token.text;
                    advance_token(parser);
                }
                close_token, close_success := consume_token(parser, .CLOSE_PARENTHESIS, "Expected ')' after track name");
                if !close_success return false;
            }

            colon_token, colon_success := consume_token(parser, .COLON, "Expected ':' after track declaration");
            if !colon_success return false;

            success := parse_mixer_track_parameters(parser, *track);
            if !success return false;

            array_add(*song_specification.mixer.tracks, track);
        } else if token.text == "master" {
            song_specification.mixer.master.location = token.location;
            advance_token(parser);

            colon_token, colon_success := consume_token(parser, .COLON, "Expected ':' after 'master'");
            if !colon_success return false;

            success := parse_master_track_parameters(parser, *song_specification.mixer.master);
            if !success return false;
        } else {
            set_error(parser, token.location, sprint("Unknown mixer item '%', expected 'track' or 'master'", token.text));
            return false;
        }
    }

    return true;
}

parse_mixer_track_parameters :: (parser: *Parser, track: *Mixer_Track_Definition) -> bool {
    first_parameter := true;

    while !parser.has_error && parser.current_token_index < parser.tokens.count {
        token := current_token(parser);

        if token.type == .NEWLINE || token.type == .OPEN_BRACKET || token.type == .END_OF_FILE {
            break;
        }

        if !first_parameter {
            comma_token, comma_success := consume_token(parser, .COMMA, "Expected ',' between track parameters");
            if !comma_success return false;
        }

        first_parameter = false;
        parameter_token := current_token(parser);

        if parameter_token.type != .IDENTIFIER {
            set_error(parser, parameter_token.location, "Expected track parameter name");
            return false;
        }

        parameter_name := parameter_token.text;
        advance_token(parser);

        equals_token, equals_success := consume_token(parser, .EQUALS, "Expected '=' after track parameter name");
        if !equals_success return false;

        if parameter_name == "gain" || parameter_name == "volume" {
            gain_value, gain_success := parse_number(parser);
            if !gain_success return false;
            track.gain = cast(float) gain_value;
        } else if parameter_name == "pan" {
            pan_value, pan_success := parse_number(parser);
            if !pan_success return false;
            track.pan = cast(float) pan_value;
        } else if parameter_name == "delay" {
            delay_value, delay_success := parse_number(parser);
            if !delay_success return false;
            track.delay_time_seconds = cast(float) delay_value;
        } else if parameter_name == "feedback" {
            feedback_value, feedback_success := parse_number(parser);
            if !feedback_success return false;
            track.delay_feedback = cast(float) feedback_value;
        } else if parameter_name == "output" {
            output_token := current_token(parser);
            if output_token.type != .IDENTIFIER && output_token.type != .STRING {
                set_error(parser, output_token.location, "Expected output name for track routing");
                return false;
            }
            track.output_target = ifx output_token.type == .STRING then output_token.string_value else output_token.text;
            advance_token(parser);
        } else {
            set_error(parser, parameter_token.location, sprint("Unknown track parameter '%'", parameter_name));
            return false;
        }
    }

    return true;
}

parse_master_track_parameters :: (parser: *Parser, master_track: *Master_Track_Definition) -> bool {
    first_parameter := true;

    while !parser.has_error && parser.current_token_index < parser.tokens.count {
        token := current_token(parser);

        if token.type == .NEWLINE || token.type == .OPEN_BRACKET || token.type == .END_OF_FILE {
            break;
        }

        if !first_parameter {
            comma_token, comma_success := consume_token(parser, .COMMA, "Expected ',' between master parameters");
            if !comma_success return false;
        }

        first_parameter = false;
        parameter_token := current_token(parser);

        if parameter_token.type != .IDENTIFIER {
            set_error(parser, parameter_token.location, "Expected master parameter name");
            return false;
        }

        parameter_name := parameter_token.text;
        advance_token(parser);

        equals_token, equals_success := consume_token(parser, .EQUALS, "Expected '=' after master parameter name");
        if !equals_success return false;

        if parameter_name == "gain" || parameter_name == "volume" {
            gain_value, gain_success := parse_number(parser);
            if !gain_success return false;
            master_track.gain = cast(float) gain_value;
        } else if parameter_name == "limiter" {
            limiter_token := current_token(parser);
            if limiter_token.type != .IDENTIFIER {
                set_error(parser, limiter_token.location, "Expected 'on', 'off', 'true', or 'false' for limiter");
                return false;
            }

            if limiter_token.text == "on" || limiter_token.text == "true" {
                master_track.limiter_enabled = true;
            } else if limiter_token.text == "off" || limiter_token.text == "false" {
                master_track.limiter_enabled = false;
            } else {
                set_error(parser, limiter_token.location, sprint("Invalid limiter setting '%', expected 'on' or 'off'", limiter_token.text));
                return false;
            }
            advance_token(parser);
        } else if parameter_name == "ceiling" {
            ceiling_value, ceiling_success := parse_number(parser);
            if !ceiling_success return false;
            master_track.limiter_ceiling_decibels = cast(float) ceiling_value;

            unit_token := current_token(parser);
            if unit_token.type == .IDENTIFIER && (unit_token.text == "db" || unit_token.text == "decibels") {
                advance_token(parser);
            }
        } else {
            set_error(parser, parameter_token.location, sprint("Unknown master parameter '%'", parameter_name));
            return false;
        }
    }

    return true;
}

parse_channel_routing_section :: (parser: *Parser, song_specification: *Song_Specification) -> bool {
    while !parser.has_error && parser.current_token_index < parser.tokens.count {
        skip_newlines(parser);
        token := current_token(parser);

        if token.type == .OPEN_BRACKET || token.type == .END_OF_FILE {
            break;
        }

        if token.type != .IDENTIFIER {
            set_error(parser, token.location, sprint("Expected instrument name in [channel_routing], got '%'", token.text));
            return false;
        }

        instrument_name := token.text;
        routing_location := token.location;
        advance_token(parser);

        arrow_token, arrow_success := consume_token(parser, .ARROW, "Expected '->' after instrument name");
        if !arrow_success return false;

        track_keyword_token := current_token(parser);
        if track_keyword_token.type == .IDENTIFIER && track_keyword_token.text == "track" {
            advance_token(parser);
        }

        track_index_token, track_index_success := consume_token(parser, .INTEGER, "Expected track index number in routing");
        if !track_index_success return false;

        routing: Routing_Definition;
        routing.instrument_name = instrument_name;
        routing.track_index = track_index_token.integer_value;
        routing.location = routing_location;

        array_add(*song_specification.routings, routing);
    }

    return true;
}

parse_arrangement_section :: (parser: *Parser, song_specification: *Song_Specification) -> bool {
    while !parser.has_error && parser.current_token_index < parser.tokens.count {
        skip_newlines(parser);
        token := current_token(parser);

        if token.type == .OPEN_BRACKET || token.type == .END_OF_FILE {
            break;
        }

        if token.type != .IDENTIFIER || token.text != "bar" {
            set_error(parser, token.location, sprint("Expected 'bar' in [arrangement], got '%'", token.text));
            return false;
        }

        clip_location := token.location;
        advance_token(parser);

        start_bar_token, start_bar_success := consume_token(parser, .INTEGER, "Expected starting bar number");
        if !start_bar_success return false;

        start_bar := start_bar_token.integer_value;
        end_bar := start_bar;

        if current_token(parser).type == .MINUS {
            advance_token(parser);
            end_bar_token, end_bar_success := consume_token(parser, .INTEGER, "Expected ending bar number after '-'");
            if !end_bar_success return false;
            end_bar = end_bar_token.integer_value;
        }

        colon_token, colon_success := consume_token(parser, .COLON, "Expected ':' after bar range");
        if !colon_success return false;

        pattern_name_token := current_token(parser);
        if pattern_name_token.type != .IDENTIFIER {
            set_error(parser, pattern_name_token.location, "Expected pattern name in arrangement");
            return false;
        }

        pattern_name := pattern_name_token.text;
        advance_token(parser);

        clip: Arrangement_Clip;
        clip.pattern_name = pattern_name;
        clip.start_bar = start_bar;
        clip.end_bar = end_bar;
        clip.location = clip_location;

        array_add(*song_specification.arrangement.clips, clip);
    }

    return true;
}

validate_song_specification :: (parser: *Parser, song_specification: *Song_Specification) -> bool {
    clip_index := 0;
    while clip_index < song_specification.arrangement.clips.count {
        clip := *song_specification.arrangement.clips[clip_index];
        pattern, pattern_found := find_pattern(song_specification, clip.pattern_name);
        if !pattern_found {
            set_error(parser, clip.location, sprint("Arrangement references undefined pattern '%'", clip.pattern_name));
            return false;
        }

        clip_index += 1;
    }

    routing_index := 0;
    while routing_index < song_specification.routings.count {
        routing := *song_specification.routings[routing_index];
        instrument, instrument_found := find_instrument(song_specification, routing.instrument_name);
        if !instrument_found {
            set_error(parser, routing.location, sprint("Channel routing references undefined instrument '%'", routing.instrument_name));
            return false;
        }

        routing_index += 1;
    }

    pattern_index := 0;
    while pattern_index < song_specification.patterns.count {
        pattern := *song_specification.patterns[pattern_index];
        track_index := 0;
        while track_index < pattern.step_tracks.count {
            track := *pattern.step_tracks[track_index];
            instrument, instrument_found := find_instrument(song_specification, track.instrument_name);
            if !instrument_found {
                set_error(parser, track.location, sprint("Pattern '%' references undefined instrument '%'", pattern.name, track.instrument_name));
                return false;
            }

            track_index += 1;
        }

        pattern_index += 1;
    }

    if parser.check_samples_on_disk {
        instrument_index := 0;
        while instrument_index < song_specification.instruments.count {
            instrument := *song_specification.instruments[instrument_index];
            if instrument.type == .SAMPLER {
                if !file_exists_on_disk(instrument.sampler.sample_file_path) {
                    set_error(parser, instrument.location, sprint("Sample file '%' does not exist on disk", instrument.sampler.sample_file_path));
                    return false;
                }
            }


            instrument_index += 1;
        }
    }

    return true;
}

parse_number :: (parser: *Parser) -> float64, bool {
    is_negative := false;
    token := current_token(parser);

    if token.type == .MINUS {
        is_negative = true;
        advance_token(parser);
        token = current_token(parser);
    }

    if token.type != .INTEGER && token.type != .FLOAT {
        set_error(parser, token.location, sprint("Expected number, got '%'", token.text));
        return 0.0, false;
    }

    advance_token(parser);

    value := token.float_value;
    if is_negative {
        value = -value;
    }

    return value, true;
}

current_token :: (parser: *Parser) -> Token {
    if parser.current_token_index >= parser.tokens.count {
        empty_token: Token;
        empty_token.type = .END_OF_FILE;
        return empty_token;
    }

    return parser.tokens[parser.current_token_index];
}

peek_token :: (parser: *Parser, offset: s64 = 1) -> Token {
    target_index := parser.current_token_index + offset;
    if target_index >= parser.tokens.count || target_index < 0 {
        empty_token: Token;
        empty_token.type = .END_OF_FILE;
        return empty_token;
    }

    return parser.tokens[target_index];
}

advance_token :: (parser: *Parser) -> Token {
    if parser.current_token_index >= parser.tokens.count {
        empty_token: Token;
        empty_token.type = .END_OF_FILE;
        return empty_token;
    }

    token := parser.tokens[parser.current_token_index];
    parser.current_token_index += 1;

    return token;
}

consume_token :: (parser: *Parser, expected_type: Token_Type, error_description: string) -> Token, bool {
    token := current_token(parser);

    if token.type != expected_type {
        set_error(parser, token.location, sprint("% (got '%')", error_description, token.text));
        return token, false;
    }

    advance_token(parser);

    return token, true;
}

skip_newlines :: (parser: *Parser) {
    while parser.current_token_index < parser.tokens.count {
        token := parser.tokens[parser.current_token_index];
        if token.type == .NEWLINE {
            parser.current_token_index += 1;
        } else {
            break;
        }
    }
}

set_error :: (parser: *Parser, location: Source_Location, message: string) {
    parser.has_error = true;
    parser.error_message = sprint("(%, line %, column %): %", location.filename, location.line_number, location.column_number, message);
}

file_exists_on_disk :: (file_path: string) -> bool {
    file, success := file_open(file_path, for_writing = false, keep_existing_content = false, log_errors = false);
    if success {
        file_close(*file);

        return true;
    }

    return false;
}

Parser :: struct {
    filename: string;
    tokens: [] Token;
    current_token_index: s64 = 0;
    has_error: bool = false;
    error_message: string;
    check_samples_on_disk: bool = true;
}
