# TODO.md - Professional Music Production Roadmap

| Phase | Milestone | Primary Deliverable | Status |
|---|---|---|:---:|
| **Phase 10** | Synth Expansion & Modulation | Multi-osc, Unison/Detune, Noise, Filter ADSR & LFOs | 🟡 In Progress |
| **Phase 11** | Studio Effects Suite | Algorithmic Reverb, 3-Band Parametric EQ, Chorus/Flanger | ⬜ Planned |
| **Phase 12** | Dynamics & Sidechain Engine | Compressor with Sidechain Ducking, Aux Send/Return Busses | ⬜ Planned |
| **Phase 13** | Musical Expression & Groove | Swing/Shuffle, Portamento/Glide, Triplets, Velocity Scaling | ⬜ Planned |
| **Phase 14** | Advanced Drum Sampler | Choke Groups, Sampler ADSR, Start Offsets, Reverse Playback | ⬜ Planned |
| **Phase 15** | Automation & Modulation Curves | Timeline Parameter Automation (Sweeps, Risers, Fades) | ⬜ Planned |
| **Phase 16** | Mastering & Multi-Track Stems | LUFS Loudness Metering, Stem Export, TPDF Dither | ⬜ Planned |
| **Phase 17** | Professional Production Showcase | Full-length Multi-minute Songs (Synthwave, Lo-Fi, Club) | ⬜ Planned |

---

## Phase 10: Synth Engine Expansion & Sound Design

> **Goal**: Transform the synthesizer into a versatile, rich sound design engine capable of thick basslines, lush pads, sharp plucks, and aggressive leads.

- [x] **10.1 Dual Oscillators & Noise Generator (`src/dsp/synth.jai`)**
  - [x] Support secondary oscillator with independent waveform, coarse transpose (semitones), and fine tune (cents).
  - [x] Oscillator mix balance (Osc 1 vs Osc 2).
  - [x] White and Pink noise generator for percussion layering, ambient textures, and sound effects.
- [ ] **10.2 Stereo Unison & Hyper-Detune**
  - [ ] Polyphonic voice stacking (2, 4, 8 unison voices per note).
  - [ ] Configurable stereo spread and detune amount for classic "supersaw" leads and wide reese basses.
- [ ] **10.3 Dedicated Filter ADSR Envelope**
  - [ ] Independent 4-stage ADSR envelope controlling filter cutoff frequency over time.
  - [ ] Envelope modulation amount (bipolar: -100% to +100%) for classic synth brass, plucks, and squelchy bass.
- [ ] **10.4 Low Frequency Oscillators (LFOs)**
  - [ ] Dual LFOs with Sine, Triangle, Square, and Random (Sample & Hold) waveforms.
  - [ ] Tempo sync modes (e.g. 1/1, 1/2, 1/4, 1/8, 1/16, triplets) or free Hertz rate.
  - [ ] Mod destination matrix: Pitch (vibrato), Filter Cutoff (wobble/growl), Pan (auto-pan), Volume (tremolo).

**Acceptance Criteria**: The synth produces convincing, rich supersaw chords, punchy plucked basses, and tempo-synced filter wobbles without external processing.

---

## Phase 11: Studio Effects Suite (Reverb, EQ & Modulation)

> **Goal**: Add acoustic depth, spectral balance, and movement to dry instruments so mixes sound deep and polished.

- [ ] **11.1 Algorithmic Studio Reverb (`src/dsp/effects.jai`)**
  - [ ] Schroeder / Feedback Delay Network (FDN) stereo reverb algorithm.
  - [ ] Controls: Room Size, Decay Time, High-Frequency Damping, Pre-Delay, and Dry/Wet balance.
  - [ ] Smooth tail decay without metallic ring or numerical instability.
- [ ] **11.2 3-Band Parametric Channel EQ**
  - [ ] Low Shelf (80–250 Hz) for controlling boominess or boosting sub thump.
  - [ ] Parametric Mid Peak/Notch (200 Hz – 8 kHz) with adjustable Q factor for cutting boxy resonances.
  - [ ] High Shelf (4 kHz – 16 kHz) for air, brilliance, and sheen.
