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
            print("Playing %\n", options.song_path);

        case .CHECK;
            print("Checking %\n", options.song_path);

        case .EXPORT;
            print("Exporting % to %\n", options.song_path, options.output_path);

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

        argument_index := 3;
        while argument_index < arguments.count {
            if arguments[argument_index] == "-o" && argument_index + 1 < arguments.count {
                options.output_path = arguments[argument_index + 1];
                argument_index += 2;
            } else {
                argument_index += 1;
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
    print("  play <file.song>                 Play a song file with hot reloading\n");
    print("  export <file.song> -o <out.wav>  Export a song file to WAV\n");
    print("  check <file.song>                Validate a song file syntax\n");
    print("  help                             Show this help message\n");
}

Command_Type :: enum {
    NONE;
    HELP;
    PLAY;
    CHECK;
    EXPORT;
}

Command_Line_Options :: struct {
    command: Command_Type = .NONE;
    song_path: string;
    output_path: string = "output.wav";
}

#load "common.jai";
#load "audio/wav_export.jai";

#import "Basic";
#import "Math";
#import "File";
