# TODO.md - Implementation Roadmap & Task Tracker

| Phase | Milestone | Primary Deliverable | Status |
|---|---|---|:---:|
| **Phase 1** | Project Scaffolding | Base layout, compilation setup, CLI skeleton | 🟢 Complete |
| **Phase 2** | Audio Output & WAV Pipeline | WAV file writer & real-time audio playback | 🟢 Complete |
| **Phase 3** | Text Specification & Parser | Lexer, AST, parser & diagnostic error messages | 🟢 Complete |
| **Phase 4** | DSP & Voice Engine | Sampler (resampling), Synth (oscillators, ADSR, filter) | ⚪ Not Started |

| **Phase 5** | Mixer & Insert Effects | Mixer channels, panning, delay line & master limiter | ⚪ Not Started |
| **Phase 6** | Sequencer & Clock | Integer sample clock, pattern triggers, playlist scheduler | ⚪ Not Started |
| **Phase 7** | Hot Reloading Engine | File watcher & lock-free hot swap of song state | ⚪ Not Started |
| **Phase 8** | CLI & Terminal UX | Playback controls, ASCII timeline & level meters | ⚪ Not Started |
| **Phase 9** | Demo Songs & Verification | Standard drum samples, demo songs & integration tests | ⚪ Not Started |

---

## Phase 1: Environment & Project Scaffolding

> **Goal**: Establish the repository structure, compilation workflow, shared utilities, and initial CLI argument handling.

- [x] **1.1 Directory Layout**
  - [x] Initialize source tree: `src/audio/`, `src/parser/`, `src/dsp/`, `src/engine/`, `src/hot_reload/`.
  - [x] Initialize content directories: `samples/`, `songs/`.
- [x] **1.2 Compilation Setup**
  - [x] Standard compile invocation: `jai src/main.jai -exe music_engine`.
  - [x] Support release / optimized builds via `-release`.
- [x] **1.3 Common Library (`src/common.jai`)**
  - [x] Define core numeric types, timing constants, and units.
  - [x] Implement audio conversion helpers:
    - Linear gain to decibels (`linear_to_decibels`) and decibels to linear gain (`decibels_to_linear`).
    - Note name to MIDI number (e.g. `"C4"` -> 60).
    - MIDI number to frequency in Hertz (`midi_to_hertz`).
- [x] **1.4 CLI Entry Point (`src/main.jai`)**
  - [x] Parse subcommands: `play <file>`, `export <file> -o <out.wav>`, `check <file>`.
  - [x] Implement `--help` screen and graceful exit codes.

**Acceptance Criteria**: Running `jai src/main.jai -exe music_engine` produces `music_engine.exe`, and `./music_engine.exe --help` displays command options cleanly.

---

## Phase 2: Audio Output & WAV Pipeline

> **Goal**: Establish the two audio output sinks: offline rendering to disk and real-time buffer streaming to speakers.

- [x] **2.1 Offline WAV Exporter (`src/audio/wav_export.jai`)**
  - [x] Implement standard RIFF/WAVE header serializer.
  - [x] Support 32-bit IEEE float stereo output (default).
  - [x] Support 16-bit PCM integer stereo output with dithering / clipping protection.
  - [x] Verify export output opens and plays cleanly in Windows Media Player and VLC.
- [x] **2.2 Real-Time Audio Output Backend (`src/audio/audio_backend.jai`)**
  - [x] Implement low-latency audio stream using native WASAPI from scratch (no external audio libraries).
  - [x] Setup high-priority audio callback supplying interleaved `float32` frames.
  - [x] Provide buffer size selection (default: 512 samples / ~11.6 ms at 44.1 kHz).
- [x] **2.3 Audio Sanity Harness**
  - [x] Write a 440 Hz stereo sine wave generator test to verify glitch-free real-time audio.

**Acceptance Criteria**: Running a test command plays a clean 440 Hz test tone through speakers without crackling, and an offline test writes a valid `.wav` file.

---

## Phase 3: Text Specification, Lexer & Parser

> **Goal**: Read `.song` files and transform them into a fully validated in-memory domain model (`SongState`).