- [ ] **11.3 Chorus & Flanger Insert**
  - [ ] Modulated short delay lines (1–20 ms) with stereo phase offset for spatial widening and lush chorusing.
  - [ ] Depth, Rate, Feedback, and Mix controls.
- [ ] **11.4 Soft Saturation & Overdrive**
  - [ ] Hyperbolic tangent (tanh) and cubic waveshaping saturation for analog warmth, presence, and grit.

**Acceptance Criteria**: Dry synth leads and snare drums gain convincing spatial acoustics and tonal clarity without phase cancellation or clipping.

---

## Phase 12: Dynamics, Sidechain & Aux Bussing

> **Goal**: Professional mix balance, glue, headroom control, and modern dance-floor sidechain pumping.

- [ ] **12.1 Dynamic Peak/RMS Compressor (`src/engine/mixer.jai`, `src/dsp/effects.jai`)**
  - [ ] Threshold (-60 to 0 dB), Ratio (1:1 to 20:1 / $\infty$), Attack time (0.1–100 ms), Release time (10–1000 ms).
  - [ ] Soft-knee transition curve and automated or manual makeup gain.
- [ ] **12.2 Sidechain Ducking Engine**
  - [ ] Allow any mixer track to receive sidechain detection signals from another track (e.g. Kick $\to$ Bass, Kick $\to$ Pads).
  - [ ] Instant envelope follower with adjustable ducking depth and release timing for rhythmic pumping.
- [ ] **12.3 Aux Send / Return Busses**
  - [ ] Dedicated Return tracks (e.g. Aux 1: Master Reverb, Aux 2: Ping-Pong Delay).
  - [ ] Post-fader / Pre-fader send level knobs per mixer channel strip.
  - [ ] Summed send buffers processed concurrently before master bus summing.

**Acceptance Criteria**: Bass and synths cleanly duck whenever the kick hits, freeing up master headroom and creating rhythmic groove.

---

## Phase 13: Musical Expression, Groove & Sequencer Precision

> **Goal**: Break out of mechanical, rigid sequencing into humanized, swinging, expressive musical performances.

- [ ] **13.1 Swing / Shuffle Engine (`src/engine/sequencer.jai`)**
  - [ ] Configurable 16th-note swing amount (50% = straight, 58% = subtle groove, 66% = hard triplet swing, up to 75%).
  - [ ] Global and per-pattern swing settings.
- [ ] **13.2 Portamento / Monophonic Glide**
  - [ ] Smooth exponential pitch glide between overlapping notes in monophonic synth modes.
  - [ ] Configurable glide time in milliseconds or tempo-synced beats (ideal for 808 bass glides and lead melodies).
- [ ] **13.3 Triplets & Micro-timing Subdivisions**
  - [ ] Support for 8th, 16th, and 32nd note triplets in step grids and piano rolls (e.g. `t1`, `t2`, `t3`).
  - [ ] Micro-step tick offsets for humanized timing and strumming emulation.
- [ ] **13.4 Velocity Mapping & Dynamics**
  - [ ] Note velocity dynamically scaling synth filter envelope depth, resonance, and amplifier gain.
  - [ ] Ghost notes and accent markers in pattern definitions.

**Acceptance Criteria**: Drum loops swing naturally with classic MPC-style shuffle, and synth bass lines glide fluidly between notes.

---

## Phase 14: Advanced Drum Sampler Engine

> **Goal**: Turn the sampler into a full-featured drum and instrument playback workstation.

- [ ] **14.1 Choke Groups (`src/dsp/sampler.jai`, `src/engine/voice_manager.jai`)**
  - [ ] Exclusive voice groups (e.g. Choke Group 1: Closed Hi-Hat instantly cuts off ringing Open Hi-Hat).
- [ ] **14.2 Sampler ADSR & Volume Envelopes**
  - [ ] Per-sample Attack and Decay envelopes to reshape transient punch or eliminate clicks.
  - [ ] Sustained sample loops with loop start / loop end markers.
