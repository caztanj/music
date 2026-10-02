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
