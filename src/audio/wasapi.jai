wasapi_initialize :: (state: *Wasapi_State, configuration: Audio_Configuration, callback: Audio_Callback, user_data: *void) -> bool {
    state.channel_count = configuration.channel_count;
    state.sample_rate = configuration.sample_rate;
    state.callback = callback;
    state.user_data = user_data;
    state.is_thread_running = false;

    co_initialize_result := CoInitializeEx(null, 0);

    clsid_device_enumerator := uid(CLSID_MM_DEVICE_ENUMERATOR);
    iid_device_enumerator := uid(IID_IMM_DEVICE_ENUMERATOR);

    device_enumerator_pointer: *void = null;
    create_enumerator_result := CoCreateInstance(*clsid_device_enumerator, null, 1, *iid_device_enumerator, *device_enumerator_pointer);
    if create_enumerator_result != 0 || device_enumerator_pointer == null {
        return false;
    }

    state.device_enumerator = cast(*IMMDeviceEnumerator) device_enumerator_pointer;

    get_endpoint_result := state.device_enumerator.vtable.GetDefaultAudioEndpoint(state.device_enumerator, 0, 0, *state.device);
    if get_endpoint_result != 0 || state.device == null {
        wasapi_shutdown(state);
        return false;
    }

    iid_audio_client := uid(IID_I_AUDIO_CLIENT);
    audio_client_pointer: *void = null;
    activate_result := state.device.vtable.Activate(state.device, *iid_audio_client, 1, null, *audio_client_pointer);
    if activate_result != 0 || audio_client_pointer == null {
        wasapi_shutdown(state);
        return false;
    }

    state.audio_client = cast(*IAudioClient) audio_client_pointer;

    format: Wave_Format_Extensible;
    format.format.format_tag = cast(s16) 0xFFFE;
    format.format.channel_count = cast(s16) configuration.channel_count;
    format.format.samples_per_second = cast(s32) configuration.sample_rate;
    format.format.bits_per_sample = 32;
    format.format.block_align = cast(s16) (configuration.channel_count * 4);
    format.format.average_bytes_per_second = cast(s32) (configuration.sample_rate * configuration.channel_count * 4);
    format.format.extra_size = 22;
    format.valid_bits_per_sample = 32;
    format.channel_mask = 3;
    format.sub_format = uid(SUBTYPE_IEEE_FLOAT);

    buffer_duration_in_hundred_nanoseconds := cast(s64) ((cast(s64) configuration.buffer_size_in_frames * 10000000) / cast(s64) configuration.sample_rate);

    stream_flags: DWORD = 0x00040000 | 0x80000000 | 0x08000000;
    initialize_result := state.audio_client.vtable.Initialize(state.audio_client, 0, stream_flags, buffer_duration_in_hundred_nanoseconds, 0, cast(*Wave_Format_Ex) *format, null);

    if initialize_result != 0 {
        mix_format_pointer: *Wave_Format_Ex = null;
        get_mix_format_result := state.audio_client.vtable.GetMixFormat(state.audio_client, *mix_format_pointer);
        if get_mix_format_result != 0 || mix_format_pointer == null {
            wasapi_shutdown(state);
            return false;
        }

        defer CoTaskMemFree(mix_format_pointer);

        state.channel_count = mix_format_pointer.channel_count;
        state.sample_rate = mix_format_pointer.samples_per_second;

        fallback_duration := cast(s64) ((cast(s64) configuration.buffer_size_in_frames * 10000000) / cast(s64) state.sample_rate);
        initialize_result = state.audio_client.vtable.Initialize(state.audio_client, 0, 0x00040000, fallback_duration, 0, mix_format_pointer, null);
        if initialize_result != 0 {
            wasapi_shutdown(state);
            return false;
        }
    }

    state.audio_event_handle = CreateEventW(null, 0, 0, null);
    if state.audio_event_handle == null {
        wasapi_shutdown(state);
        return false;
    }

    set_event_result := state.audio_client.vtable.SetEventHandle(state.audio_client, state.audio_event_handle);
    if set_event_result != 0 {
        wasapi_shutdown(state);
        return false;
    }

    get_buffer_size_result := state.audio_client.vtable.GetBufferSize(state.audio_client, *state.buffer_frame_count);
    if get_buffer_size_result != 0 {
        wasapi_shutdown(state);
        return false;
    }

    iid_audio_render_client := uid(IID_I_AUDIO_RENDER_CLIENT);
    render_client_pointer: *void = null;
    get_service_result := state.audio_client.vtable.GetService(state.audio_client, *iid_audio_render_client, *render_client_pointer);
    if get_service_result != 0 || render_client_pointer == null {
        wasapi_shutdown(state);
        return false;
    }

    state.audio_render_client = cast(*IAudioRenderClient) render_client_pointer;

    thread_init(*state.audio_thread, wasapi_audio_thread_procedure);
    state.audio_thread.data = state;

    return true;
}

