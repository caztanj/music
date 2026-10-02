audio_backend_initialize :: (backend: *Audio_Backend, configuration: Audio_Configuration, callback: Audio_Callback, user_data: *void = null) -> bool {
    backend.configuration = configuration;
    backend.callback = callback;
    backend.user_data = user_data;
    backend.is_running = false;

    success := false;

    #if OS == .WINDOWS {
        success = wasapi_initialize(*backend.wasapi_state, configuration, callback, user_data);
    }

    return success;
}

audio_backend_start :: (backend: *Audio_Backend) -> bool {
    if backend.is_running {
        return true;
    }

    success := false;

    #if OS == .WINDOWS {
        success = wasapi_start(*backend.wasapi_state);
        if success {
            backend.is_running = true;
        }
    }

    return success;
}

audio_backend_stop :: (backend: *Audio_Backend) -> bool {
    if !backend.is_running {
        return true;
    }

    success := false;

    #if OS == .WINDOWS {
        success = wasapi_stop(*backend.wasapi_state);
        if success {
            backend.is_running = false;
        }
    }

    return success;
}

audio_backend_shutdown :: (backend: *Audio_Backend) {
    if backend.is_running {
        audio_backend_stop(backend);
    }

    #if OS == .WINDOWS {
        wasapi_shutdown(*backend.wasapi_state);
    }
}

play_test_tone :: (duration_in_seconds: float = 1.0, frequency: float64 = 440.0, amplitude: float = 0.2) -> bool {
    state: Sine_Tone_State;
    state.frequency = frequency;
    state.amplitude = amplitude;

    configuration: Audio_Configuration;
    backend: Audio_Backend;

    initialize_success := audio_backend_initialize(*backend, configuration, sine_tone_audio_callback, *state);
    if !initialize_success {
        return false;
    }

    start_success := audio_backend_start(*backend);
    if !start_success {
        audio_backend_shutdown(*backend);
        return false;
    }

    sleep_milliseconds(cast(s32) (duration_in_seconds * 1000.0));

    audio_backend_stop(*backend);
    audio_backend_shutdown(*backend);

    return true;
}

sine_tone_audio_callback :: (output_samples: [] float, channel_count: int, sample_rate: int, user_data: *void) {
    state := cast(*Sine_Tone_State) user_data;
    phase_increment := (state.frequency * 6.28318530717958648) / cast(float64) sample_rate;

    sample_index := 0;
    while sample_index < output_samples.count {
        sample_value := cast(float) (sin(state.phase) * cast(float64) state.amplitude);

        channel_index := 0;
        while channel_index < channel_count {
            output_samples[sample_index + channel_index] = sample_value;
            channel_index += 1;
        }

        state.phase += phase_increment;
        if state.phase >= 6.28318530717958648 {
            state.phase -= 6.28318530717958648;
        }

        sample_index += channel_count;
    }
}

Audio_Callback :: #type (output_samples: [] float, channel_count: int, sample_rate: int, user_data: *void);

Audio_Configuration :: struct {
    sample_rate: int = DEFAULT_SAMPLE_RATE;
    channel_count: int = 2;
    buffer_size_in_frames: int = 512;
}

Audio_Backend :: struct {
    configuration: Audio_Configuration;
    callback: Audio_Callback;
    user_data: *void;
    is_running: bool;

    #if OS == .WINDOWS {
        wasapi_state: Wasapi_State;
    }
}

Sine_Tone_State :: struct {
    phase: float64 = 0.0;
    frequency: float64 = 440.0;
    amplitude: float = 0.2;
}
