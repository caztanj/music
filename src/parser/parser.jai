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
        } else if parameter_name == "filter_envelope_amount" || parameter_name == "filter_env_amount" || parameter_name == "env_amount" {
            amount_value, amount_success := parse_number(parser);
            if !amount_success return false;
            synthesizer_configuration.filter.envelope_amount = cast(float) amount_value;
        } else if parameter_name == "filter_attack" || parameter_name == "filter_envelope_attack" {
            attack_value, attack_success := parse_number(parser);
            if !attack_success return false;
            synthesizer_configuration.filter.envelope.attack_milliseconds = cast(float) attack_value;
        } else if parameter_name == "filter_decay" || parameter_name == "filter_envelope_decay" {
            decay_value, decay_success := parse_number(parser);
            if !decay_success return false;
            synthesizer_configuration.filter.envelope.decay_milliseconds = cast(float) decay_value;
        } else if parameter_name == "filter_sustain" || parameter_name == "filter_envelope_sustain" {
            sustain_value, sustain_success := parse_number(parser);
            if !sustain_success return false;
            synthesizer_configuration.filter.envelope.sustain_level = cast(float) sustain_value;
        } else if parameter_name == "filter_release" || parameter_name == "filter_envelope_release" {
            release_value, release_success := parse_number(parser);
            if !release_success return false;
            synthesizer_configuration.filter.envelope.release_milliseconds = cast(float) release_value;
        } else if parameter_name == "wave2" || parameter_name == "waveform2" || parameter_name == "osc2_wave" || parameter_name == "osc2" {
            wave_token := current_token(parser);
            wave_name := ifx wave_token.type == .STRING then wave_token.string_value else wave_token.text;
            waveform_type, waveform_success := string_to_waveform_type(wave_name);
            if !waveform_success {
                set_error(parser, wave_token.location, sprint("Unknown secondary waveform '%'", wave_name));
                return false;
            }
            synthesizer_configuration.oscillator_2_waveform = waveform_type;
            synthesizer_configuration.oscillator_2_enabled = true;
            advance_token(parser);
        } else if parameter_name == "osc2_transpose" || parameter_name == "transpose2" || parameter_name == "coarse2" || parameter_name == "semitones2" {
            semitones_value, semitones_success := parse_number(parser);
            if !semitones_success return false;
            synthesizer_configuration.oscillator_2_semitones = cast(s32) semitones_value;
            synthesizer_configuration.oscillator_2_enabled = true;
        } else if parameter_name == "osc2_tune" || parameter_name == "tune2" || parameter_name == "cents2" || parameter_name == "detune2" {
            cents_value, cents_success := parse_number(parser);
            if !cents_success return false;
            synthesizer_configuration.oscillator_2_cents = cast(float) cents_value;
            synthesizer_configuration.oscillator_2_enabled = true;
        } else if parameter_name == "osc_mix" || parameter_name == "mix" {
            mix_value, mix_success := parse_number(parser);
            if !mix_success return false;
            synthesizer_configuration.oscillator_mix = cast(float) mix_value;
        } else if parameter_name == "noise_level" || parameter_name == "noise_gain" || parameter_name == "noise_mix" {
            noise_value, noise_success := parse_number(parser);
            if !noise_success return false;
            synthesizer_configuration.noise_level = cast(float) noise_value;
        } else if parameter_name == "noise_type" || parameter_name == "noise" {
            noise_token := current_token(parser);
            noise_name := ifx noise_token.type == .STRING then noise_token.string_value else noise_token.text;
            waveform_type, waveform_success := string_to_waveform_type(noise_name);
            if !waveform_success || (waveform_type != .WHITE_NOISE && waveform_type != .PINK_NOISE) {
                set_error(parser, noise_token.location, sprint("Unknown noise type '%', expected 'white' or 'pink'", noise_name));
                return false;
            }
            synthesizer_configuration.noise_type = waveform_type;
            if synthesizer_configuration.noise_level == 0.0 {
                synthesizer_configuration.noise_level = 0.5;
            }
            advance_token(parser);
        } else if parameter_name == "unison" || parameter_name == "unison_voices" {
            unison_value, unison_success := parse_number(parser);
            if !unison_success return false;
            unison_voice_count := cast(s32) unison_value;
            if unison_voice_count < 1 {
                unison_voice_count = 1;
            } else if unison_voice_count > 8 {
                unison_voice_count = 8;
            }
            synthesizer_configuration.unison_voices = unison_voice_count;
        } else if parameter_name == "detune" || parameter_name == "unison_detune" {
            detune_value, detune_success := parse_number(parser);
            if !detune_success return false;
            synthesizer_configuration.unison_detune = cast(float) detune_value;
        } else if parameter_name == "spread" || parameter_name == "unison_spread" {
            spread_value, spread_success := parse_number(parser);
            if !spread_success return false;
            synthesizer_configuration.unison_spread = cast(float) spread_value;
        } else if parameter_name == "gain" || parameter_name == "volume" {
            gain_value, gain_success := parse_number(parser);
            if !gain_success return false;
            synthesizer_configuration.gain = cast(float) gain_value;
        } else if parameter_name == "lfo1_waveform" || parameter_name == "lfo1_wave" || parameter_name == "lfo_waveform" || parameter_name == "lfo_wave" || parameter_name == "lfo2_waveform" || parameter_name == "lfo2_wave" {
            target_lfo := ifx (parameter_name == "lfo2_waveform" || parameter_name == "lfo2_wave") then *synthesizer_configuration.lfo_2 else *synthesizer_configuration.lfo_1;
            waveform_token := current_token(parser);
            waveform_name := ifx waveform_token.type == .STRING then waveform_token.string_value else waveform_token.text;
            lfo_waveform, waveform_success := string_to_lfo_waveform(waveform_name);
            if !waveform_success {
                set_error(parser, waveform_token.location, sprint("Unknown LFO waveform '%'", waveform_name));
                return false;
            }
            target_lfo.waveform = lfo_waveform;
            target_lfo.enabled = true;
            advance_token(parser);
        } else if parameter_name == "lfo1_destination" || parameter_name == "lfo1_dest" || parameter_name == "lfo1_target" || parameter_name == "lfo_destination" || parameter_name == "lfo_dest" || parameter_name == "lfo_target" || parameter_name == "lfo2_destination" || parameter_name == "lfo2_dest" || parameter_name == "lfo2_target" {
            target_lfo := ifx (parameter_name == "lfo2_destination" || parameter_name == "lfo2_dest" || parameter_name == "lfo2_target") then *synthesizer_configuration.lfo_2 else *synthesizer_configuration.lfo_1;
            destination_token := current_token(parser);
            destination_name := ifx destination_token.type == .STRING then destination_token.string_value else destination_token.text;
            lfo_destination, destination_success := string_to_lfo_destination(destination_name);
            if !destination_success {
                set_error(parser, destination_token.location, sprint("Unknown LFO destination '%'", destination_name));
                return false;
            }
            target_lfo.destination = lfo_destination;
            target_lfo.enabled = true;
            advance_token(parser);
        } else if parameter_name == "lfo1_rate" || parameter_name == "lfo1_speed" || parameter_name == "lfo_rate" || parameter_name == "lfo_speed" || parameter_name == "lfo2_rate" || parameter_name == "lfo2_speed" || parameter_name == "lfo1_sync" || parameter_name == "lfo_sync" || parameter_name == "lfo2_sync" {
            target_lfo := ifx (parameter_name == "lfo2_rate" || parameter_name == "lfo2_speed" || parameter_name == "lfo2_sync") then *synthesizer_configuration.lfo_2 else *synthesizer_configuration.lfo_1;
            rate_token := current_token(parser);
            if rate_token.type == .STRING {
                sync_success, numerator, denominator, is_triplet := parse_tempo_sync_string(rate_token.string_value);
                if sync_success {
                    target_lfo.is_tempo_synced = true;
                    target_lfo.tempo_sync_numerator = numerator;
                    target_lfo.tempo_sync_denominator = denominator;
                    target_lfo.is_triplet = is_triplet;
                    target_lfo.enabled = true;
                } else {
                    set_error(parser, rate_token.location, sprint("Invalid tempo sync format '%', expected e.g. '1/4' or '1/8t'", rate_token.string_value));
                    return false;
                }
                advance_token(parser);
            } else if rate_token.type == .INTEGER || rate_token.type == .FLOAT {
                rate_value, rate_success := parse_number(parser);
                if !rate_success return false;
                target_lfo.rate_hertz = cast(float) rate_value;
                target_lfo.is_tempo_synced = false;
                target_lfo.enabled = true;
            } else if rate_token.type == .IDENTIFIER {
                sync_success, numerator, denominator, is_triplet := parse_tempo_sync_string(rate_token.text);
                if sync_success {
                    target_lfo.is_tempo_synced = true;
                    target_lfo.tempo_sync_numerator = numerator;
                    target_lfo.tempo_sync_denominator = denominator;
                    target_lfo.is_triplet = is_triplet;
                    target_lfo.enabled = true;
                    advance_token(parser);
                } else {
                    set_error(parser, rate_token.location, sprint("Invalid tempo sync format '%'", rate_token.text));
                    return false;
                }
            } else {
                set_error(parser, rate_token.location, "Expected number or sync string for LFO rate");
                return false;
            }
        } else if parameter_name == "lfo1_amount" || parameter_name == "lfo1_depth" || parameter_name == "lfo_amount" || parameter_name == "lfo_depth" || parameter_name == "lfo2_amount" || parameter_name == "lfo2_depth" {
            target_lfo := ifx (parameter_name == "lfo2_amount" || parameter_name == "lfo2_depth") then *synthesizer_configuration.lfo_2 else *synthesizer_configuration.lfo_1;
            amount_value, amount_success := parse_number(parser);
            if !amount_success return false;
            target_lfo.amount = cast(float) amount_value;
            target_lfo.enabled = true;
        } else if parameter_name == "lfo1_retrigger" || parameter_name == "lfo_retrigger" || parameter_name == "lfo2_retrigger" {
            target_lfo := ifx parameter_name == "lfo2_retrigger" then *synthesizer_configuration.lfo_2 else *synthesizer_configuration.lfo_1;
            retrigger_token := current_token(parser);
            retrigger_text := ifx retrigger_token.type == .STRING then retrigger_token.string_value else retrigger_token.text;
            if retrigger_text == "on" || retrigger_text == "true" {
                target_lfo.retrigger = true;
            } else if retrigger_text == "off" || retrigger_text == "false" {
                target_lfo.retrigger = false;
            }
            advance_token(parser);
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
        } else if parameter_name == "reverb" || parameter_name == "reverb_mix" || parameter_name == "reverb_wet" {
            reverb_value, reverb_success := parse_number(parser);
            if !reverb_success return false;
            track.reverb_mix = cast(float) reverb_value;
            track.reverb_enabled = true;
        } else if parameter_name == "reverb_room" || parameter_name == "reverb_room_size" || parameter_name == "reverb_size" {
            room_value, room_success := parse_number(parser);
            if !room_success return false;
            track.reverb_room_size = cast(float) room_value;
            track.reverb_enabled = true;
        } else if parameter_name == "reverb_damp" || parameter_name == "reverb_damping" {
            damping_value, damping_success := parse_number(parser);
            if !damping_success return false;
            track.reverb_damping = cast(float) damping_value;
            track.reverb_enabled = true;
        } else if parameter_name == "reverb_predelay" || parameter_name == "reverb_delay" {
            predelay_value, predelay_success := parse_number(parser);
            if !predelay_success return false;
            track.reverb_predelay_milliseconds = cast(float) predelay_value;
            track.reverb_enabled = true;
        } else if parameter_name == "eq_low" || parameter_name == "eq_low_gain" || parameter_name == "low_gain" {
            gain_value, gain_success := parse_number(parser);
            if !gain_success return false;
            track.equalizer_low_gain_decibels = cast(float) gain_value;
            track.equalizer_enabled = true;
        } else if parameter_name == "eq_low_freq" || parameter_name == "eq_low_frequency" || parameter_name == "low_freq" {
            frequency_value, frequency_success := parse_number(parser);
            if !frequency_success return false;
            track.equalizer_low_frequency_hertz = cast(float) frequency_value;
            track.equalizer_enabled = true;
        } else if parameter_name == "eq_mid" || parameter_name == "eq_mid_gain" || parameter_name == "mid_gain" {
            gain_value, gain_success := parse_number(parser);
            if !gain_success return false;
            track.equalizer_mid_gain_decibels = cast(float) gain_value;
            track.equalizer_enabled = true;
        } else if parameter_name == "eq_mid_freq" || parameter_name == "eq_mid_frequency" || parameter_name == "mid_freq" {
            frequency_value, frequency_success := parse_number(parser);
            if !frequency_success return false;
            track.equalizer_mid_frequency_hertz = cast(float) frequency_value;
            track.equalizer_enabled = true;
        } else if parameter_name == "eq_mid_q" || parameter_name == "mid_q" || parameter_name == "eq_q" {
            quality_factor_value, quality_factor_success := parse_number(parser);
            if !quality_factor_success return false;
            track.equalizer_mid_quality_factor = cast(float) quality_factor_value;
            track.equalizer_enabled = true;
        } else if parameter_name == "eq_high" || parameter_name == "eq_high_gain" || parameter_name == "high_gain" {
            gain_value, gain_success := parse_number(parser);
            if !gain_success return false;
            track.equalizer_high_gain_decibels = cast(float) gain_value;
            track.equalizer_enabled = true;
        } else if parameter_name == "eq_high_freq" || parameter_name == "eq_high_frequency" || parameter_name == "high_freq" {
            frequency_value, frequency_success := parse_number(parser);
            if !frequency_success return false;
            track.equalizer_high_frequency_hertz = cast(float) frequency_value;
            track.equalizer_enabled = true;
        } else if parameter_name == "chorus" || parameter_name == "chorus_mix" || parameter_name == "flanger" || parameter_name == "flanger_mix" {
            mix_value, mix_success := parse_number(parser);
            if !mix_success return false;
            track.chorus_mix = cast(float) mix_value;
            track.chorus_enabled = true;
        } else if parameter_name == "chorus_rate" || parameter_name == "chorus_speed" || parameter_name == "flanger_rate" || parameter_name == "flanger_speed" {
            rate_value, rate_success := parse_number(parser);
            if !rate_success return false;
            track.chorus_rate_hertz = cast(float) rate_value;
            track.chorus_enabled = true;
        } else if parameter_name == "chorus_depth" || parameter_name == "flanger_depth" {
            depth_value, depth_success := parse_number(parser);
            if !depth_success return false;
            track.chorus_depth_milliseconds = cast(float) depth_value;
            track.chorus_enabled = true;
        } else if parameter_name == "chorus_delay" || parameter_name == "chorus_time" || parameter_name == "flanger_delay" || parameter_name == "flanger_time" {
            delay_value, delay_success := parse_number(parser);
            if !delay_success return false;
            track.chorus_center_delay_milliseconds = cast(float) delay_value;
            track.chorus_enabled = true;
        } else if parameter_name == "chorus_feedback" || parameter_name == "flanger_feedback" {
            feedback_value, feedback_success := parse_number(parser);
            if !feedback_success return false;
            track.chorus_feedback = cast(float) feedback_value;
            track.chorus_enabled = true;
        } else if parameter_name == "chorus_phase" || parameter_name == "chorus_stereo_phase" || parameter_name == "flanger_phase" {
            phase_value, phase_success := parse_number(parser);
            if !phase_success return false;
            track.chorus_stereo_phase_degrees = cast(float) phase_value;
            track.chorus_enabled = true;
        } else if parameter_name == "saturation_type" || parameter_name == "saturation_mode" {
            type_token := current_token(parser);
            if type_token.type != .IDENTIFIER && type_token.type != .STRING {
                set_error(parser, type_token.location, "Expected saturation type name");
                return false;
            }
            type_text := ifx type_token.type == .STRING then type_token.string_value else type_token.text;
            saturation_type, saturation_type_found := string_to_saturation_type(type_text);
            if !saturation_type_found {
                set_error(parser, type_token.location, sprint("Unknown saturation type '%'", type_text));
                return false;
            }
            track.saturation_type = saturation_type;
            track.saturation_enabled = saturation_type != .NONE;
            advance_token(parser);
        } else if parameter_name == "saturation" || parameter_name == "drive" || parameter_name == "saturation_drive" {
            type_token := current_token(parser);
            if type_token.type == .IDENTIFIER || type_token.type == .STRING {
                type_text := ifx type_token.type == .STRING then type_token.string_value else type_token.text;
                saturation_type, saturation_type_found := string_to_saturation_type(type_text);
                if saturation_type_found {
                    track.saturation_type = saturation_type;
                    track.saturation_enabled = saturation_type != .NONE;
                    advance_token(parser);
                } else if type_text == "on" || type_text == "true" {
                    track.saturation_enabled = true;
                    advance_token(parser);
                } else if type_text == "off" || type_text == "false" {
                    track.saturation_enabled = false;
                    advance_token(parser);
                } else {
                    set_error(parser, type_token.location, sprint("Unknown saturation parameter value '%'", type_text));
                    return false;
                }
            } else {
                drive_value, drive_success := parse_number(parser);
                if !drive_success return false;
                track.saturation_drive = cast(float) drive_value;
                track.saturation_enabled = true;
            }
        } else if parameter_name == "saturation_mix" || parameter_name == "saturation_wet" {
            mix_value, mix_success := parse_number(parser);
            if !mix_success return false;
            track.saturation_mix = cast(float) mix_value;
            track.saturation_enabled = true;
        } else if parameter_name == "saturation_gain" || parameter_name == "saturation_output" || parameter_name == "saturation_out" {
            gain_value, gain_success := parse_number(parser);
            if !gain_success return false;
            track.saturation_output_gain = cast(float) gain_value;
            track.saturation_enabled = true;
        } else if parameter_name == "compressor" || parameter_name == "comp" {
            type_token := current_token(parser);
            if type_token.type == .IDENTIFIER {
                if type_token.text == "on" || type_token.text == "true" {
                    track.compressor_enabled = true;
                    advance_token(parser);
                } else if type_token.text == "off" || type_token.text == "false" {
                    track.compressor_enabled = false;
                    advance_token(parser);
                } else {
                    set_error(parser, type_token.location, sprint("Expected 'on', 'off', 'true', or 'false' for compressor, got '%'", type_token.text));
                    return false;
                }
            } else {
                threshold_value, threshold_success := parse_number(parser);
                if !threshold_success return false;
                track.compressor_threshold_decibels = cast(float) threshold_value;
                track.compressor_enabled = true;
            }
        } else if parameter_name == "comp_threshold" || parameter_name == "compressor_threshold" || parameter_name == "threshold" || parameter_name == "sidechain_threshold" || parameter_name == "ducking_threshold" {
            threshold_value, threshold_success := parse_number(parser);
            if !threshold_success return false;
            track.compressor_threshold_decibels = cast(float) threshold_value;
            track.compressor_threshold_set = true;
            track.compressor_enabled = true;
        } else if parameter_name == "comp_ratio" || parameter_name == "compressor_ratio" || parameter_name == "ratio" || parameter_name == "sidechain_ratio" || parameter_name == "ducking_ratio" {
            ratio_value, ratio_success := parse_number(parser);
            if !ratio_success return false;
            track.compressor_ratio = cast(float) ratio_value;
            track.compressor_ratio_set = true;
            track.compressor_enabled = true;
        } else if parameter_name == "comp_attack" || parameter_name == "compressor_attack" || parameter_name == "attack" || parameter_name == "sidechain_attack" || parameter_name == "ducking_attack" || parameter_name == "duck_attack" {
            attack_value, attack_success := parse_number(parser);
            if !attack_success return false;
            track.compressor_attack_milliseconds = cast(float) attack_value;
            track.compressor_attack_set = true;
            track.compressor_enabled = true;
        } else if parameter_name == "comp_release" || parameter_name == "compressor_release" || parameter_name == "release" || parameter_name == "sidechain_release" || parameter_name == "ducking_release" || parameter_name == "duck_release" {
            release_value, release_success := parse_number(parser);
            if !release_success return false;
            track.compressor_release_milliseconds = cast(float) release_value;
            track.compressor_enabled = true;
        } else if parameter_name == "comp_knee" || parameter_name == "compressor_knee" || parameter_name == "knee" || parameter_name == "sidechain_knee" || parameter_name == "ducking_knee" {
            knee_value, knee_success := parse_number(parser);
            if !knee_success return false;
            track.compressor_knee_decibels = cast(float) knee_value;
            track.compressor_enabled = true;
        } else if parameter_name == "comp_gain" || parameter_name == "comp_makeup" || parameter_name == "compressor_gain" || parameter_name == "compressor_makeup" || parameter_name == "makeup_gain" {
            gain_value, gain_success := parse_number(parser);
            if !gain_success return false;
            track.compressor_makeup_gain_decibels = cast(float) gain_value;
            track.compressor_enabled = true;
        } else if parameter_name == "comp_mix" || parameter_name == "compressor_mix" {
            mix_value, mix_success := parse_number(parser);
            if !mix_success return false;
            track.compressor_mix = cast(float) mix_value;
            track.compressor_enabled = true;
        } else if parameter_name == "sidechain" || parameter_name == "sidechain_source" || parameter_name == "sidechain_track" || parameter_name == "duck_from" {
            source_token := current_token(parser);
            if source_token.type == .INTEGER {
                track.sidechain_source_track_index = source_token.integer_value;
                track.compressor_enabled = true;
                advance_token(parser);
            } else if source_token.type == .IDENTIFIER || source_token.type == .STRING {
                source_text := ifx source_token.type == .STRING then source_token.string_value else source_token.text;
                if source_text == "none" || source_text == "off" {
                    track.sidechain_source_track_index = 0;
                    track.sidechain_source_name = "";
                    advance_token(parser);
                } else if source_text == "track" {
                    advance_token(parser);
                    track_index_token, track_index_success := consume_token(parser, .INTEGER, "Expected track index number after 'track'");
                    if !track_index_success return false;
                    track.sidechain_source_track_index = track_index_token.integer_value;
                    track.compressor_enabled = true;
                } else {
                    track.sidechain_source_name = source_text;
                    track.compressor_enabled = true;
                    advance_token(parser);
                }
            } else {
                set_error(parser, source_token.location, "Expected track number or name for sidechain");
                return false;
            }
        } else if parameter_name == "ducking_depth" || parameter_name == "sidechain_depth" || parameter_name == "duck_depth" {
            depth_value, depth_success := parse_number(parser);
            if !depth_success return false;
            track.sidechain_depth_decibels = cast(float) abs(depth_value);
            track.compressor_enabled = true;
            if !track.compressor_threshold_set {
                track.compressor_threshold_decibels = -24.0;
            }
            if !track.compressor_ratio_set {
                track.compressor_ratio = 20.0;
            }
            if !track.compressor_attack_set {
                track.compressor_attack_milliseconds = 2.0;
            }

            unit_token := current_token(parser);
            if unit_token.type == .IDENTIFIER && (unit_token.text == "db" || unit_token.text == "decibels") {
                advance_token(parser);
            }
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
        } else if parameter_name == "reverb" || parameter_name == "reverb_mix" || parameter_name == "reverb_wet" {
            reverb_value, reverb_success := parse_number(parser);
            if !reverb_success return false;
            master_track.reverb_mix = cast(float) reverb_value;
            master_track.reverb_enabled = true;
        } else if parameter_name == "reverb_room" || parameter_name == "reverb_room_size" || parameter_name == "reverb_size" {
            room_value, room_success := parse_number(parser);
            if !room_success return false;
            master_track.reverb_room_size = cast(float) room_value;
            master_track.reverb_enabled = true;
        } else if parameter_name == "reverb_damp" || parameter_name == "reverb_damping" {
            damping_value, damping_success := parse_number(parser);
            if !damping_success return false;
            master_track.reverb_damping = cast(float) damping_value;
            master_track.reverb_enabled = true;
        } else if parameter_name == "reverb_predelay" || parameter_name == "reverb_delay" {
            predelay_value, predelay_success := parse_number(parser);
            if !predelay_success return false;
            master_track.reverb_predelay_milliseconds = cast(float) predelay_value;
            master_track.reverb_enabled = true;
        } else if parameter_name == "eq_low" || parameter_name == "eq_low_gain" || parameter_name == "low_gain" {
            gain_value, gain_success := parse_number(parser);
            if !gain_success return false;
            master_track.equalizer_low_gain_decibels = cast(float) gain_value;
            master_track.equalizer_enabled = true;
        } else if parameter_name == "eq_low_freq" || parameter_name == "eq_low_frequency" || parameter_name == "low_freq" {
            frequency_value, frequency_success := parse_number(parser);
            if !frequency_success return false;
            master_track.equalizer_low_frequency_hertz = cast(float) frequency_value;
            master_track.equalizer_enabled = true;
        } else if parameter_name == "eq_mid" || parameter_name == "eq_mid_gain" || parameter_name == "mid_gain" {
            gain_value, gain_success := parse_number(parser);
            if !gain_success return false;
            master_track.equalizer_mid_gain_decibels = cast(float) gain_value;
            master_track.equalizer_enabled = true;
        } else if parameter_name == "eq_mid_freq" || parameter_name == "eq_mid_frequency" || parameter_name == "mid_freq" {
            frequency_value, frequency_success := parse_number(parser);
            if !frequency_success return false;
            master_track.equalizer_mid_frequency_hertz = cast(float) frequency_value;
            master_track.equalizer_enabled = true;
        } else if parameter_name == "eq_mid_q" || parameter_name == "mid_q" || parameter_name == "eq_q" {
            quality_factor_value, quality_factor_success := parse_number(parser);
            if !quality_factor_success return false;
            master_track.equalizer_mid_quality_factor = cast(float) quality_factor_value;
            master_track.equalizer_enabled = true;
        } else if parameter_name == "eq_high" || parameter_name == "eq_high_gain" || parameter_name == "high_gain" {
            gain_value, gain_success := parse_number(parser);
            if !gain_success return false;
            master_track.equalizer_high_gain_decibels = cast(float) gain_value;
            master_track.equalizer_enabled = true;
        } else if parameter_name == "eq_high_freq" || parameter_name == "eq_high_frequency" || parameter_name == "high_freq" {
            frequency_value, frequency_success := parse_number(parser);
            if !frequency_success return false;
            master_track.equalizer_high_frequency_hertz = cast(float) frequency_value;
            master_track.equalizer_enabled = true;
        } else if parameter_name == "chorus" || parameter_name == "chorus_mix" || parameter_name == "flanger" || parameter_name == "flanger_mix" {
            mix_value, mix_success := parse_number(parser);
            if !mix_success return false;
            master_track.chorus_mix = cast(float) mix_value;
            master_track.chorus_enabled = true;
        } else if parameter_name == "chorus_rate" || parameter_name == "chorus_speed" || parameter_name == "flanger_rate" || parameter_name == "flanger_speed" {
            rate_value, rate_success := parse_number(parser);
            if !rate_success return false;
            master_track.chorus_rate_hertz = cast(float) rate_value;
            master_track.chorus_enabled = true;
        } else if parameter_name == "chorus_depth" || parameter_name == "flanger_depth" {
            depth_value, depth_success := parse_number(parser);
            if !depth_success return false;
            master_track.chorus_depth_milliseconds = cast(float) depth_value;
            master_track.chorus_enabled = true;
        } else if parameter_name == "chorus_delay" || parameter_name == "chorus_time" || parameter_name == "flanger_delay" || parameter_name == "flanger_time" {
            delay_value, delay_success := parse_number(parser);
            if !delay_success return false;
            master_track.chorus_center_delay_milliseconds = cast(float) delay_value;
            master_track.chorus_enabled = true;
        } else if parameter_name == "chorus_feedback" || parameter_name == "flanger_feedback" {
            feedback_value, feedback_success := parse_number(parser);
            if !feedback_success return false;
            master_track.chorus_feedback = cast(float) feedback_value;
            master_track.chorus_enabled = true;
        } else if parameter_name == "chorus_phase" || parameter_name == "chorus_stereo_phase" || parameter_name == "flanger_phase" {
            phase_value, phase_success := parse_number(parser);
            if !phase_success return false;
            master_track.chorus_stereo_phase_degrees = cast(float) phase_value;
            master_track.chorus_enabled = true;
        } else if parameter_name == "saturation_type" || parameter_name == "saturation_mode" {
            type_token := current_token(parser);
            if type_token.type != .IDENTIFIER && type_token.type != .STRING {
                set_error(parser, type_token.location, "Expected saturation type name");
                return false;
            }
            type_text := ifx type_token.type == .STRING then type_token.string_value else type_token.text;
            saturation_type, saturation_type_found := string_to_saturation_type(type_text);
            if !saturation_type_found {
                set_error(parser, type_token.location, sprint("Unknown saturation type '%'", type_text));
                return false;
            }
            master_track.saturation_type = saturation_type;
            master_track.saturation_enabled = saturation_type != .NONE;
            advance_token(parser);
        } else if parameter_name == "saturation" || parameter_name == "drive" || parameter_name == "saturation_drive" {
            type_token := current_token(parser);
            if type_token.type == .IDENTIFIER || type_token.type == .STRING {
                type_text := ifx type_token.type == .STRING then type_token.string_value else type_token.text;
                saturation_type, saturation_type_found := string_to_saturation_type(type_text);
                if saturation_type_found {
                    master_track.saturation_type = saturation_type;
                    master_track.saturation_enabled = saturation_type != .NONE;
                    advance_token(parser);
                } else if type_text == "on" || type_text == "true" {
                    master_track.saturation_enabled = true;
                    advance_token(parser);
                } else if type_text == "off" || type_text == "false" {
                    master_track.saturation_enabled = false;
                    advance_token(parser);
                } else {
                    set_error(parser, type_token.location, sprint("Unknown saturation parameter value '%'", type_text));
                    return false;
                }
            } else {
                drive_value, drive_success := parse_number(parser);
                if !drive_success return false;
                master_track.saturation_drive = cast(float) drive_value;
                master_track.saturation_enabled = true;
            }
        } else if parameter_name == "saturation_mix" || parameter_name == "saturation_wet" {
            mix_value, mix_success := parse_number(parser);
            if !mix_success return false;
            master_track.saturation_mix = cast(float) mix_value;
            master_track.saturation_enabled = true;
        } else if parameter_name == "saturation_gain" || parameter_name == "saturation_output" || parameter_name == "saturation_out" {
            gain_value, gain_success := parse_number(parser);
            if !gain_success return false;
            master_track.saturation_output_gain = cast(float) gain_value;
            master_track.saturation_enabled = true;
        } else if parameter_name == "compressor" || parameter_name == "comp" {
            type_token := current_token(parser);
            if type_token.type == .IDENTIFIER {
                if type_token.text == "on" || type_token.text == "true" {
                    master_track.compressor_enabled = true;
                    advance_token(parser);
                } else if type_token.text == "off" || type_token.text == "false" {
                    master_track.compressor_enabled = false;
                    advance_token(parser);
                } else {
                    set_error(parser, type_token.location, sprint("Expected 'on', 'off', 'true', or 'false' for compressor, got '%'", type_token.text));
                    return false;
                }
            } else {
                threshold_value, threshold_success := parse_number(parser);
                if !threshold_success return false;
                master_track.compressor_threshold_decibels = cast(float) threshold_value;
                master_track.compressor_enabled = true;
            }
        } else if parameter_name == "comp_threshold" || parameter_name == "compressor_threshold" || parameter_name == "threshold" {
            threshold_value, threshold_success := parse_number(parser);
            if !threshold_success return false;
            master_track.compressor_threshold_decibels = cast(float) threshold_value;
            master_track.compressor_enabled = true;
        } else if parameter_name == "comp_ratio" || parameter_name == "compressor_ratio" || parameter_name == "ratio" {
            ratio_value, ratio_success := parse_number(parser);
            if !ratio_success return false;
            master_track.compressor_ratio = cast(float) ratio_value;
            master_track.compressor_enabled = true;
        } else if parameter_name == "comp_attack" || parameter_name == "compressor_attack" || parameter_name == "attack" {
            attack_value, attack_success := parse_number(parser);
            if !attack_success return false;
            master_track.compressor_attack_milliseconds = cast(float) attack_value;
            master_track.compressor_enabled = true;
        } else if parameter_name == "comp_release" || parameter_name == "compressor_release" || parameter_name == "release" {
            release_value, release_success := parse_number(parser);
            if !release_success return false;
            master_track.compressor_release_milliseconds = cast(float) release_value;
            master_track.compressor_enabled = true;
        } else if parameter_name == "comp_knee" || parameter_name == "compressor_knee" || parameter_name == "knee" {
            knee_value, knee_success := parse_number(parser);
            if !knee_success return false;
            master_track.compressor_knee_decibels = cast(float) knee_value;
            master_track.compressor_enabled = true;
        } else if parameter_name == "comp_gain" || parameter_name == "comp_makeup" || parameter_name == "compressor_gain" || parameter_name == "compressor_makeup" || parameter_name == "makeup_gain" {
            gain_value, gain_success := parse_number(parser);
            if !gain_success return false;
            master_track.compressor_makeup_gain_decibels = cast(float) gain_value;
            master_track.compressor_enabled = true;
        } else if parameter_name == "comp_mix" || parameter_name == "compressor_mix" {
            mix_value, mix_success := parse_number(parser);
            if !mix_success return false;
            master_track.compressor_mix = cast(float) mix_value;
            master_track.compressor_enabled = true;
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

    mixer_track_index := 0;
    while mixer_track_index < song_specification.mixer.tracks.count {
        track := *song_specification.mixer.tracks[mixer_track_index];
        if track.sidechain_source_name.count > 0 && track.sidechain_source_track_index == 0 {
            resolved := false;
            other_index := 0;
            while other_index < song_specification.mixer.tracks.count {
                other_track := *song_specification.mixer.tracks[other_index];
                if other_track.name == track.sidechain_source_name {
                    track.sidechain_source_track_index = other_track.track_index;
                    resolved = true;
                    break;
                }

                other_index += 1;
            }

            if !resolved {
                routing_search_index := 0;
                while routing_search_index < song_specification.routings.count {
                    routing := *song_specification.routings[routing_search_index];
                    if routing.instrument_name == track.sidechain_source_name {
                        track.sidechain_source_track_index = routing.track_index;
                        resolved = true;
                        break;
                    }

                    routing_search_index += 1;
                }
            }

            if !resolved {
                set_error(parser, track.location, sprint("Sidechain source '%' not found in mixer tracks or routings", track.sidechain_source_name));
                return false;
            }
        }

        if track.sidechain_source_track_index > 0 {
            if track.sidechain_source_track_index < 1 || track.sidechain_source_track_index > 16 {
                set_error(parser, track.location, sprint("Invalid sidechain track index %", track.sidechain_source_track_index));
                return false;
            }
        }

        mixer_track_index += 1;
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

parse_tempo_sync_string :: (sync_string: string) -> bool, s32, s32, bool {
    if sync_string.count == 0 {
        return false, 1, 4, false;
    }

    is_triplet := false;
    string_to_parse := sync_string;

    last_character := string_to_parse[string_to_parse.count - 1];
    if last_character == #char "t" || last_character == #char "T" {
        is_triplet = true;
        string_to_parse.count -= 1;
    }

    slash_index := -1;
    cursor := 0;
    while cursor < string_to_parse.count {
        if string_to_parse[cursor] == #char "/" {
            slash_index = cursor;
            break;
        }

        cursor += 1;
    }

    if slash_index < 0 {
        return false, 1, 4, false;
    }

    numerator_string: string;
    numerator_string.data = string_to_parse.data;
    numerator_string.count = slash_index;

    denominator_string: string;
    denominator_string.data = string_to_parse.data + slash_index + 1;
    denominator_string.count = string_to_parse.count - slash_index - 1;

    numerator, numerator_success := string_to_int(numerator_string);
    denominator, denominator_success := string_to_int(denominator_string);

    if !numerator_success || !denominator_success || denominator <= 0 || numerator <= 0 {
        return false, 1, 4, false;
    }

    return true, cast(s32) numerator, cast(s32) denominator, is_triplet;
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
