mixer_tests :: () {
    test("mixer channel initialization", () {
        mixer := New(Mixer);
        defer {
            deinitialize_mixer(mixer);
            free(mixer);
        }
        initialize_mixer(mixer, 44100);

        channel, found := find_mixer_channel(mixer, 1);
        expect_true(found);
        expect_equals(channel.gain, 1.0);
        expect_equals(channel.pan, 0.0);
        expect_true(!channel.is_muted);
        expect_true(!channel.is_soloed);

        missing_channel, missing_found := find_mixer_channel(mixer, 99);
        expect_true(!missing_found);
    });

    test("mixer panning equal power", () {
        mixer := New(Mixer);
        defer {
            deinitialize_mixer(mixer);
            free(mixer);
        }
        initialize_mixer(mixer, 44100);

        channel, found := find_mixer_channel(mixer, 1);
        channel.gain = 1.0;
        channel.pan = -1.0;

        clear_channel_buffers(mixer, 10);
        channel.left_buffer[0] = 1.0;
        channel.right_buffer[0] = 1.0;

        mix_channels_to_master(mixer, 10);

        expect_true(mixer.master.left_buffer[0] > 0.9);
        expect_near(mixer.master.right_buffer[0], 0.0, 0.001);

        channel.pan = 1.0;
        clear_channel_buffers(mixer, 10);
        channel.left_buffer[0] = 1.0;
        channel.right_buffer[0] = 1.0;

        mix_channels_to_master(mixer, 10);

        expect_near(mixer.master.left_buffer[0], 0.0, 0.001);
        expect_true(mixer.master.right_buffer[0] > 0.9);
    });

    test("mixer mute and solo logic", () {
        mixer := New(Mixer);
        defer {
            deinitialize_mixer(mixer);
            free(mixer);
        }
        initialize_mixer(mixer, 44100);

        channel_1, _ := find_mixer_channel(mixer, 1);
        channel_2, _ := find_mixer_channel(mixer, 2);

        channel_1.left_buffer[0] = 0.5;
        channel_2.left_buffer[0] = 0.5;

        set_channel_mute(mixer, 1, true);
        mix_channels_to_master(mixer, 1);
        expect_near(mixer.master.left_buffer[0], 0.5 * cast(float) cos(0.25 * PI), 0.01);

        set_channel_mute(mixer, 1, false);
        set_channel_solo(mixer, 1, true);

        clear_channel_buffers(mixer, 1);
        channel_1.left_buffer[0] = 0.5;
        channel_2.left_buffer[0] = 0.5;

        mix_channels_to_master(mixer, 1);
        expect_near(mixer.master.left_buffer[0], 0.5 * cast(float) cos(0.25 * PI), 0.01);
    });

    test("mixer master limiter protection", () {
        mixer := New(Mixer);
        defer {
            deinitialize_mixer(mixer);
            free(mixer);
        }
        initialize_mixer(mixer, 44100);

        channel, _ := find_mixer_channel(mixer, 1);
        channel.gain = 10.0;
        channel.left_buffer[0] = 5.0;
        channel.right_buffer[0] = 5.0;

        mix_channels_to_master(mixer, 1);

        expect_true(mixer.master.left_buffer[0] <= 1.0);
        expect_true(mixer.master.right_buffer[0] <= 1.0);
    });

    test("mixer_aux_send_pre_and_post_fader", () {
        mixer := New(Mixer);
        defer {
            deinitialize_mixer(mixer);
            free(mixer);
        }
        initialize_mixer(mixer, 44100);

        channel, _ := find_mixer_channel(mixer, 1);
        channel.gain = 0.5;
        channel.send_levels[0] = 0.8;
        channel.send_pre_fader[0] = false;
        channel.send_levels[1] = 0.8;
        channel.send_pre_fader[1] = true;

        clear_channel_buffers(mixer, 1);
        channel.left_buffer[0] = 1.0;
        channel.right_buffer[0] = 1.0;

        mix_channels_to_master(mixer, 1);

        expect_near(mixer.aux_tracks[0].left_buffer[0], 0.4, 0.001);
        expect_near(mixer.aux_tracks[1].left_buffer[0], 0.8, 0.001);
    });

    test("mixer_aux_return_effect_summing", () {
        mixer := New(Mixer);
        defer {
            deinitialize_mixer(mixer);
            free(mixer);
        }
        initialize_mixer(mixer, 44100);

        channel, _ := find_mixer_channel(mixer, 1);
        channel.gain = 1.0;
        channel.send_levels[0] = 0.5;
        channel.send_pre_fader[0] = false;

        aux_1, _ := find_mixer_aux_channel(mixer, 1);
        aux_1.gain = 1.0;
        aux_1.saturation_enabled = true;
        configure_saturation_insert(*aux_1.saturation, saturation_type = .TANH, drive = 2.0, mix = 1.0, output_gain = 1.0);

        clear_channel_buffers(mixer, 1);
        channel.left_buffer[0] = 0.6;
        channel.right_buffer[0] = 0.6;

        mix_channels_to_master(mixer, 1);

        pan_factor := cast(float) cos(0.25 * PI);
        dry_component := 0.6 * pan_factor;
        expected_driven := cast(float64) (0.6 * 0.5 * 2.0);
        expected_tanh := (exp(2.0 * expected_driven) - 1.0) / (exp(2.0 * expected_driven) + 1.0);
        aux_component := cast(float) expected_tanh * pan_factor;
        expected_master := dry_component + aux_component;

        expect_near(mixer.master.left_buffer[0], expected_master, 0.01);
    });

    test("mixer_parser_aux_and_send_arguments", () {
        song_text := "[project]\nname = \"Aux Mixer Test\"\nbpm = 120\ntime_signature = 4/4\nbars = 1\n\n[instruments]\nlead = synth(wave=\"saw\")\n\n[pattern melody]\nC4 step=0 len=1 vel=1.0\n\n[mixer]\ntrack 1 (lead): gain = 0.9, send_1 = 0.35, send_2 = 0.6, send_2_pre = true, output = master\naux 1 (reverb): gain = 0.95, reverb = 0.85, room = 0.75, damp = 0.45\nreturn 2 (delay): gain = 0.8, delay = 0.25, feedback = 0.4\nmaster: gain = 1.0, limiter = on\n\n[channel_routing]\nlead -> track 1\n\n[arrangement]\nbar 1: melody\n";

        specification, parse_success, _ := parse_song(song_text, check_samples_on_disk = false);
        expect_true(parse_success);

        track_1 := *specification.mixer.tracks[0];
        expect_near(track_1.send_levels[0], 0.35, 0.001);
        expect_near(track_1.send_levels[1], 0.60, 0.001);
        expect_true(!track_1.send_pre_fader[0]);
        expect_true(track_1.send_pre_fader[1]);

        expect_equals(specification.mixer.aux_tracks.count, 2);

        aux_spec_1 := *specification.mixer.aux_tracks[0];
        expect_equals(aux_spec_1.aux_index, 1);
        expect_equals(aux_spec_1.name, "reverb");
        expect_near(aux_spec_1.gain, 0.95, 0.001);
        expect_true(aux_spec_1.reverb_enabled);
        expect_near(aux_spec_1.reverb_room_size, 0.75, 0.001);
        expect_near(aux_spec_1.reverb_damping, 0.45, 0.001);

        aux_spec_2 := *specification.mixer.aux_tracks[1];
        expect_equals(aux_spec_2.aux_index, 2);
        expect_equals(aux_spec_2.name, "delay");
        expect_near(aux_spec_2.gain, 0.8, 0.001);
        expect_near(aux_spec_2.delay_time_seconds, 0.25, 0.001);
        expect_near(aux_spec_2.delay_feedback, 0.4, 0.001);

        mixer: Mixer;
        configure_mixer_from_definition(*mixer, specification.mixer, 44100, 120.0);
        defer deinitialize_mixer(*mixer);

        expect_near(mixer.tracks[0].send_levels[0], 0.35, 0.001);
        expect_near(mixer.tracks[0].send_levels[1], 0.60, 0.001);
        expect_true(mixer.tracks[0].send_pre_fader[1]);

        expect_equals(mixer.aux_tracks[0].aux_index, 1);
        expect_equals(mixer.aux_tracks[0].name, "reverb");
        expect_true(mixer.aux_tracks[0].reverb_enabled);
        expect_near(mixer.aux_tracks[0].reverb.room_size, 0.75, 0.001);

        expect_equals(mixer.aux_tracks[1].aux_index, 2);
        expect_equals(mixer.aux_tracks[1].name, "delay");
        expect_true(mixer.aux_tracks[1].delay_enabled);
        expect_near(mixer.aux_tracks[1].stereo_delay.feedback, 0.4, 0.001);
    });
}
