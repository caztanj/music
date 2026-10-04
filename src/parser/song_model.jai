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

    if name == "triangle" || name == "tri" {
        return .TRIANGLE, true;
    }

    if name == "white" || name == "white_noise" || name == "noise" {
        return .WHITE_NOISE, true;
    }

    if name == "pink" || name == "pink_noise" {
        return .PINK_NOISE, true;
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

    if name == "low_shelf" || name == "lowshelf" || name == "shelf_low" {
        return .LOW_SHELF, true;
    }

    if name == "high_shelf" || name == "highshelf" || name == "shelf_high" {
        return .HIGH_SHELF, true;
    }

    if name == "peaking" || name == "peak" || name == "bell" {
        return .PEAKING, true;
    }

    if name == "notch" {
        return .NOTCH, true;
    }

    return .NONE, false;
}

string_to_saturation_type :: (name: string) -> Saturation_Type, bool {
    if name == "tanh" || name == "soft" || name == "tape" {
        return .TANH, true;
    }

    if name == "cubic" || name == "warmth" || name == "warm" {
        return .CUBIC, true;
    }

    if name == "hard_clip" || name == "hard" || name == "clip" {
        return .HARD_CLIP, true;
    }

    if name == "none" || name == "off" {
        return .NONE, true;
    }

    return .NONE, false;
}

string_to_lfo_waveform :: (name: string) -> LFO_Waveform, bool {
    if name == "sine" {
        return .SINE, true;
    }

    if name == "triangle" || name == "tri" {
        return .TRIANGLE, true;
    }

    if name == "square" || name == "pulse" {
        return .SQUARE, true;
    }

    if name == "sample_and_hold" || name == "random" || name == "sh" {
        return .SAMPLE_AND_HOLD, true;
    }

    return .SINE, false;
}

string_to_lfo_destination :: (name: string) -> LFO_Destination, bool {
    if name == "pitch" || name == "vibrato" || name == "tune" {
        return .PITCH, true;
    }

    if name == "filter" || name == "cutoff" || name == "filter_cutoff" {
        return .FILTER_CUTOFF, true;
    }

    if name == "pan" || name == "panning" {
        return .PAN, true;
    }

    if name == "volume" || name == "gain" || name == "tremolo" {
        return .VOLUME, true;
    }

    if name == "none" {
        return .NONE, true;
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

        case .WHITE_NOISE;
            return "white_noise";

        case .PINK_NOISE;
            return "pink_noise";

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

        case .LOW_SHELF;
            return "low_shelf";

        case .HIGH_SHELF;
            return "high_shelf";

        case .PEAKING;
            return "peaking";

        case .NOTCH;
            return "notch";

        case .NONE;
            return "none";

        case;
            return "unknown";
    }
}

saturation_type_to_string :: (saturation_type: Saturation_Type) -> string {
    if saturation_type == {
        case .TANH;
            return "tanh";

        case .CUBIC;
            return "cubic";

        case .HARD_CLIP;
            return "hard_clip";

        case .NONE;
            return "none";

        case;
            return "unknown";
    }
}

clamp_swing_value :: (swing_amount: float) -> float {
    clamped_value := swing_amount;
    if clamped_value < 0.0 {
        clamped_value = 0.0;
    }
    if clamped_value > 0.95 {
        clamped_value = 0.95;
    }

    return clamped_value;
}

get_pattern_effective_swing :: (song_specification: *Song_Specification, pattern: *Pattern_Definition) -> float {
    if pattern != null && pattern.swing >= 0.0 {
        return clamp_swing_value(pattern.swing);
    }

    if song_specification != null {
        return clamp_swing_value(song_specification.project.swing);
    }

    return 0.5;
}

string_to_pattern_subdivision :: (name: string) -> Pattern_Subdivision, bool {
    if name == "standard" || name == "16th" || name == "16" || name == "1/16" {
        return .STANDARD_16TH, true;
    }

    if name == "triplet_8th" || name == "8t" || name == "8th_triplet" || name == "1/8t" || name == "12" {
        return .TRIPLET_8TH, true;
    }

    if name == "triplet_16th" || name == "16t" || name == "16th_triplet" || name == "1/16t" || name == "24" {
        return .TRIPLET_16TH, true;
    }

    if name == "triplet_32nd" || name == "32t" || name == "32nd_triplet" || name == "1/32t" || name == "48" {
        return .TRIPLET_32ND, true;
    }

    return .STANDARD_16TH, false;
}