wasapi_start :: (state: *Wasapi_State) -> bool {
    if state.is_thread_running {
        return true;
    }

    start_client_result := state.audio_client.vtable.Start(state.audio_client);
    if start_client_result != 0 {
        return false;
    }

    state.is_thread_running = true;
    thread_start(*state.audio_thread);

    return true;
}

wasapi_stop :: (state: *Wasapi_State) -> bool {
    if !state.is_thread_running {
        return true;
    }

    state.is_thread_running = false;
    SetEvent(state.audio_event_handle);

    thread_is_done(*state.audio_thread, 2000);
    thread_deinit(*state.audio_thread);

    state.audio_client.vtable.Stop(state.audio_client);
    state.audio_client.vtable.Reset(state.audio_client);

    return true;
}

wasapi_shutdown :: (state: *Wasapi_State) {
    if state.is_thread_running {
        wasapi_stop(state);
    }

    if state.audio_render_client != null {
        state.audio_render_client.vtable.Release(state.audio_render_client);
        state.audio_render_client = null;
    }

    if state.audio_client != null {
        state.audio_client.vtable.Release(state.audio_client);
        state.audio_client = null;
    }

    if state.device != null {
        state.device.vtable.Release(state.device);
        state.device = null;
    }

    if state.device_enumerator != null {
        state.device_enumerator.vtable.Release(state.device_enumerator);
        state.device_enumerator = null;
    }

    if state.audio_event_handle != null {
        CloseHandle(state.audio_event_handle);
        state.audio_event_handle = null;
    }

    CoUninitialize();
}

wasapi_audio_thread_procedure :: (thread: *Thread) -> s64 {
    state := cast(*Wasapi_State) thread.data;

    SetThreadPriority(GetCurrentThread(), 15);

    while state.is_thread_running {
        wait_result := WaitForSingleObject(state.audio_event_handle, 2000);
        if !state.is_thread_running {
            break;
        }

        if wait_result != 0 {
            continue;
        }

        padding_frame_count: u32 = 0;
        padding_result := state.audio_client.vtable.GetCurrentPadding(state.audio_client, *padding_frame_count);
        if padding_result != 0 {
            continue;
        }

        available_frame_count := state.buffer_frame_count - padding_frame_count;
        if available_frame_count <= 0 {
            continue;
        }

        buffer_pointer: *u8 = null;
        get_buffer_result := state.audio_render_client.vtable.GetBuffer(state.audio_render_client, available_frame_count, *buffer_pointer);
        if get_buffer_result != 0 || buffer_pointer == null {
            continue;
        }

        output_samples: [] float;
        output_samples.data = cast(*float) buffer_pointer;
        output_samples.count = available_frame_count * cast(u32) state.channel_count;

        state.callback(output_samples, state.channel_count, state.sample_rate, state.user_data);

        state.audio_render_client.vtable.ReleaseBuffer(state.audio_render_client, available_frame_count, 0);
    }

    return 0;
}

Wasapi_State :: struct {
    device_enumerator: *IMMDeviceEnumerator;
    device: *IMMDevice;
    audio_client: *IAudioClient;
    audio_render_client: *IAudioRenderClient;
    audio_event_handle: HANDLE;
    audio_thread: Thread;
    is_thread_running: bool;
    buffer_frame_count: u32;
    channel_count: int;
    sample_rate: int;
    callback: Audio_Callback;
    user_data: *void;
}

Wave_Format_Ex :: struct {
    format_tag: s16;
    channel_count: s16;
    samples_per_second: s32;
    average_bytes_per_second: s32;
    block_align: s16;
    bits_per_sample: s16;
    extra_size: s16;
} #no_padding;

Wave_Format_Extensible :: struct {
    format: Wave_Format_Ex;
    valid_bits_per_sample: u16;
    channel_mask: u32;
    sub_format: GUID;
} #no_padding;

IMMDeviceEnumerator :: struct {
    vtable: *IMMDeviceEnumerator_VTable;
}

IMMDeviceEnumerator_VTable :: struct {
    QueryInterface: (this: *IMMDeviceEnumerator, interface_identifier: *IID, output_object: **void) -> HRESULT #cpp_method;
    AddRef: (this: *IMMDeviceEnumerator) -> u32 #cpp_method;
    Release: (this: *IMMDeviceEnumerator) -> u32 #cpp_method;
    EnumAudioEndpoints: (this: *IMMDeviceEnumerator, data_flow: s32, state_mask: DWORD, devices: **void) -> HRESULT #cpp_method;
    GetDefaultAudioEndpoint: (this: *IMMDeviceEnumerator, data_flow: s32, role: s32, endpoint: **IMMDevice) -> HRESULT #cpp_method;
    GetDevice: (this: *IMMDeviceEnumerator, string_identifier: *u16, device: **IMMDevice) -> HRESULT #cpp_method;
    RegisterEndpointNotificationCallback: (this: *IMMDeviceEnumerator, client: *void) -> HRESULT #cpp_method;
    UnregisterEndpointNotificationCallback: (this: *IMMDeviceEnumerator, client: *void) -> HRESULT #cpp_method;
}

