# AGENT.md - Text-Driven Music Engine (DAW)

| Attribute | Specification |
|---|---|
| **Project Name** | Text DAW / Music Engine |
| **Language** | Jai |
| **Platform Architecture** | Cross-platform (Windows x64 via native WASAPI, with future Linux & macOS support; all built from scratch without third-party audio libraries) |
| **Format** | Plaintext `.song` specification (FL Studio mental model) |
| **Primary Output** | Real-time audio stream (low latency) + Offline 32-bit float WAV exporter |

---

## 1. Executive Summary & Philosophy

This project is a lightweight, high-performance, text-specified music sequencer and audio engine. It adopts the core workflow paradigms of **FL Studio**—step sequencers, piano rolls, pattern arrangement, mixer channels, samplers, and synthesizers—while replacing the graphical user interface with an expressive, tooling-friendly text format.

### Core Principles
- **Git & Diff Friendly**: Compositions are plain text. Version control tracks melodic edits, mixer balance changes, and structure diffs cleanly.
- **Machine & Tooling Interop**: Scripts (Python, AI generators, CLI macros) can easily parse, generate, or mutate songs.
- **Deterministic & Sample-Accurate**: Playback timing is calculated strictly in discrete audio sample counts (`u64`), avoiding float accumulation drift.
- **Zero Real-Time Allocation**: The audio rendering thread guarantees bounded execution time with zero heap allocations, zero system I/O, and zero mutex locks.
- **Seamless Hot Reloading**: Save the file in any text editor, and the engine reloads the state instantaneously without stopping audio or introducing audible clicks.
- **Cross-Platform & Dependency-Free**: Architected for multi-platform support (Windows, Linux, macOS). Platform backends are implemented from scratch using native OS APIs directly without third-party audio libraries. The core engine, DSP, sequencer, and parser remain strictly platform-independent.

---

## 2. System Architecture

```
 ┌─────────────────────────────────────────────────────────────────────────┐
 │                               MAIN THREAD                               │
 │                                                                         │
 │  ┌─────────────────┐       ┌─────────────────┐      ┌────────────────┐  │
 │  │ File Watcher    │──────▶│ Lexer & Parser  │─────▶│ SongState (AST)│  │
 │  │ (.song changes) │       │ (with diagnostics)     │ (Pre-validated)│  │
 │  └─────────────────┘       └─────────────────┘      └───────┬────────┘  │
 └─────────────────────────────────────────────────────────────┼───────────┘
                                                               │ Lock-Free Pointer Swap
                                                               ▼
 ┌─────────────────────────────────────────────────────────────────────────┐
 │                           AUDIO ENGINE THREAD                           │
 │                                                                         │
 │   ┌────────────────────────┐              ┌──────────────────────────┐  │
 │   │    Sequencer Clock     │              │      Voice Manager       │  │
 │   │ - Integer Sample Clock │  Note On/Off │ - 64-128 Pre-allocated   │  │
 │   │ - Arrangement Tracker  │─────────────▶│ - Sampler (Resampling)   │  │
 │   │ - Pattern Step Trigger │              │ - Subtractive Synth      │  │
 │   └────────────────────────┘              └─────────────┬────────────┘  │
 │                                                         │ Audio Streams │
 │                                                         ▼               │
 │                                           ┌──────────────────────────┐  │
 │                                           │       Mixer Engine       │  │
 │                                           │ - Track Strips (Gain/Pan)│  │
 │                                           │ - Insert DSP (Delay/EQ)  │  │
 │                                           │ - Master Bus + Limiter   │  │
 │                                           └─────────────┬────────────┘  │
 └─────────────────────────────────────────────────────────┼───────────────┘
                                                           │ Stereo Float32
                                                           ▼
                                             ┌──────────────────────────┐
                                             │ Output Sink              │
                                             │ - WASAPI / Audio Device  │
                                             │ - Offline WAV Exporter   │
                                             └──────────────────────────┘
```

---

## 3. Real-Time Audio Thread Constraints

> [!IMPORTANT]
> The audio callback runs under high/real-time OS priority. Failing to follow these rules results in audio glitches, buffer underruns, or deadlocks.

| Constraint | Rule | Solution / Implementation |
|---|---|---|
| **No Dynamic Allocations** | Never call `alloc`, `New`, or dynamic array growth inside audio routines. | Pre-allocate fixed buffers and static voice pools during initialization. |
| **No Mutex Locks** | Never acquire blocking locks in the callback. | Use atomic pointer swaps (`atomic_swap`) or triple-buffering for state swaps. |
| **No Filesystem / OS I/O** | Never load audio samples or read files on the audio thread. | Pre-decode all WAV sample files into memory during the parse phase. |
| **Sanitized Math** | Prevent infinite loops, denormal floats, and NaN propagation. | Clamp DSP calculations; flush denormals or add microscopic DC bias if needed. |

