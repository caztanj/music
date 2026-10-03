envelope_tests :: () {
    test("initial state is idle", () {
        envelope_generator: Envelope_Generator;
        expect_equals(envelope_generator.state, Envelope_State.IDLE);
        expect_true(!is_envelope_active(*envelope_generator));
        sample := process_envelope_sample(*envelope_generator);
        expect_equals(sample, 0.0);
    });

    test("attack phase reaches peak", () {
        envelope_generator: Envelope_Generator;
        configuration: Envelope_Configuration;
        configuration.attack_milliseconds = 10.0;
        configuration.decay_milliseconds = 50.0;
        configuration.sustain_level = 0.5;
        configuration.release_milliseconds = 50.0;

        configure_envelope(*envelope_generator, configuration, 1000);
        trigger_attack(*envelope_generator);

        expect_true(is_envelope_active(*envelope_generator));
        expect_equals(envelope_generator.state, Envelope_State.ATTACK);

        sample_index := 0;
        while sample_index < envelope_generator.attack_samples {
            sample := process_envelope_sample(*envelope_generator);
            expect_true(sample >= 0.0 && sample <= 1.0);
            sample_index += 1;
        }

        expect_equals(envelope_generator.state, Envelope_State.DECAY);
        expect_near(envelope_generator.current_level, 1.0, 0.001);
    });

    test("decay phase reaches sustain level", () {
        envelope_generator: Envelope_Generator;
        configuration: Envelope_Configuration;
        configuration.attack_milliseconds = 1.0;
        configuration.decay_milliseconds = 10.0;
        configuration.sustain_level = 0.6;
        configuration.release_milliseconds = 20.0;

        configure_envelope(*envelope_generator, configuration, 1000);
        trigger_attack(*envelope_generator);

        sample_index := 0;
        while sample_index < envelope_generator.attack_samples + envelope_generator.decay_samples {
            process_envelope_sample(*envelope_generator);
            sample_index += 1;
        }

        expect_equals(envelope_generator.state, Envelope_State.SUSTAIN);
        expect_near(envelope_generator.current_level, 0.6, 0.001);
    });

    test("sustain phase holds value", () {
        envelope_generator: Envelope_Generator;
        configuration: Envelope_Configuration;
        configuration.attack_milliseconds = 1.0;
        configuration.decay_milliseconds = 2.0;
        configuration.sustain_level = 0.4;
        configuration.release_milliseconds = 10.0;

        configure_envelope(*envelope_generator, configuration, 1000);
        trigger_attack(*envelope_generator);

        sample_index := 0;
        while sample_index < 10 {
            process_envelope_sample(*envelope_generator);
            sample_index += 1;
        }

        expect_equals(envelope_generator.state, Envelope_State.SUSTAIN);

        sustain_step_index := 0;
        while sustain_step_index < 50 {
            sample := process_envelope_sample(*envelope_generator);
            expect_near(sample, 0.4, 0.0001);
            sustain_step_index += 1;
        }
    });

    test("release phase decays to idle", () {
        envelope_generator: Envelope_Generator;
        configuration: Envelope_Configuration;
        configuration.attack_milliseconds = 1.0;
        configuration.decay_milliseconds = 2.0;
        configuration.sustain_level = 0.8;
        configuration.release_milliseconds = 10.0;

        configure_envelope(*envelope_generator, configuration, 1000);
        trigger_attack(*envelope_generator);

        sample_index := 0;
        while sample_index < 5 {
            process_envelope_sample(*envelope_generator);
            sample_index += 1;
        }

        trigger_release(*envelope_generator);
        expect_equals(envelope_generator.state, Envelope_State.RELEASE);

        release_step_index := 0;
        while release_step_index < envelope_generator.release_samples + 5 {
            process_envelope_sample(*envelope_generator);
            release_step_index += 1;
        }

        expect_equals(envelope_generator.state, Envelope_State.IDLE);
        expect_equals(envelope_generator.current_level, 0.0);
        expect_true(!is_envelope_active(*envelope_generator));
    });

    test("retriggering attack while releasing", () {
        envelope_generator: Envelope_Generator;
        configuration: Envelope_Configuration;
        configuration.attack_milliseconds = 10.0;
        configuration.decay_milliseconds = 10.0;
        configuration.sustain_level = 0.5;
        configuration.release_milliseconds = 20.0;

        configure_envelope(*envelope_generator, configuration, 1000);
        trigger_attack(*envelope_generator);

        sample_index := 0;
        while sample_index < 15 {
            process_envelope_sample(*envelope_generator);
            sample_index += 1;
        }

        trigger_release(*envelope_generator);
        release_sample := process_envelope_sample(*envelope_generator);
        expect_true(release_sample > 0.1);

        trigger_attack(*envelope_generator);
        expect_equals(envelope_generator.state, Envelope_State.ATTACK);
        retriggered_sample := process_envelope_sample(*envelope_generator);
        expect_true(retriggered_sample >= release_sample);
    });

    test("reset envelope", () {
        envelope_generator: Envelope_Generator;
        configuration: Envelope_Configuration;
        configuration.attack_milliseconds = 10.0;
        configuration.decay_milliseconds = 10.0;
        configuration.sustain_level = 0.5;
        configuration.release_milliseconds = 10.0;

        configure_envelope(*envelope_generator, configuration, 1000);
        trigger_attack(*envelope_generator);
        process_envelope_sample(*envelope_generator);

        expect_true(is_envelope_active(*envelope_generator));
        reset_envelope(*envelope_generator);
        expect_true(!is_envelope_active(*envelope_generator));
        expect_equals(envelope_generator.state, Envelope_State.IDLE);
        expect_equals(envelope_generator.current_level, 0.0);
    });
}