pattern_subdivision_to_string :: (subdivision: Pattern_Subdivision) -> string {
    if subdivision == {
        case .STANDARD_16TH;
            return "16th";

        case .TRIPLET_8TH;
            return "8t";

        case .TRIPLET_16TH;
            return "16t";

        case .TRIPLET_32ND;
            return "32t";

        case;
            return "unknown";
    }
}

is_triplet_subdivision :: (subdivision: Pattern_Subdivision) -> bool {
    return subdivision == .TRIPLET_8TH || subdivision == .TRIPLET_16TH || subdivision == .TRIPLET_32ND;
}

get_subdivision_step_count :: (subdivision: Pattern_Subdivision) -> s64 {
    if subdivision == {
        case .TRIPLET_8TH;
            return 12;

        case .TRIPLET_16TH;
            return 24;

        case .TRIPLET_32ND;
            return 48;

        case .STANDARD_16TH;
            return STEPS_PER_BAR;

        case;
            return STEPS_PER_BAR;
    }
}


Waveform_Type :: enum {

    SAWTOOTH;
    SQUARE;
    SINE;
    TRIANGLE;
    WHITE_NOISE;
    PINK_NOISE;
}

Filter_Type :: enum {
    NONE;
    LOWPASS;
    HIGHPASS;
    BANDPASS;
    LOW_SHELF;
    HIGH_SHELF;
    PEAKING;
    NOTCH;
}

Saturation_Type :: enum {
    NONE;
    TANH;
    CUBIC;
    HARD_CLIP;
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
    swing: float = 0.5;
    location: Source_Location;
}


Envelope_Configuration :: struct {
    attack_milliseconds: float = 10.0;
    decay_milliseconds: float = 100.0;
    sustain_level: float = 0.7;
    release_milliseconds: float = 100.0;
}

Filter_Configuration :: struct {
    type: Filter_Type = .NONE;
    cutoff_frequency_hertz: float = 20000.0;
    resonance: float = 0.0;
    envelope_amount: float = 0.0;
    velocity_to_envelope: float = 0.0;
    velocity_to_cutoff: float = 0.0;
    velocity_to_resonance: float = 0.0;
    envelope: Envelope_Configuration;
}

LFO_Waveform :: enum {
    SINE;
    TRIANGLE;
    SQUARE;
    SAMPLE_AND_HOLD;
}

LFO_Destination :: enum {
    NONE;
    PITCH;
    FILTER_CUTOFF;
    PAN;
    VOLUME;
}

LFO_Configuration :: struct {
    enabled: bool = false;
    waveform: LFO_Waveform = .SINE;
    destination: LFO_Destination = .NONE;
    rate_hertz: float = 2.0;
    is_tempo_synced: bool = false;
    tempo_sync_numerator: s32 = 1;
    tempo_sync_denominator: s32 = 4;
    is_triplet: bool = false;
    amount: float = 0.0;
    retrigger: bool = true;
}

Sampler_Configuration :: struct {
    sample_file_path: string;
    gain: float = 1.0;
    root_midi_note: s32 = 60;
}

Synthesizer_Configuration :: struct {
    waveform: Waveform_Type = .SAWTOOTH;
    oscillator_2_enabled: bool = false;
    oscillator_2_waveform: Waveform_Type = .SAWTOOTH;
    oscillator_2_semitones: s32 = 0;
    oscillator_2_cents: float = 0.0;
    oscillator_mix: float = 0.5;
    noise_level: float = 0.0;
    noise_type: Waveform_Type = .WHITE_NOISE;
    unison_voices: s32 = 1;
    unison_detune: float = 15.0;
    unison_spread: float = 1.0;
    filter: Filter_Configuration;
    envelope: Envelope_Configuration;
    lfo_1: LFO_Configuration;
    lfo_2: LFO_Configuration;
    gain: float = 1.0;
    is_monophonic: bool = false;
    portamento_milliseconds: float = 0.0;
    is_portamento_tempo_synced: bool = false;
    portamento_tempo_sync_numerator: s32 = 1;
    portamento_tempo_sync_denominator: s32 = 16;
    is_portamento_triplet: bool = false;
    legato: bool = true;
    velocity_to_gain: float = 1.0;
}


