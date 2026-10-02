common_tests :: () {
    test("note_to_midi", () {
        expect_equals(note_to_midi("A4"), 69);
        expect_equals(note_to_midi("C4"), 60);
        expect_equals(note_to_midi("F#3"), 54);
        expect_equals(note_to_midi("Bb2"), 46);
        expect_equals(note_to_midi("invalid"), -1);
    });

    test("midi_to_hertz", () {
        expect_near(midi_to_hertz(69), 440.0);
        expect_near(midi_to_hertz(81), 880.0);
    });

    test("decibel_conversions", () {
        decibels := -6.0;
        linear := decibels_to_linear(decibels);
        expect_near(linear_to_decibels(linear), -6.0, 0.01);
        expect_near(decibels_to_linear(0.0), 1.0, 0.0001);
    });
}