---

## 4. The `.song` Format Specification

A `.song` file is composed of declarative sections enclosed in brackets `[...]`.

### 4.1 Section Reference

| Section | Purpose | Example Parameters / Syntax |
|---|---|---|
| `[project]` | Song metadata, tempo, and timeline bounds. | `name = "Track"`, `bpm = 120`, `time_signature = 4/4`, `bars = 32` |
| `[instruments]` | Declares synth engines and audio samplers. | `kick = sampler("samples/kick.wav")`, `lead = synth(wave="saw")` |
| `[pattern <name>]` | Grid-based step sequencer or piano roll events. | Step grid (`x . . .`) or tracker notation (`C4 step=0 len=2`) |
| `[mixer]` | Channel strips, track routing, gain, and effects. | `track 1 (drums): gain = 0.9, pan = 0.0`, `master: limiter = on` |
| `[channel_routing]`| Maps declared instruments to mixer channel strips. | `kick -> track 1`, `lead -> track 2` |
| `[arrangement]` | Schedules patterns across timeline bars (playlist). | `bar 1-8: drums_a`, `bar 5-16: lead_hook` |

---

### 4.2 Comprehensive `.song` Example

```ini
[project]
name           = "Neon Horizon"
bpm            = 128
time_signature = 4/4
bars           = 16

[instruments]
# Samplers: WAV samples loaded into memory
kick   = sampler("samples/kick.wav", gain = 1.0)
snare  = sampler("samples/snare.wav", gain = 0.85)
hat    = sampler("samples/hat.wav", gain = 0.70)

# Synthesizers: Parametric subtractive synth
bass   = synth(wave="saw", filter="lowpass", cutoff=600, res=0.2, attack=5, decay=60, sustain=0.4, release=100)
lead   = synth(wave="square", filter="lowpass", cutoff=1800, res=0.4, attack=10, decay=120, sustain=0.6, release=200)

[pattern drums_main]
# 16-step grid per bar (FL Studio step sequencer style)
# '.' = rest, 'x' or 'X' = standard hit, letters/digits allow velocity variations
kick   | x . . . x . . . x . . . x . . . |
snare  | . . . . x . . . . . . . x . . . |
hat    | x . x . x . x . x . x . x . x . |

[pattern bass_loop]
# Piano roll notation: [Note] step=[0-15] len=[steps] vel=[0.0-1.0]
C2   step=0   len=2  vel=0.9
C2   step=3   len=1  vel=0.8
Eb2  step=6   len=2  vel=0.9
F2   step=10  len=2  vel=0.85
G2   step=14  len=2  vel=0.95

[pattern lead_hook]
C4   step=0   len=2  vel=0.85
G4   step=4   len=2  vel=0.80
Bb4  step=8   len=4  vel=0.90
C5   step=12  len=4  vel=1.00

[mixer]
track 1 (drums):  gain = 0.95, pan =  0.0, output = master
track 2 (bass):   gain = 0.85, pan =  0.0, output = master
track 3 (lead):   gain = 0.75, pan =  0.15, delay = 0.25, feedback = 0.35, output = master
master:           gain = 1.00, limiter = on, ceiling = -0.2db

[channel_routing]
kick  -> track 1
snare -> track 1
hat   -> track 1
bass  -> track 2
lead  -> track 3

[arrangement]
# Playlist timeline mapping bar ranges to patterns
bar 1-8:   drums_main
bar 1-8:   bass_loop
bar 5-12:  lead_hook
bar 9-16:  drums_main
bar 9-16:  bass_loop
```

---

## 5. Directory Layout

```
c:/Kod/Music/
│
├── AGENT.md                       # Architectural documentation & guidelines
├── TODO.md                        # Master task list & milestone tracker
│
├── src/
│   ├── main.jai                   # Entry point, CLI dispatcher & repl
│   ├── tests.jai                  # Test suite runner entry point
│   ├── common.jai                 # Global types, units, dB conversions, math
│   ├── tests/                     # Tests for root-level modules (e.g. common_tests.jai)
│   │
│   ├── parser/
│   │   ├── lexer.jai              # Tokenizer with line & column tracking
│   │   ├── parser.jai             # Section-based parser & semantic validator
│   │   ├── song_model.jai         # In-memory song representation (AST)
│   │   └── tests/                 # Parser unit tests
│   │
│   ├── audio/
│   │   ├── audio_backend.jai      # Unified OS-agnostic audio backend interface
│   │   ├── wasapi.jai             # Native Windows WASAPI implementation from scratch
│   │   ├── wav_export.jai         # Offline 32-bit float / 16-bit PCM exporter
│   │   ├── buffer.jai             # Interleaved audio buffer utilities
│   │   └── tests/                 # Audio & WAV tests (e.g. wav_export_tests.jai)
│   │
│   ├── engine/
│   │   ├── sequencer.jai          # Sample-accurate clock & pattern runner
│   │   ├── voice_manager.jai      # Voice pool, polyphony, voice stealing
│   │   ├── mixer.jai              # Channel strips, bus summing, volume & pan
│   │   └── tests/                 # Engine & sequencer tests
│   │
│   ├── dsp/
│   │   ├── synth.jai              # Oscillators (Saw, Pulse, Sine, Triangle)
│   │   ├── sampler.jai            # Resampling audio sample playback
│   │   ├── envelope.jai           # ADSR envelope state machine
│   │   ├── effects.jai            # Delay line, Biquad filter, Limiter
│   │   └── tests/                 # DSP unit tests
│   │
│   └── hot_reload/
│       └── watcher.jai            # Background file watcher for hot reloading
│
├── samples/                       # Drum & instrument WAV samples
└── songs/                         # User .song compositions
```