Instrument_Definition :: struct {
    name: string;
    type: Instrument_Type = .SYNTHESIZER;
    sampler: Sampler_Configuration;
    synthesizer: Synthesizer_Configuration;
    location: Source_Location;
}

Pattern_Subdivision :: enum {
    STANDARD_16TH;
    TRIPLET_8TH;
    TRIPLET_16TH;
    TRIPLET_32ND;
}

Step_Event :: struct {
    step_index: s64 = 0;
    tick_offset: s64 = 0;
    velocity: float = 1.0;
}

Sub_Step_Item :: struct {
    is_hit: bool = false;
    velocity: float = 1.0;
}

Piano_Roll_Note :: struct {
    midi_note_number: s32 = 60;
    start_step: s64 = 0;
    step_length: s64 = 1;
    tick_offset: s64 = 0;
    length_ticks: s64 = 0;
    velocity: float = 1.0;
    location: Source_Location;
}

Step_Sequencer_Track :: struct {
    instrument_name: string;
    steps: [..] bool;
    velocities: [..] float;
    step_events: [..] Step_Event;
    location: Source_Location;
}

Pattern_Definition :: struct {
    name: string;
    step_tracks: [..] Step_Sequencer_Track;
    piano_roll_notes: [..] Piano_Roll_Note;
    step_count: s64 = STEPS_PER_BAR;
    subdivision: Pattern_Subdivision = .STANDARD_16TH;
    swing: float = -1.0;
    location: Source_Location;
}


Mixer_Track_Definition :: struct {
    track_index: s64 = 1;
    name: string;
    gain: float = 1.0;
    pan: float = 0.0;
    delay_time_seconds: float = 0.0;
    delay_feedback: float = 0.0;
    reverb_enabled: bool = false;
    reverb_room_size: float = 0.5;
    reverb_damping: float = 0.5;
    reverb_predelay_milliseconds: float = 10.0;
    reverb_mix: float = 0.3;
    equalizer_enabled: bool = false;
    equalizer_low_gain_decibels: float = 0.0;
    equalizer_low_frequency_hertz: float = 120.0;
    equalizer_mid_gain_decibels: float = 0.0;
    equalizer_mid_frequency_hertz: float = 1200.0;
    equalizer_mid_quality_factor: float = 1.0;
    equalizer_high_gain_decibels: float = 0.0;
    equalizer_high_frequency_hertz: float = 8000.0;
    chorus_enabled: bool = false;
    chorus_rate_hertz: float = 1.0;
    chorus_depth_milliseconds: float = 2.0;
    chorus_center_delay_milliseconds: float = 7.0;
    chorus_feedback: float = 0.0;
    chorus_mix: float = 0.5;
    chorus_stereo_phase_degrees: float = 90.0;
    saturation_enabled: bool = false;
    saturation_type: Saturation_Type = .TANH;
    saturation_drive: float = 1.0;
    saturation_mix: float = 1.0;
    saturation_output_gain: float = 1.0;
    compressor_enabled: bool = false;
    compressor_threshold_decibels: float = -12.0;
    compressor_ratio: float = 4.0;
    compressor_attack_milliseconds: float = 10.0;
    compressor_release_milliseconds: float = 100.0;
    compressor_knee_decibels: float = 6.0;
    compressor_makeup_gain_decibels: float = 0.0;
    compressor_mix: float = 1.0;
    sidechain_source_track_index: s64 = 0;
    sidechain_source_name: string;
    sidechain_depth_decibels: float = 0.0;
    compressor_threshold_set: bool = false;
    compressor_ratio_set: bool = false;
    compressor_attack_set: bool = false;
    send_levels: [MAXIMUM_AUX_TRACKS] float;
    send_pre_fader: [MAXIMUM_AUX_TRACKS] bool;
    output_target: string = "master";
    location: Source_Location;
}

