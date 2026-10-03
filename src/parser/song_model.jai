find_instrument :: (song_specification: *Song_Specification, name: string) -> *Instrument_Definition, bool {
    instrument_index := 0;
    while instrument_index < song_specification.instruments.count {
        instrument := *song_specification.instruments[instrument_index];
        if instrument.name == name {
            return instrument, true;
        }

        instrument_index += 1;
    }

    return null, false;
}

find_pattern :: (song_specification: *Song_Specification, name: string) -> *Pattern_Definition, bool {
    pattern_index := 0;
    while pattern_index < song_specification.patterns.count {
        pattern := *song_specification.patterns[pattern_index];
        if pattern.name == name {
            return pattern, true;
        }

        pattern_index += 1;
    }

    return null, false;
}

find_mixer_track :: (song_specification: *Song_Specification, track_index: s64) -> *Mixer_Track_Definition, bool {
    mixer_track_index := 0;
    while mixer_track_index < song_specification.mixer.tracks.count {
        track := *song_specification.mixer.tracks[mixer_track_index];
        if track.track_index == track_index {
            return track, true;
        }

        mixer_track_index += 1;
    }

    return null, false;
}

find_routing_for_instrument :: (song_specification: *Song_Specification, instrument_name: string) -> *Routing_Definition, bool {
    routing_index := 0;
    while routing_index < song_specification.routings.count {
        routing := *song_specification.routings[routing_index];
        if routing.instrument_name == instrument_name {
            return routing, true;
        }

        routing_index += 1;
    }

    return null, false;
}

calculate_total_steps :: (song_specification: *Song_Specification) -> s64 {
    total_steps := song_specification.project.total_bars * STEPS_PER_BAR;

    return total_steps;
}

calculate_song_duration_seconds :: (song_specification: *Song_Specification) -> float64 {
    if song_specification.project.beats_per_minute <= 0.0 {
        return 0.0;
    }

    seconds_per_beat := 60.0 / cast(float64) song_specification.project.beats_per_minute;
    total_beats := cast(float64) (song_specification.project.total_bars * song_specification.project.time_signature_numerator);
    total_seconds := total_beats * seconds_per_beat;

    return total_seconds;
}

string_to_waveform_type :: (name: string) -> Waveform_Type, bool {
    if name == "saw" || name == "sawtooth" {
        return .SAWTOOTH, true;
    }

    if name == "square" || name == "pulse" {
        return .SQUARE, true;
    }

    if name == "sine" {
        return .SINE, true;
    }

    if name == "triangle" {
        return .TRIANGLE, true;
    }

    return .SAWTOOTH, false;
}

string_to_filter_type :: (name: string) -> Filter_Type, bool {
    if name == "lowpass" || name == "lp" {
        return .LOWPASS, true;
    }

    if name == "highpass" || name == "hp" {
        return .HIGHPASS, true;
    }

    if name == "bandpass" || name == "bp" {
        return .BANDPASS, true;
    }

    return .NONE, false;
}

waveform_type_to_string :: (waveform_type: Waveform_Type) -> string {
    if waveform_type == {
        case .SAWTOOTH;
            return "sawtooth";

        case .SQUARE;
            return "square";

        case .SINE;
            return "sine";

        case .TRIANGLE;
            return "triangle";

        case;
            return "unknown";
    }
}

filter_type_to_string :: (filter_type: Filter_Type) -> string {
    if filter_type == {
        case .LOWPASS;
            return "lowpass";

        case .HIGHPASS;
            return "highpass";

        case .BANDPASS;
            return "bandpass";

        case .NONE;
            return "none";

        case;
            return "unknown";
    }
}

Waveform_Type :: enum {
    SAWTOOTH;
    SQUARE;
    SINE;
    TRIANGLE;
}

Filter_Type :: enum {
    NONE;
    LOWPASS;
    HIGHPASS;
    BANDPASS;
}

Instrument_Type :: enum {
    SAMPLER;
    SYNTHESIZER;
}

Project_Configuration :: struct {
    name: string = "Untitled";
    beats_per_minute: float = 120.0;
    time_signature_numerator: s64 = 4;
    time_signature_denominator: s64 = 4;
    total_bars: s64 = 16;
    location: Source_Location;
}

Filter_Configuration :: struct {
    type: Filter_Type = .NONE;
    cutoff_frequency_hertz: float = 20000.0;
    resonance: float = 0.0;
}

Envelope_Configuration :: struct {
    attack_milliseconds: float = 10.0;
    decay_milliseconds: float = 100.0;
    sustain_level: float = 0.7;
    release_milliseconds: float = 100.0;
}

Sampler_Configuration :: struct {
    sample_file_path: string;
    gain: float = 1.0;
    root_midi_note: s32 = 60;
}

Synthesizer_Configuration :: struct {
    waveform: Waveform_Type = .SAWTOOTH;
    filter: Filter_Configuration;
    envelope: Envelope_Configuration;
    gain: float = 1.0;
}

Instrument_Definition :: struct {
    name: string;
    type: Instrument_Type = .SYNTHESIZER;
    sampler: Sampler_Configuration;
    synthesizer: Synthesizer_Configuration;
    location: Source_Location;
}

Piano_Roll_Note :: struct {
    midi_note_number: s32 = 60;
    start_step: s64 = 0;
    step_length: s64 = 1;
    velocity: float = 1.0;
    location: Source_Location;
}

Step_Sequencer_Track :: struct {
    instrument_name: string;
    steps: [..] bool;
    velocities: [..] float;
    location: Source_Location;
}

Pattern_Definition :: struct {
    name: string;
    step_tracks: [..] Step_Sequencer_Track;
    piano_roll_notes: [..] Piano_Roll_Note;
    step_count: s64 = STEPS_PER_BAR;
    location: Source_Location;
}

Mixer_Track_Definition :: struct {
    track_index: s64 = 1;
    name: string;
    gain: float = 1.0;
    pan: float = 0.0;
    delay_time_seconds: float = 0.0;
    delay_feedback: float = 0.0;
    output_target: string = "master";
    location: Source_Location;
}

Master_Track_Definition :: struct {
    gain: float = 1.0;
    limiter_enabled: bool = true;
    limiter_ceiling_decibels: float = -0.1;
    location: Source_Location;
}

Mixer_Definition :: struct {
    tracks: [..] Mixer_Track_Definition;
    master: Master_Track_Definition;
    location: Source_Location;
}

Routing_Definition :: struct {
    instrument_name: string;
    track_index: s64 = 1;
    location: Source_Location;
}

Arrangement_Clip :: struct {
    pattern_name: string;
    start_bar: s64 = 1;
    end_bar: s64 = 1;
    location: Source_Location;
}

Arrangement_Definition :: struct {
    clips: [..] Arrangement_Clip;
    location: Source_Location;
}

Song_Specification :: struct {
    project: Project_Configuration;
    instruments: [..] Instrument_Definition;
    patterns: [..] Pattern_Definition;
    mixer: Mixer_Definition;
    routings: [..] Routing_Definition;
    arrangement: Arrangement_Definition;
}