---

## 6. Build & Usage Guide

### 6.1 Compiling
From the project root:
```powershell
# Build application:
jai src/main.jai -exe music_engine

# Build test suite:
jai src/tests.jai -exe music_tests
```

### 6.2 Running Tests
```powershell
.\src\music_tests.exe
```

### 6.2 CLI Commands

| Command | Description |
|---|---|
| `music_engine play <file.song>` | Launches real-time playback with hot reloading enabled. |
| `music_engine export <file.song> -o <out.wav>` | Renders composition offline to a pristine 32-bit float WAV file at maximum CPU speed. |
| `music_engine check <file.song>` | Validates syntax, references, and missing samples without starting audio. |

### 6.3 Interactive Playback Controls
While `play` mode is running in the terminal:
- **`Space`**: Pause / Resume.
- **`R`**: Rewind to beginning.
- **`M`**: Cycle channel mute/solo view.
- **`Q` / `Esc`**: Exit playback cleanly.

---

## 7. Developer & Agent Guidelines

1. **Error Diagnostics**:
   Always include `(filename, line, column)` in parser error outputs so users can jump directly to syntax mistakes.
2. **DSP Integrity**:
   Always wrap master audio output with soft-clipping / limiting to protect ears and speakers from uninitialized float bursts or mathematical explosions (NaN, inf).
3. **Jai Language Idioms**:
   - File element order (top-to-bottom):
     1. `main` procedure (if present)
     2. All other procedures
     3. Global variables
     4. Global constants (and structs/enums)
     5. `#load` directives (only in `main.jai` and `tests.jai`)
     6. (blank line)
     7. `#import` directives (only in `main.jai` and `tests.jai`)
   - `#load` and `#import` directives are ONLY permitted in `main.jai` and in `tests.jai`. No other source files may contain `#load` or `#import`.
   - Prefer structs with explicit initialization defaults.
   - Use Jai `#run` directives for compile-time lookup tables (e.g. note-to-frequency tables).
   - Use explicit pointer passes (`*Type`) for mutable data structures.
   - In `if-case` / `switch` blocks, place the body of each `case` indented on the line below the `case` label, with a blank line before every new `case` statement.
   - Include a blank line before the final `return` in a function if the function is 3 lines or longer.
4. **Testing Architecture**:
   - Any folder may contain a `tests/` subfolder with dedicated test files.
   - Tests use vitest-like syntax: `test("description", () { ... });` inside a suite procedure (e.g. `common_tests :: () { ... }`).
   - Use `expect_equals(actual, expected)`, `expect_near(actual, expected, tolerance)`, and `expect_true(condition)` instead of standard `assert` so that tests report failures with line numbers and continue running.
   - `src/tests.jai` loads test suites and executes them, printing each test name and reporting `% passed, % failed` at the end.
5. **No Comments**:
   - Never write comments in code. Keep code completely clean and free of comments.
6. **No Abbreviations**:
   - Never use abbreviations for identifiers, variables, functions, or parameters (e.g. use `Command_Line` instead of `Cli`, `arguments` instead of `args`, `command` instead of `cmd`, `decibels` instead of `db`, `test_function` instead of `fn`, `location` instead of `loc`, `difference` instead of `diff`, `hertz` instead of `hz`). Write all names in full.
7. **Cross-Platform Architecture & No External Audio Libraries**:
   - The engine is designed for multi-platform portability (Windows, Linux, macOS).
   - Audio backends must be implemented from scratch using native OS APIs directly (e.g. WASAPI on Windows via COM vtables, ALSA/PipeWire on Linux, CoreAudio on macOS). Never introduce third-party audio libraries (such as miniaudio, SDL, or PortAudio).
   - `audio_backend.jai` provides the common platform-agnostic interface (`Audio_Backend`, `Audio_Configuration`, `Audio_Callback`), delegating to platform-specific implementations.
   - Core music logic, DSP algorithms, mixer channels, and sequencer timekeeping must remain 100% platform-independent.
