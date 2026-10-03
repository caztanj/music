decibels_to_linear :: (decibels: float) -> float {
    return pow(10.0, decibels / 20.0);
}

linear_to_decibels :: (linear: float) -> float {
    if linear <= 0.00001 return -100.0;

    return cast(float) (8.685889638 * cast(float64) log(linear));
}

midi_to_hertz :: (midi_note: s32) -> float {
    return 440.0 * pow(2.0, cast(float)(midi_note - 69) / 12.0);
}

note_to_midi :: (name: string) -> s32 {
    if name.count < 2 return -1;

    cursor := 0;
    first_character := name[cursor];
    cursor += 1;

    if first_character >= #char "a" && first_character <= #char "z" {
        first_character -= 32;
    }

    base_note: s32 = -1;
    if first_character == {
        case #char "C";
            base_note = 0;

        case #char "D";
            base_note = 2;

        case #char "E";
            base_note = 4;

        case #char "F";
            base_note = 5;

        case #char "G";
            base_note = 7;

        case #char "A";
            base_note = 9;

        case #char "B";
            base_note = 11;

        case;
            return -1;
    }

    accidental := 0;
    if cursor < name.count {
        character := name[cursor];
        if character == #char "#" {
            accidental = 1;
            cursor += 1;
        } else if character == #char "b" {
            accidental = -1;
            cursor += 1;
        }
    }

    if cursor >= name.count return -1;

    octave_string: string;
    octave_string.data = name.data + cursor;
    octave_string.count = name.count - cursor;

    octave, success := string_to_int(octave_string);
    if !success return -1;

    midi_number := cast(s32)((octave + 1) * 12 + base_note + accidental);
    if midi_number < 0 || midi_number > 127 return -1;

    return midi_number;
}

DEFAULT_SAMPLE_RATE :: 44100;
DEFAULT_BPM         :: 120.0;
STEPS_PER_BAR       :: 16;
MAXIMUM_TRACKS      :: 16;
MAXIMUM_AUX_TRACKS  :: 4;
MAXIMUM_BLOCK_SIZE  :: 1024;
