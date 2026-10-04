parser_tests :: () {
    test("parse full song specification", () {
        song_text := #string END
[project]
name           = "Neon Horizon"
bpm            = 128
time_signature = 4/4
bars           = 16

[instruments]
kick   = sampler("samples/kick.wav", gain = 1.0)
snare  = sampler("samples/snare.wav", gain = 0.85)
hat    = sampler("samples/hat.wav", gain = 0.70)
bass   = synth(wave="saw", filter="lowpass", cutoff=600, res=0.2, attack=5, decay=60, sustain=0.4, release=100)
lead   = synth(wave="square", filter="lowpass", cutoff=1800, res=0.4, attack=10, decay=120, sustain=0.6, release=200)

[pattern drums_main]
kick   | x . . . x . . . x . . . x . . . |
snare  | . . . . x . . . . . . . x . . . |
hat    | x . x . x . x . x . x . x . x . |

[pattern bass_loop]
C2   step=0   len=2  vel=0.9
C2   step=3   len=1  vel=0.8
Eb2  step=6   len=2  vel=0.9
F2   step=10  len=2  vel=0.85
G2   step=14  len=2  vel=0.95

[pattern lead_hook]
C4   step=0   len=2  vel=0.85
G4   step=4   len=2  vel=0.80
Bb4  step=8   len=4  vel=0.90
C5   step=12  len=4  vel=1.00

[mixer]
track 1 (drums):  gain = 0.95, pan =  0.0, output = master
track 2 (bass):   gain = 0.85, pan =  0.0, output = master
track 3 (lead):   gain = 0.75, pan =  0.15, delay = 0.25, feedback = 0.35, output = master
master:           gain = 1.00, limiter = on, ceiling = -0.2db

[channel_routing]
kick  -> track 1
snare -> track 1
hat   -> track 1
bass  -> track 2
lead  -> track 3

[arrangement]
bar 1-8:   drums_main
bar 1-8:   bass_loop
bar 5-12:  lead_hook
bar 9-16:  drums_main
bar 9-16:  bass_loop
END;

        song_specification, success, error_message := parse_song(song_text, "neon.song", check_samples_on_disk = false);
        expect_true(success);

        expect_equals(song_specification.project.name, "Neon Horizon");
        expect_equals(song_specification.project.beats_per_minute, 128.0);
        expect_equals(song_specification.project.time_signature_numerator, 4);
        expect_equals(song_specification.project.time_signature_denominator, 4);
        expect_equals(song_specification.project.total_bars, 16);

        expect_equals(song_specification.instruments.count, 5);

        kick_instrument, kick_found := find_instrument(*song_specification, "kick");
        expect_true(kick_found);
        expect_equals(kick_instrument.type, Instrument_Type.SAMPLER);
        expect_equals(kick_instrument.sampler.sample_file_path, "samples/kick.wav");
        expect_near(kick_instrument.sampler.gain, 1.0, 0.001);

        bass_instrument, bass_found := find_instrument(*song_specification, "bass");
        expect_true(bass_found);
        expect_equals(bass_instrument.type, Instrument_Type.SYNTHESIZER);
        expect_equals(bass_instrument.synthesizer.waveform, Waveform_Type.SAWTOOTH);
        expect_equals(bass_instrument.synthesizer.filter.type, Filter_Type.LOWPASS);
        expect_near(bass_instrument.synthesizer.filter.cutoff_frequency_hertz, 600.0, 0.001);
        expect_near(bass_instrument.synthesizer.filter.resonance, 0.2, 0.001);
        expect_near(bass_instrument.synthesizer.envelope.attack_milliseconds, 5.0, 0.001);
        expect_near(bass_instrument.synthesizer.envelope.decay_milliseconds, 60.0, 0.001);
        expect_near(bass_instrument.synthesizer.envelope.sustain_level, 0.4, 0.001);
        expect_near(bass_instrument.synthesizer.envelope.release_milliseconds, 100.0, 0.001);

        expect_equals(song_specification.patterns.count, 3);

        drums_pattern, drums_found := find_pattern(*song_specification, "drums_main");
        expect_true(drums_found);
        expect_equals(drums_pattern.step_tracks.count, 3);
        expect_equals(drums_pattern.step_tracks[0].instrument_name, "kick");
        expect_equals(drums_pattern.step_tracks[0].steps.count, 16);
        expect_true(drums_pattern.step_tracks[0].steps[0]);
        expect_true(!drums_pattern.step_tracks[0].steps[1]);

        bass_pattern, bass_pattern_found := find_pattern(*song_specification, "bass_loop");
        expect_true(bass_pattern_found);
        expect_equals(bass_pattern.piano_roll_notes.count, 5);
        expect_equals(bass_pattern.piano_roll_notes[0].midi_note_number, 36);
        expect_equals(bass_pattern.piano_roll_notes[0].start_step, 0);
        expect_equals(bass_pattern.piano_roll_notes[0].step_length, 2);
        expect_near(bass_pattern.piano_roll_notes[0].velocity, 0.9, 0.001);

        expect_equals(song_specification.mixer.tracks.count, 3);
        track_1, track_1_found := find_mixer_track(*song_specification, 1);
        expect_true(track_1_found);
        expect_equals(track_1.name, "drums");
        expect_near(track_1.gain, 0.95, 0.001);

        track_3, track_3_found := find_mixer_track(*song_specification, 3);
        expect_true(track_3_found);
        expect_near(track_3.delay_time_seconds, 0.25, 0.001);
        expect_near(track_3.delay_feedback, 0.35, 0.001);

        expect_true(song_specification.mixer.master.limiter_enabled);
        expect_near(song_specification.mixer.master.limiter_ceiling_decibels, -0.2, 0.001);

        expect_equals(song_specification.routings.count, 5);
        kick_routing, kick_routing_found := find_routing_for_instrument(*song_specification, "kick");
        expect_true(kick_routing_found);
        expect_equals(kick_routing.track_index, 1);

        expect_equals(song_specification.arrangement.clips.count, 5);
        expect_equals(song_specification.arrangement.clips[0].pattern_name, "drums_main");
        expect_equals(song_specification.arrangement.clips[0].start_bar, 1);
        expect_equals(song_specification.arrangement.clips[0].end_bar, 8);
    });

    test("diagnostic error on missing section bracket", () {
        song_text := "project]\nname = \"Track\"";
        song_specification, success, error_message := parse_song(song_text, "test.song", check_samples_on_disk = false);
        expect_true(!success);
        expect_true(error_message.count > 0);
    });

    test("diagnostic error on invalid note name", () {
        song_text := #string END
[project]
name = "Track"

[pattern lead]
InvalidNote step=0 len=2
END;

        song_specification, success, error_message := parse_song(song_text, "test.song", check_samples_on_disk = false);
        expect_true(!success);
        expect_true(error_message.count > 0);
    });

    test("semantic error on undefined pattern in arrangement", () {
        song_text := #string END
[project]
name = "Track"

[arrangement]
bar 1-4: nonexistent_pattern
END;

        song_specification, success, error_message := parse_song(song_text, "test.song", check_samples_on_disk = false);
        expect_true(!success);
        expect_true(error_message.count > 0);
    });

    test("semantic error on undefined instrument in routing", () {
        song_text := #string END
[project]
name = "Track"

[channel_routing]
nonexistent_instrument -> track 1
END;

        song_specification, success, error_message := parse_song(song_text, "test.song", check_samples_on_disk = false);
        expect_true(!success);
        expect_true(error_message.count > 0);
    });

    test("semantic error on undefined instrument in step pattern", () {
        song_text := #string END
[project]
name = "Track"

[pattern drums]
ghost_drum | x . x . |
END;

        song_specification, success, error_message := parse_song(song_text, "test.song", check_samples_on_disk = false);
        expect_true(!success);
        expect_true(error_message.count > 0);
    });

    test("semantic error on missing sample file on disk", () {
        song_text := #string END
[project]
name = "Track"

[instruments]
kick = sampler("nonexistent_path_to_sample_file_12345.wav")
END;

        song_specification, success, error_message := parse_song(song_text, "test.song", check_samples_on_disk = true);
        expect_true(!success);
        expect_true(error_message.count > 0);
    });

    test("project swing and shuffle parsing", () {
        song_text := #string END
[project]
name = "Swing Track"
bpm = 120
swing = 58%

[instruments]
lead = synth(wave="saw")

[pattern melody]
C4 step=0 len=1

[mixer]
track 1: gain = 1.0, output = master
master: gain = 1.0, limiter = on

[channel_routing]
lead -> track 1

[arrangement]
bar 1: melody
END;

        song_specification, success, error_message := parse_song(song_text, "test.song", check_samples_on_disk = false);
        expect_true(success);
        expect_near(song_specification.project.swing, 0.58, 0.001);
    });

    test("pattern swing in header and body", () {
        song_text := #string END
[project]
name = "Pattern Swing Track"
bpm = 120
swing = 50%

[instruments]
kick = synth(wave="sine")
lead = synth(wave="saw")

[pattern drums swing=66%]
kick | x . x . |

[pattern melody]
swing = 0.70
C4 step=0 len=1

[mixer]
track 1: gain = 1.0, output = master
master: gain = 1.0, limiter = on

[channel_routing]
kick -> track 1
lead -> track 1

[arrangement]
bar 1: drums
bar 1: melody
END;

        song_specification, success, error_message := parse_song(song_text, "test.song", check_samples_on_disk = false);
        expect_true(success);
        drums_pattern, drums_found := find_pattern(*song_specification, "drums");
        expect_true(drums_found);
        expect_near(drums_pattern.swing, 0.66, 0.001);
        expect_near(get_pattern_effective_swing(*song_specification, drums_pattern), 0.66, 0.001);

        melody_pattern, melody_found := find_pattern(*song_specification, "melody");
        expect_true(melody_found);
        expect_near(melody_pattern.swing, 0.70, 0.001);
        expect_near(get_pattern_effective_swing(*song_specification, melody_pattern), 0.70, 0.001);
    });

    test("pattern triplet grid and micro timing subdivisions", () {
        song_text := #string END
[project]
name = "Triplet Track"
bpm = 140

[instruments]
hat = synth(wave="sine")
lead = synth(wave="saw")

[pattern triplet_hats grid=8t]
hat | t1 t2 t3 t1 t2 t3 t1 t2 t3 t1 t2 t3 |

[pattern rolls]
hat | [t1 t2 t3] . [x x x x] . |

[pattern guitar_strum]
E2 step=0 tick=0 len=2
B2 step=0 tick=12 len=2
E3 step=0 tick=24 len=2
G3 step=t2 len=16t

[mixer]
track 1: gain = 1.0, output = master
master: gain = 1.0, limiter = on

[channel_routing]
hat -> track 1
lead -> track 1

[arrangement]
bar 1: triplet_hats
bar 2: rolls
bar 3: guitar_strum
END;

        song_specification, success, error_message := parse_song(song_text, "test.song", check_samples_on_disk = false);
        expect_true(success);

        triplet_pattern, triplet_found := find_pattern(*song_specification, "triplet_hats");
        expect_true(triplet_found);
        expect_equals(cast(s64) triplet_pattern.subdivision, cast(s64) Pattern_Subdivision.TRIPLET_8TH);
        expect_equals(triplet_pattern.step_count, 12);

        rolls_pattern, rolls_found := find_pattern(*song_specification, "rolls");
        expect_true(rolls_found);
        expect_true(rolls_pattern.step_tracks.count > 0);
        track := *rolls_pattern.step_tracks[0];
        expect_true(track.step_events.count >= 7);
        expect_equals(track.step_events[0].step_index, 0);
        expect_equals(track.step_events[0].tick_offset, 0);
        expect_equals(track.step_events[1].step_index, 0);
        expect_equals(track.step_events[1].tick_offset, 8);
        expect_equals(track.step_events[2].step_index, 0);
        expect_equals(track.step_events[2].tick_offset, 16);

        strum_pattern, strum_found := find_pattern(*song_specification, "guitar_strum");
        expect_true(strum_found);
        expect_equals(strum_pattern.piano_roll_notes.count, 4);
        expect_equals(strum_pattern.piano_roll_notes[0].tick_offset, 0);
        expect_equals(strum_pattern.piano_roll_notes[1].tick_offset, 12);
        expect_equals(strum_pattern.piano_roll_notes[2].tick_offset, 24);
        expect_equals(strum_pattern.piano_roll_notes[3].tick_offset, 16);
        expect_equals(strum_pattern.piano_roll_notes[3].length_ticks, 16);
    });

    test("pattern ghost and accent note dynamics parsing", () {
        song_text := #string END
[project]
name = "Dynamics Test"
bpm = 120
time_signature = 4/4
bars = 1

[instruments]
kick = synth(wave="sine")
snare = synth(wave="triangle")
hat = synth(wave="square")
lead = synth(wave="saw")

[pattern drum_dynamics]
snare | . . g . ^ . ! . |
hat   | [x g ^ x] . ghost . |
kick  | a . accent . x . . . |

[pattern melody_dynamics]
^C4 step=0 len=2
!E4 step=2 len=2
G4  step=4 len=2 ghost
B4  step=6 len=2 accent
D5  step=8 len=2 vel=ghost
F5  step=10 len=2 vel=accent
A5  step=12 len=2 vel=75%

[mixer]
track 1: gain = 1.0, output = master
master: gain = 1.0, limiter = on

[channel_routing]
kick -> track 1
snare -> track 1
hat -> track 1
lead -> track 1

[arrangement]
bar 1: drum_dynamics
bar 1: melody_dynamics
END;

        song_specification, success, error_message := parse_song(song_text, "dynamics.song", check_samples_on_disk = false);
        expect_true(success);

        drum_pattern, drum_pattern_found := find_pattern(*song_specification, "drum_dynamics");
        expect_true(drum_pattern_found);

        snare_track := *drum_pattern.step_tracks[0];
        expect_near(snare_track.velocities[2], GHOST_NOTE_VELOCITY, 0.001);
        expect_near(snare_track.velocities[4], ACCENT_NOTE_VELOCITY, 0.001);
        expect_near(snare_track.velocities[6], ACCENT_NOTE_VELOCITY, 0.001);

        hat_track := *drum_pattern.step_tracks[1];
        expect_equals(hat_track.step_events[0].velocity, 1.0);
        expect_near(hat_track.step_events[1].velocity, GHOST_NOTE_VELOCITY, 0.001);
        expect_near(hat_track.step_events[2].velocity, ACCENT_NOTE_VELOCITY, 0.001);
        expect_equals(hat_track.step_events[3].velocity, 1.0);
        expect_near(hat_track.velocities[2], GHOST_NOTE_VELOCITY, 0.001);

        kick_track := *drum_pattern.step_tracks[2];
        expect_near(kick_track.velocities[0], ACCENT_NOTE_VELOCITY, 0.001);
        expect_near(kick_track.velocities[2], ACCENT_NOTE_VELOCITY, 0.001);

        melody_pattern, melody_pattern_found := find_pattern(*song_specification, "melody_dynamics");
        expect_true(melody_pattern_found);
        expect_equals(melody_pattern.piano_roll_notes.count, 7);

        expect_near(melody_pattern.piano_roll_notes[0].velocity, ACCENT_NOTE_VELOCITY, 0.001);
        expect_near(melody_pattern.piano_roll_notes[1].velocity, ACCENT_NOTE_VELOCITY, 0.001);
        expect_near(melody_pattern.piano_roll_notes[2].velocity, GHOST_NOTE_VELOCITY, 0.001);
        expect_near(melody_pattern.piano_roll_notes[3].velocity, ACCENT_NOTE_VELOCITY, 0.001);
        expect_near(melody_pattern.piano_roll_notes[4].velocity, GHOST_NOTE_VELOCITY, 0.001);
        expect_near(melody_pattern.piano_roll_notes[5].velocity, ACCENT_NOTE_VELOCITY, 0.001);
        expect_near(melody_pattern.piano_roll_notes[6].velocity, 0.75, 0.001);
    });

    test("sampler_and_synthesizer_choke_group_parsing", () {
        song_text := #string END
[project]
name = "Choke Group Test"
bpm = 120
time_signature = 4/4
bars = 1

[instruments]
hat_open = sampler("samples/hat_open.wav", choke = 1)
hat_closed = sampler("samples/hat_closed.wav", choke_group = 1)
cymbal = sampler("samples/cymbal.wav", group = "cymbals")
lead = synth(wave="saw", choke = 2)

[pattern main]
hat_open | x . . . |

[mixer]
track 1: gain = 1.0, output = master
master: gain = 1.0, limiter = on

[channel_routing]
hat_open -> track 1
hat_closed -> track 1
cymbal -> track 1
lead -> track 1

[arrangement]
bar 1: main
END;

        song_specification, success, error_message := parse_song(song_text, "choke.song", check_samples_on_disk = false);
        expect_true(success);

        hat_open, hat_open_found := find_instrument(*song_specification, "hat_open");
        expect_true(hat_open_found);
        expect_equals(hat_open.sampler.choke_group, 1);

        hat_closed, hat_closed_found := find_instrument(*song_specification, "hat_closed");
        expect_true(hat_closed_found);
        expect_equals(hat_closed.sampler.choke_group, 1);

        cymbal, cymbal_found := find_instrument(*song_specification, "cymbal");
        expect_true(cymbal_found);
        expect_true(cymbal.sampler.choke_group > 0);

        lead, lead_found := find_instrument(*song_specification, "lead");
        expect_true(lead_found);
        expect_equals(lead.synthesizer.choke_group, 2);
    });
}