- [ ] **14.3 Sample Manipulation Parameters**
  - [ ] Sample start offset (skip silent intros or slice sample attacks).
  - [ ] Reverse playback flag (for reverse cymbals, snare swells, and transitional risers).
- [ ] **14.4 Multi-Sample Pitch Tracking**
  - [ ] Root note assignment and linear/cubic pitch interpolation across octaves for realistic acoustic or piano playback.

**Acceptance Criteria**: Open hi-hats choke naturally on closed hits, and reverse cymbals swell seamlessly into song sections.

---

## Phase 15: Parameter Automation & Timeline Curves

> **Goal**: Give songs evolving energy, tension, and release through automated sweeps, risers, and fades.

- [ ] **15.1 Automation Model & Syntax (`src/parser/`)**
  - [ ] Extend `.song` language with an `[automation]` section or inline arrangement curves:
    - `automate track 1.filter_cutoff from 200 to 8000 over bar 9-16 curve=exponential`
    - `automate track 2.gain from -inf to 0dB over bar 1-4 curve=linear`
    - `automate tempo from 120 to 140 over bar 16-17`
- [ ] **15.2 Timeline Curve Interpolation (`src/engine/sequencer.jai`)**
  - [ ] Linear, exponential, and logarithmic curve shapes calculated sample-accurately during block rendering.
  - [ ] Target parameters: Channel Gain, Pan, Filter Cutoff/Resonance, Send Levels, and Master Tempo.
- [ ] **15.3 Live Hot-Reload Verification**
  - [ ] Editing automation points in real time updates the playback curves smoothly without audio clicks.

**Acceptance Criteria**: An 8-bar build-up filter sweep rises smoothly and peaks precisely on the first beat of the drop.

---

## Phase 16: Mastering Suite & Stem Export

> **Goal**: Deliver broadcast-ready audio masters and individual stems for archival, collaboration, or external mixing.

- [ ] **16.1 Industry Standard Loudness & Metering (`src/engine/mixer.jai`)**
  - [ ] Integrated, Short-term, and Momentary LUFS loudness calculation conforming to ITU-R BS.1770 / EBU R128.
  - [ ] True-Peak detector (oversampled 4x) to avoid inter-sample clipping on digital playback systems.
  - [ ] Live terminal status displaying current LUFS (e.g. `Loudness: -14.2 LUFS | True Peak: -0.3 dBFS`).
- [ ] **16.2 Multi-Track Stem Export**
  - [ ] CLI command: `music_engine export <file.song> --stems -o <output_directory>/`.
  - [ ] Render all mixer channels (Drums, Bass, Synths, FX, Master) into separate, synchronized WAV stems in a single pass.
- [ ] **16.3 TPDF Audio Dithering**
  - [ ] Triangular Probability Density Function (TPDF) noise dithering when exporting to 16-bit WAV to eliminate quantization distortion in quiet tails.

**Acceptance Criteria**: The engine exports broadcast-standard masters at target LUFS with zero true-peak overshoots, plus individual stems.

---

## Phase 17: Full-Length Production Showcase

> **Goal**: Prove that the engine can produce complete, commercial-grade, multi-minute compositions with intro, builds, drops, breakdowns, and outros.

- [ ] **17.1 Synthwave / Cyberpunk Track (`songs/cyber_city.song`)**
  - [ ] 3+ minute complete track featuring driving sidechained bassline, unison supersaw leads, gated reverb snare, and automated filter sweeps.
- [ ] **17.2 Lo-Fi Chillhop Beat (`songs/midnight_coffee.song`)**
  - [ ] Swing groove, saturated acoustic drums, Rhodes-style warm chords, vinyl noise layer, and relaxed tempo.
- [ ] **17.3 Modern Electronic Club Track (`songs/pulse_reactor.song`)**
  - [ ] 4-on-the-floor club arrangement with riser transitions, tension builds, sidechain compression, and punchy master limiting.
- [ ] **17.4 Comprehensive Benchmark & Regression Suite**
  - [ ] Stress test voice engine and effect pipelines under maximum polyphony and heavy automation.

**Acceptance Criteria**: All 3 showcase songs render seamlessly offline and play back live with < 15% CPU load and broadcast-ready mix balance.