- [x] **3.1 Lexer (`src/parser/lexer.jai`)**
  - [x] Implement token scanner with source location tracking (`line`, `col`).
  - [x] Support tokens: headers (`[section]`), identifiers, literals (int, float, string), operators (`=`, `:`, `->`, `|`), step symbols (`x`, `.`).
  - [x] Support line comments (`#` and `//`).
- [x] **3.2 AST & Domain Model (`src/parser/song_model.jai`)**
  - [x] `Project_Configuration`: BPM, time signature, bar count.
  - [x] `Instrument_Definition`: Sampler configuration (path, gain, root note) or Synth configuration (waveform, filter, envelope).
  - [x] `Pattern_Definition`: Step-sequencer grid tracks or piano-roll note lists.
  - [x] `Mixer_Definition`: Track strips, volume, pan, delay sends, master limiter configuration.
  - [x] `Routing_Definition`: Instrument-to-mixer track channel mappings.
  - [x] `Arrangement_Definition`: Timeline clips mapping bar ranges to patterns.

- [x] **3.3 Parser & Diagnostics (`src/parser/parser.jai`)**
  - [x] Section-by-section parser with descriptive errors pointing to line and column.
  - [x] Semantic verification:
    - [x] Check that patterns in `[arrangement]` exist in `[pattern]`.
    - [x] Check that instruments in `[channel_routing]` exist in `[instruments]`.
    - [x] Check that sample WAV files exist on disk before completing parse.


**Acceptance Criteria**: `music_engine check file.song` reports exact file, line, and column for syntax errors, or returns success on valid files.

---

## Phase 4: DSP Primitives & Voice Engine

> **Goal**: Build all sound generation components (sampler, synthesizers, filters, envelopes) and the voice allocator.

- [ ] **4.1 Envelope Generator (`src/dsp/envelope.jai`)**
  - [ ] Implement ADSR state machine (Attack, Decay, Sustain, Release) computed in sample counts.
  - [ ] Exponential release curve to prevent abrupt cutoff clicks.
- [ ] **4.2 Synthesizer Voice (`src/dsp/synth.jai`)**
  - [ ] Polyphonic oscillator bank: Sawtooth, Square / Pulse, Sine, and Triangle waveforms.
  - [ ] Resonant Biquad Filter (Lowpass, Highpass, Bandpass).
  - [ ] Envelope modulation connected to amplifier and filter cutoff.
- [ ] **4.3 Audio Sampler Engine (`src/dsp/sampler.jai`)**
  - [ ] In-memory PCM audio buffer storage.
  - [ ] Linear interpolation resampling for variable-pitch playback.
  - [ ] One-shot trigger mode for drum hits.
- [ ] **4.4 Voice Manager (`src/engine/voice_manager.jai`)**
  - [ ] Pre-allocated pool of 64–128 concurrent active voices.
  - [ ] Deterministic voice stealing (steals released voices first, then lowest velocity/gain).
  - [ ] Zero heap allocations during voice activation or rendering.

**Acceptance Criteria**: The voice manager can trigger multiple simultaneous synth notes and drum samples without dropouts or allocations.

---

## Phase 5: Mixer & DSP Effects

> **Goal**: Route polyphonic voice outputs through dedicated channel strips, apply insert effects, and master the mix.

- [ ] **5.1 Channel Strips (`src/engine/mixer.jai`)**
  - [ ] Pre-allocated array of mixer channels (e.g. 16 tracks + Master bus).
  - [ ] Per-channel Volume Gain (0.0 till 2.0) and Stereo Pan (-1.0 till +1.0).
  - [ ] Channel Mute and Solo toggles.
- [ ] **5.2 Insert Effects (`src/dsp/effects.jai`)**
  - [ ] Stereo Delay: Tempo-synced (e.g. 1/4 note, 1/8 note) with feedback and dry/wet blend.
  - [ ] Resonant Filter Insert: 12 dB / octave lowpass/highpass sweepable filter.