IMMDevice :: struct {
    vtable: *IMMDevice_VTable;
}

IMMDevice_VTable :: struct {
    QueryInterface: (this: *IMMDevice, interface_identifier: *IID, output_object: **void) -> HRESULT #cpp_method;
    AddRef: (this: *IMMDevice) -> u32 #cpp_method;
    Release: (this: *IMMDevice) -> u32 #cpp_method;
    Activate: (this: *IMMDevice, interface_identifier: *IID, class_context: DWORD, activation_parameters: *void, interface_pointer: **void) -> HRESULT #cpp_method;
    OpenPropertyStore: (this: *IMMDevice, storage_access_mode: DWORD, properties: **void) -> HRESULT #cpp_method;
    GetId: (this: *IMMDevice, string_identifier: **u16) -> HRESULT #cpp_method;
    GetState: (this: *IMMDevice, state: *DWORD) -> HRESULT #cpp_method;
}

IAudioClient :: struct {
    vtable: *IAudioClient_VTable;
}

IAudioClient_VTable :: struct {
    QueryInterface: (this: *IAudioClient, interface_identifier: *IID, output_object: **void) -> HRESULT #cpp_method;
    AddRef: (this: *IAudioClient) -> u32 #cpp_method;
    Release: (this: *IAudioClient) -> u32 #cpp_method;
    Initialize: (this: *IAudioClient, share_mode: s32, stream_flags: DWORD, buffer_duration: s64, periodicity: s64, format: *Wave_Format_Ex, audio_session_guid: *GUID) -> HRESULT #cpp_method;
    GetBufferSize: (this: *IAudioClient, buffer_frame_count: *u32) -> HRESULT #cpp_method;
    GetStreamLatency: (this: *IAudioClient, latency: *s64) -> HRESULT #cpp_method;
    GetCurrentPadding: (this: *IAudioClient, padding_frame_count: *u32) -> HRESULT #cpp_method;
    IsFormatSupported: (this: *IAudioClient, share_mode: s32, format: *Wave_Format_Ex, closest_match: **Wave_Format_Ex) -> HRESULT #cpp_method;
    GetMixFormat: (this: *IAudioClient, device_format: **Wave_Format_Ex) -> HRESULT #cpp_method;
    GetDevicePeriod: (this: *IAudioClient, default_device_period: *s64, minimum_device_period: *s64) -> HRESULT #cpp_method;
    Start: (this: *IAudioClient) -> HRESULT #cpp_method;
    Stop: (this: *IAudioClient) -> HRESULT #cpp_method;
    Reset: (this: *IAudioClient) -> HRESULT #cpp_method;
    SetEventHandle: (this: *IAudioClient, event_handle: HANDLE) -> HRESULT #cpp_method;
    GetService: (this: *IAudioClient, interface_identifier: *IID, service: **void) -> HRESULT #cpp_method;
}

IAudioRenderClient :: struct {
    vtable: *IAudioRenderClient_VTable;
}

IAudioRenderClient_VTable :: struct {
    QueryInterface: (this: *IAudioRenderClient, interface_identifier: *IID, output_object: **void) -> HRESULT #cpp_method;
    AddRef: (this: *IAudioRenderClient) -> u32 #cpp_method;
    Release: (this: *IAudioRenderClient) -> u32 #cpp_method;
    GetBuffer: (this: *IAudioRenderClient, requested_frame_count: u32, data_pointer: **u8) -> HRESULT #cpp_method;
    ReleaseBuffer: (this: *IAudioRenderClient, written_frame_count: u32, flags: DWORD) -> HRESULT #cpp_method;
}

CLSID_MM_DEVICE_ENUMERATOR :: "BCDE0395-E52F-467C-8E3D-C4579291692E";
IID_IMM_DEVICE_ENUMERATOR  :: "A95664D2-9614-4F35-A746-DE8DB63617E6";
IID_I_AUDIO_CLIENT         :: "1CB9AD4C-DBFA-4c32-B178-C2F568A703B2";
IID_I_AUDIO_RENDER_CLIENT  :: "F294AC80-3186-4288-A468-9A83B3D66670";
SUBTYPE_IEEE_FLOAT         :: "00000003-0000-0010-8000-00aa00389b71";

SetEvent :: (handle: HANDLE) -> BOOL #foreign kernel32;

CoInitializeEx :: (reserved: *void, flags: DWORD) -> HRESULT #foreign Ole32;
CoUninitialize :: () -> void #foreign Ole32;
CoCreateInstance :: (class_identifier: *GUID, outer: *IUnknown, class_context: DWORD, interface_identifier: *GUID, output_pointer: **void) -> HRESULT #foreign Ole32;
CoTaskMemFree :: (pointer: *void) -> void #foreign Ole32;

kernel32 :: #library,system "kernel32";
Ole32 :: #library,system "ole32";
