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
}
