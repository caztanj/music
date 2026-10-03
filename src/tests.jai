main :: () {
    common_tests();
    wav_export_tests();
    audio_backend_tests();
    lexer_tests();
    song_model_tests();
    parser_tests();
    envelope_tests();
    synth_tests();
    sampler_tests();
    voice_manager_tests();
    effects_tests();
    mixer_tests();
    sequencer_tests();
    watcher_tests();
    interactive_tests();

    print("% passed, % failed\n", tests_passed, tests_failed);

    if tests_failed > 0 {
        exit(1);
    }
}

test :: (name: string, test_function: () -> ()) {
    print("%\n", name);
    current_test_failed = false;
    test_function();

    if current_test_failed {
        tests_failed += 1;
    } else {
        tests_passed += 1;
    }
}

expect_equals :: (actual: $T, expected: T, location := #caller_location) {
    if actual != expected {
        current_test_failed = true;
        print("  FAILED at line %: expected %, got %\n", location.line_number, expected, actual);
    }
}

expect_near :: (actual: float, expected: float, tolerance: float = 0.001, location := #caller_location) {
    difference := abs(actual - expected);
    if difference > tolerance {
        current_test_failed = true;
        print("  FAILED at line %: expected % (~%), got %\n", location.line_number, expected, tolerance, actual);
    }
}

expect_true :: (condition: bool, location := #caller_location) {
    if !condition {
        current_test_failed = true;
        print("  FAILED at line %\n", location.line_number);
    }
}

tests_passed := 0;
tests_failed := 0;
current_test_failed := false;

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
#load "tests/common_tests.jai";
#load "audio/tests/wav_export_tests.jai";
#load "audio/tests/audio_backend_tests.jai";
#load "parser/tests/lexer_tests.jai";
#load "parser/tests/song_model_tests.jai";
#load "parser/tests/parser_tests.jai";
#load "dsp/tests/envelope_tests.jai";
#load "dsp/tests/synth_tests.jai";
#load "dsp/tests/sampler_tests.jai";
#load "dsp/tests/effects_tests.jai";
#load "engine/tests/voice_manager_tests.jai";
#load "engine/tests/mixer_tests.jai";
#load "engine/tests/sequencer_tests.jai";
#load "hot_reload/watcher.jai";
#load "hot_reload/tests/watcher_tests.jai";
#load "terminal/interactive.jai";
#load "terminal/tests/interactive_tests.jai";

#import "Basic";
#import "Math";
#import "File";
#import "Windows";
#import "Thread";
#import "Atomics";
