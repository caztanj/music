interactive_tests :: () {
    test("map_character_to_playback_command_space", () {
        command := map_character_to_playback_command(32);
        expect_equals(command, Playback_Control_Command.TOGGLE_PLAY_PAUSE);
    });

    test("map_character_to_playback_command_rewind", () {
        command_upper := map_character_to_playback_command(82);
        command_lower := map_character_to_playback_command(114);

        expect_equals(command_upper, Playback_Control_Command.REWIND);
        expect_equals(command_lower, Playback_Control_Command.REWIND);
    });

    test("map_character_to_playback_command_mixer_view", () {
        command_upper := map_character_to_playback_command(77);
        command_lower := map_character_to_playback_command(109);

        expect_equals(command_upper, Playback_Control_Command.TOGGLE_MIXER_VIEW);
        expect_equals(command_lower, Playback_Control_Command.TOGGLE_MIXER_VIEW);
    });

    test("map_character_to_playback_command_quit", () {
        command_upper := map_character_to_playback_command(81);
        command_lower := map_character_to_playback_command(113);
        command_escape := map_character_to_playback_command(27);
        command_unknown := map_character_to_playback_command(65);

        expect_equals(command_upper, Playback_Control_Command.QUIT);
        expect_equals(command_lower, Playback_Control_Command.QUIT);
        expect_equals(command_escape, Playback_Control_Command.QUIT);
        expect_equals(command_unknown, Playback_Control_Command.NONE);
    });

    test("apply_playback_command_state_mutations", () {
        player: Playback_State;
        player.is_paused = false;
        player.show_mixer_view = false;
        player.should_exit = false;
        player.sequencer.clock.current_sample = 44100;

        apply_playback_command(.TOGGLE_PLAY_PAUSE, *player);
        expect_true(player.is_paused);

        apply_playback_command(.TOGGLE_PLAY_PAUSE, *player);
        expect_true(!player.is_paused);

        apply_playback_command(.TOGGLE_MIXER_VIEW, *player);
        expect_true(player.show_mixer_view);

        apply_playback_command(.TOGGLE_MIXER_VIEW, *player);
        expect_true(!player.show_mixer_view);

        apply_playback_command(.REWIND, *player);
        expect_equals(player.sequencer.clock.current_sample, 0);

        apply_playback_command(.QUIT, *player);
        expect_true(player.should_exit);
    });

    test("format_vu_meter_bar", () {
        bar_empty := format_vu_meter_bar(0.0, 12);
        defer free(bar_empty);
        expect_equals(bar_empty, "[------------]");

        bar_half := format_vu_meter_bar(0.5, 12);
        defer free(bar_half);
        expect_equals(bar_half, "[######------]");

        bar_full := format_vu_meter_bar(1.0, 12);
        defer free(bar_full);
        expect_equals(bar_full, "[############]");
    });

    test("format_vu_meters_display", () {
        meters := format_vu_meters_display(0.5, 1.0, 12);
        defer free(meters);
        expect_equals(meters, "L: [######------]  R: [############]");
    });

    test("format_playback_status_line", () {
        player: Playback_State;
        initialize_sequencer_clock(*player.sequencer.clock, 44100, 128.0, 16, 4, 4);
        initialize_voice_manager(*player.voice_manager, 44100);

        samples_per_bar := calculate_samples_per_bar(44100, 128.0, 4);
        samples_per_beat := calculate_samples_per_beat(44100, 128.0);
        player.sequencer.clock.current_sample = cast(u64) (samples_per_bar * 3.0 + samples_per_beat * 1.5);
        player.estimated_cpu_percentage = 1.2;
        player.is_paused = false;

        status_line := format_playback_status_line(*player);
        defer free(status_line);

        expect_equals(status_line, "[PLAYING] Bar: 04.2 | BPM: 128 | CPU: 1.2% | Voices: 0/128");

        player.is_paused = true;
        paused_status_line := format_playback_status_line(*player);
        defer free(paused_status_line);

        expect_equals(paused_status_line, "[PAUSED]  Bar: 04.2 | BPM: 128 | CPU: 1.2% | Voices: 0/128");
    });

    test("format_loudness_meter_status_display", () {
        player: Playback_State;
        initialize_mixer(*player.mixer, 44100);
        defer deinitialize_mixer(*player.mixer);

        loudness_line := format_loudness_meter_status(*player.mixer.loudness_meter);
        defer free(loudness_line);

        expect_equals(loudness_line, "Loudness: -70.0 LUFS | True Peak: -100.0 dBFS");
    });
}
