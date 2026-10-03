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
}