Aux_Track_Definition :: struct {
    aux_index: s64 = 1;
    name: string;
    gain: float = 1.0;
    pan: float = 0.0;
    delay_time_seconds: float = 0.0;
    delay_feedback: float = 0.0;
    reverb_enabled: bool = false;
    reverb_room_size: float = 0.5;
    reverb_damping: float = 0.5;
    reverb_predelay_milliseconds: float = 10.0;
    reverb_mix: float = 1.0;
    equalizer_enabled: bool = false;
    equalizer_low_gain_decibels: float = 0.0;
    equalizer_low_frequency_hertz: float = 120.0;
    equalizer_mid_gain_decibels: float = 0.0;
    equalizer_mid_frequency_hertz: float = 1200.0;
    equalizer_mid_quality_factor: float = 1.0;
    equalizer_high_gain_decibels: float = 0.0;
    equalizer_high_frequency_hertz: float = 8000.0;
    chorus_enabled: bool = false;
    chorus_rate_hertz: float = 1.0;
    chorus_depth_milliseconds: float = 2.0;
    chorus_center_delay_milliseconds: float = 7.0;
    chorus_feedback: float = 0.0;
    chorus_mix: float = 0.5;
    chorus_stereo_phase_degrees: float = 90.0;
    saturation_enabled: bool = false;
    saturation_type: Saturation_Type = .TANH;
    saturation_drive: float = 1.0;
    saturation_mix: float = 1.0;
    saturation_output_gain: float = 1.0;
    compressor_enabled: bool = false;
    compressor_threshold_decibels: float = -12.0;
    compressor_ratio: float = 4.0;
    compressor_attack_milliseconds: float = 10.0;
    compressor_release_milliseconds: float = 100.0;
    compressor_knee_decibels: float = 6.0;
    compressor_makeup_gain_decibels: float = 0.0;
    compressor_mix: float = 1.0;
    location: Source_Location;
}

Master_Track_Definition :: struct {
    gain: float = 1.0;
    limiter_enabled: bool = true;
    limiter_ceiling_decibels: float = -0.1;
    reverb_enabled: bool = false;
    reverb_room_size: float = 0.5;
    reverb_damping: float = 0.5;
    reverb_predelay_milliseconds: float = 10.0;
    reverb_mix: float = 0.3;
    equalizer_enabled: bool = false;
    equalizer_low_gain_decibels: float = 0.0;
    equalizer_low_frequency_hertz: float = 120.0;
    equalizer_mid_gain_decibels: float = 0.0;
    equalizer_mid_frequency_hertz: float = 1200.0;
    equalizer_mid_quality_factor: float = 1.0;
    equalizer_high_gain_decibels: float = 0.0;
    equalizer_high_frequency_hertz: float = 8000.0;
    chorus_enabled: bool = false;
    chorus_rate_hertz: float = 1.0;
    chorus_depth_milliseconds: float = 2.0;
    chorus_center_delay_milliseconds: float = 7.0;
    chorus_feedback: float = 0.0;
    chorus_mix: float = 0.5;
    chorus_stereo_phase_degrees: float = 90.0;
    saturation_enabled: bool = false;
    saturation_type: Saturation_Type = .TANH;
    saturation_drive: float = 1.0;
    saturation_mix: float = 1.0;
    saturation_output_gain: float = 1.0;
    compressor_enabled: bool = false;
    compressor_threshold_decibels: float = -12.0;
    compressor_ratio: float = 4.0;
    compressor_attack_milliseconds: float = 10.0;
    compressor_release_milliseconds: float = 100.0;
    compressor_knee_decibels: float = 6.0;
    compressor_makeup_gain_decibels: float = 0.0;
    compressor_mix: float = 1.0;
    location: Source_Location;
}

Mixer_Definition :: struct {
    tracks: [..] Mixer_Track_Definition;
    aux_tracks: [..] Aux_Track_Definition;
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
