map_character_to_playback_command :: (character: s32) -> Playback_Control_Command {
    if character == {
        case 32;
            return .TOGGLE_PLAY_PAUSE;

        case 82;
            return .REWIND;

        case 114;
            return .REWIND;

        case 77;
            return .TOGGLE_MIXER_VIEW;

        case 109;
            return .TOGGLE_MIXER_VIEW;

        case 81;
            return .QUIT;

        case 113;
            return .QUIT;

        case 27;
            return .QUIT;

        case;
            return .NONE;
    }

    return .NONE;
}

poll_interactive_keyboard_input :: () -> Playback_Control_Command {
    #if OS == .WINDOWS {
        if _kbhit() != 0 {
            character := _getch();
            if character == 0 || character == 224 {
                _getch();

                return .NONE;
            }

            command := map_character_to_playback_command(character);

            return command;
        }

        return .NONE;
    } else {
        return .NONE;
    }
}

apply_playback_command :: (command: Playback_Control_Command, player: *Playback_State) {
    if command == {
        case .TOGGLE_PLAY_PAUSE;
            player.is_paused = !player.is_paused;

        case .REWIND;
            rewind_playback(player);

        case .TOGGLE_MIXER_VIEW;
            player.show_mixer_view = !player.show_mixer_view;

        case .QUIT;
            player.should_exit = true;

        case .NONE;
    }
}

rewind_playback :: (player: *Playback_State) {
    player.sequencer.clock.current_sample = 0;
}

playback_audio_callback :: (output_samples: [] float, channel_count: int, sample_rate: int, user_data: *void) {
    player := cast(*Playback_State) user_data;
    frame_count := output_samples.count / channel_count;

    if player.is_paused {
        sample_index := 0;
        while sample_index < output_samples.count {
            output_samples[sample_index] = 0.0;
            sample_index += 1;
        }

        return;
    }

    render_audio_block_with_hot_reload(
        *player.hot_reloader,
        *player.sequencer,
        *player.voice_manager,
        *player.mixer,
        output_samples,
        frame_count,
        *player.last_applied_version
    );
}

initialize_playback_state :: (player: *Playback_State, song_path: string, sample_rate: s64 = DEFAULT_SAMPLE_RATE) -> bool {
    player.last_applied_version = 0;
    player.is_paused = false;
    player.show_mixer_view = false;
    player.should_exit = false;
    player.is_running = false;

    initialize_voice_manager(*player.voice_manager, sample_rate);
    initialize_mixer(*player.mixer, sample_rate);
    initialize_sequencer_clock(*player.sequencer.clock, sample_rate);

    hot_reloader_success := hot_reloader_initialize(*player.hot_reloader, song_path, sample_rate);
    if !hot_reloader_success {
        return false;
    }

    active_state := cast(*Song_State) atomic_read(*player.hot_reloader.active_state_pointer);
    if active_state != null && active_state.is_valid {
        hot_reloader_apply_state_to_engine(active_state, *player.sequencer, *player.mixer);
        player.last_applied_version = active_state.version;
    }

    configuration: Audio_Configuration;
    configuration.sample_rate = cast(int) sample_rate;
    configuration.channel_count = 2;
    configuration.buffer_size_in_frames = 512;

    backend_success := audio_backend_initialize(*player.audio_backend, configuration, playback_audio_callback, player);
    if !backend_success {
        hot_reloader_shutdown(*player.hot_reloader);

        return false;
    }

    return true;
}

start_playback :: (player: *Playback_State) -> bool {
    if player.is_running {
        return true;
    }

    backend_success := audio_backend_start(*player.audio_backend);
    if !backend_success {
        return false;
    }

    hot_reloader_start(*player.hot_reloader);
    player.is_running = true;

    return true;
}

stop_playback :: (player: *Playback_State) {
    if !player.is_running {
        return;
    }

    audio_backend_stop(*player.audio_backend);
    hot_reloader_stop(*player.hot_reloader);
    player.is_running = false;
}

shutdown_playback_state :: (player: *Playback_State) {
    if player.is_running {
        stop_playback(player);
    }

    audio_backend_shutdown(*player.audio_backend);
    hot_reloader_shutdown(*player.hot_reloader);
}

run_interactive_playback :: (song_path: string) -> bool {
    player: Playback_State;
    initialize_success := initialize_playback_state(*player, song_path);
    if !initialize_success {
        print("Failed to initialize playback for '%'\n", song_path);

        return false;
    }

    start_success := start_playback(*player);
    if !start_success {
        print("Failed to start audio playback for '%'\n", song_path);
        shutdown_playback_state(*player);

        return false;
    }

    print("Playing '%' with hot reloading enabled.\n", song_path);
    print("Controls: [Space] Pause/Resume | [R] Rewind | [M] Mixer View | [Q/Esc] Exit\n\n");

    while !player.should_exit {
        command := poll_interactive_keyboard_input();
        if command != .NONE {
            apply_playback_command(command, *player);
            if command == .QUIT {
                break;
            }
        }

        sleep_milliseconds(20);
    }

    print("\nStopping playback and shutting down...\n");
    stop_playback(*player);
    shutdown_playback_state(*player);

    return true;
}

Playback_Control_Command :: enum {
    NONE;
    TOGGLE_PLAY_PAUSE;
    REWIND;
    TOGGLE_MIXER_VIEW;
    QUIT;
}

Playback_State :: struct {
    hot_reloader: Hot_Reloader;
    sequencer: Sequencer;
    voice_manager: Voice_Manager;
    mixer: Mixer;
    audio_backend: Audio_Backend;
    last_applied_version: u64 = 0;
    is_paused: bool = false;
    show_mixer_view: bool = false;
    should_exit: bool = false;
    is_running: bool = false;
}

#if OS == .WINDOWS {
    msvcrt :: #library,system "msvcrt";
    _kbhit :: () -> s32 #foreign msvcrt;
    _getch :: () -> s32 #foreign msvcrt;
}
