main :: () {
    arguments := get_command_line_arguments();
    options, success := parse_arguments(arguments);

    if !success {
        print_usage();
        exit(1);
    }

    if options.command == {
        case .HELP;
            print_usage();

        case .PLAY;
            play_success := run_interactive_playback(options.song_path);
            if !play_success {
                exit(1);
            }

        case .CHECK;
            print("Checking %\n", options.song_path);
            song_specification, success, error_message := parse_song_from_file(options.song_path, check_samples_on_disk = true);
            if !success {
                print("Error: %\n", error_message);
                exit(1);
            }
            print("Song '%': Validation successful!\n", song_specification.project.name);

        case .EXPORT;
            if options.export_stems {
                print("Exporting stems for % to %\n", options.song_path, options.output_path);
                export_success := export_song_stems_to_wav(options.song_path, options.output_path);
                if !export_success {
                    print("Stem export failed!\n");
                    exit(1);
                }
                print("Stem export completed successfully: %\n", options.output_path);
            } else {
                print("Exporting % to %\n", options.song_path, options.output_path);
                export_success := export_song_to_wav(options.song_path, options.output_path);
                if !export_success {
                    print("Export failed!\n");
                    exit(1);
                }
                print("Export completed successfully: %\n", options.output_path);
            }

        case .TEST_TONE;
            print("Playing 440 Hz test tone for % seconds...\n", options.test_tone_duration);
            play_success := play_test_tone(options.test_tone_duration, 440.0, 0.2);
            if !play_success {
                print("Failed to initialize or play audio test tone.\n");
                exit(1);
            }

        case;
            print_usage();
    }
}

parse_arguments :: (arguments: [] string) -> (Command_Line_Options, bool) {
    options: Command_Line_Options;

    if arguments.count <= 1 {
        options.command = .HELP;
        return options, true;
    }

    command := arguments[1];

    if command == "-h" || command == "--help" || command == "help" {
        options.command = .HELP;
        return options, true;
    }

    if command == "play" {
        if arguments.count < 3 {
            print("Error: Missing song file for play command.\n\n");
            return options, false;
        }

        options.command = .PLAY;
        options.song_path = arguments[2];
        return options, true;
    }

    if command == "check" {
        if arguments.count < 3 {
            print("Error: Missing song file for check command.\n\n");
            return options, false;
        }

        options.command = .CHECK;
        options.song_path = arguments[2];
        return options, true;
    }

    if command == "export" {
        if arguments.count < 3 {
            print("Error: Missing song file for export command.\n\n");
            return options, false;
        }

        options.command = .EXPORT;
        options.song_path = arguments[2];

        has_custom_output := false;
        argument_index := 3;
        while argument_index < arguments.count {
            if arguments[argument_index] == "-o" && argument_index + 1 < arguments.count {
                options.output_path = arguments[argument_index + 1];
                has_custom_output = true;
                argument_index += 2;
            } else if arguments[argument_index] == "--stems" || arguments[argument_index] == "-stems" {
                options.export_stems = true;
                argument_index += 1;
            } else {
                argument_index += 1;
            }
        }

        if options.export_stems && !has_custom_output {
            options.output_path = "stems";
        }

        return options, true;
    }

    if command == "test-tone" {
        options.command = .TEST_TONE;
        if arguments.count >= 3 {
            duration_value, parse_success := string_to_float(arguments[2]);
            if parse_success && duration_value > 0.0 {
                options.test_tone_duration = duration_value;
            }
        }

        return options, true;
    }

    print("Error: Unknown command '%'\n\n", command);

    return options, false;
}

print_usage :: () {
    print("Usage: music_engine <command> [options]\n\n");
    print("Commands:\n");
    print("  play <file.song>                                Play a song file with hot reloading\n");
    print("  export <file.song> [-o <out.wav>] [--stems]     Export a song file to WAV or multi-track stems\n");
    print("  check <file.song>                               Validate a song file syntax\n");
    print("  test-tone [seconds]                             Play a 440 Hz sine test tone through speakers\n");
    print("  help                                            Show this help message\n");
}

Command_Type :: enum {
    NONE;
    HELP;
    PLAY;
    CHECK;
    EXPORT;
    TEST_TONE;
}

Command_Line_Options :: struct {
    command: Command_Type = .NONE;
    song_path: string;
    output_path: string = "output.wav";
    export_stems: bool = false;
    test_tone_duration: float = 1.0;
}

#load "common.jai";
#load "audio/wav_export.jai";
#load "audio/audio_backend.jai";
#load "audio/wasapi.jai";
#load "parser/lexer.jai";
#load "parser/song_model.jai";
#load "parser/parser.jai";
#load "dsp/envelope.jai";
#load "dsp/synth.jai";
#load "dsp/sampler.jai";
#load "dsp/effects.jai";
#load "engine/voice_manager.jai";
#load "engine/mixer.jai";
#load "engine/sequencer.jai";
#load "hot_reload/watcher.jai";
#load "terminal/interactive.jai";

#import "Basic";
#import "Math";
#import "File";
#import "Windows";
#import "Thread";
#import "Atomics";