- [ ] **5.3 Master Bus & Safety Limiter**
  - [ ] Fast lookahead or soft-knee saturation curve on the master bus.
  - [ ] Hard ceiling at -0.1 dBFS to eliminate digital clipping and protect speakers.

**Acceptance Criteria**: Audio routed across multiple mixer tracks sums cleanly without distortion or clipping.

---

## Phase 6: Sequencer & Clock Engine

> **Goal**: Accurate sample-level scheduling of bars, beats, pattern steps, and timeline arrangements.

- [ ] **6.1 Clock & Timekeeper (`src/engine/sequencer.jai`)**
  - [ ] Store playhead as a 64-bit unsigned integer (`u64 current_sample`).
  - [ ] Compute `samples_per_beat = (sample_rate * 60) / bpm`.
  - [ ] Compute `samples_per_step = samples_per_beat / 4` (for 16th notes).
- [ ] **6.2 Pattern Sequencer**
  - [ ] Evaluate 16-step grid hits (`x . . . x . . .`) and trigger note-on events.
  - [ ] Evaluate piano-roll notes with specific lengths and note-off events.
- [ ] **6.3 Arrangement Player**
  - [ ] Map global bar positions to active patterns.
  - [ ] Seamless timeline looping between `bar 1` and `bar N`.
  - [ ] Accurate sub-buffer event scheduling (sample offsets inside the current audio block).

**Acceptance Criteria**: A multi-bar drum and melody sequence loops with zero audible drift over extended playback.

---

## Phase 7: Hot Reloading Engine

> **Goal**: Instant hot reloading of `.song` files upon save without interrupting playback or causing audio glitches.

- [ ] **7.1 File Watcher Thread (`src/hot_reload/watcher.jai`)**
  - [ ] Monitor loaded `.song` file timestamp / change notifications.
  - [ ] Debounce multiple quick editor writes (50–100 ms debounce).
- [ ] **7.2 Lock-Free State Swap**
  - [ ] Parse updated text in the watcher thread into a candidate `SongState`.
  - [ ] If syntax errors occur, print diagnostic error to console without stopping playback.
  - [ ] If parse succeeds, perform an atomic pointer swap to replace the active song state.
  - [ ] Retain active voices smoothly during the transition.

**Acceptance Criteria**: Modifying a pattern or tempo in a text editor and saving instantly updates playback within 100 ms without audio pops.

---

## Phase 8: CLI Interface & Terminal UX

> **Goal**: Interactive, readable terminal interface during playback.

- [ ] **8.1 Interactive Controls**
  - [ ] Keybinding listener:
    - `Space`: Pause / Play.
    - `R`: Rewind to Bar 1.
    - `M`: Toggle Mixer track view.
    - `Q` / `Esc`: Clean shutdown.
- [ ] **8.2 Terminal Display**
  - [ ] Live status line: `[PLAYING] Bar: 04.2 | BPM: 128 | CPU: 1.2% | Voices: 8/64`.
  - [ ] Visual ASCII VU meters for Master L/R output levels.

**Acceptance Criteria**: The terminal displays real-time playback position and responds to keyboard commands smoothly.

---

## Phase 9: Demo Songs, Assets & Verification

> **Goal**: Provide out-of-the-box playable songs and verify end-to-end functionality.

- [ ] **9.1 Sample Kit (`samples/`)**
  - [ ] Bundle standard clean 44.1 kHz WAV samples: `kick.wav`, `snare.wav`, `hihat.wav`, `clap.wav`.
- [ ] **9.2 Demo Song Files (`songs/`)**
  - [ ] `songs/drums.song`: 4-bar drum loop demonstrating step sequencer grids.
  - [ ] `songs/synth_lead.song`: Melodic piano-roll notation with synth filter envelope and delay.
  - [ ] `songs/full_demo.song`: Multi-instrument track with intro, drop, and complete arrangement.
- [ ] **9.3 End-to-End Validation**
  - [ ] Verify offline export generates byte-identical audio outputs given identical inputs.
  - [ ] Verify real-time playback matches exported WAV file exactly.
  - [ ] Verify hot reloading of `.song` files provides instant audio update without glitches.
