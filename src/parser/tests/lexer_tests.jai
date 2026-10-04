lexer_tests :: () {
    test("tokenize empty text", () {
        tokens, success, error_message := tokenize("");
        expect_true(success);
        expect_equals(tokens.count, 1);
        expect_equals(tokens[0].type, Token_Type.END_OF_FILE);
    });

    test("tokenize section header", () {
        tokens, success, error_message := tokenize("[project]");
        expect_true(success);
        expect_equals(tokens.count, 4);
        expect_equals(tokens[0].type, Token_Type.OPEN_BRACKET);
        expect_equals(tokens[1].type, Token_Type.IDENTIFIER);
        expect_equals(tokens[1].text, "project");
        expect_equals(tokens[2].type, Token_Type.CLOSE_BRACKET);
        expect_equals(tokens[3].type, Token_Type.END_OF_FILE);
    });

    test("tokenize numbers", () {
        tokens, success, error_message := tokenize("128 0.95 0 10.0");
        expect_true(success);
        expect_equals(tokens.count, 5);
        expect_equals(tokens[0].type, Token_Type.INTEGER);
        expect_equals(tokens[0].integer_value, 128);
        expect_equals(tokens[1].type, Token_Type.FLOAT);
        expect_near(cast(float) tokens[1].float_value, 0.95, 0.0001);
        expect_equals(tokens[2].type, Token_Type.INTEGER);
        expect_equals(tokens[2].integer_value, 0);
        expect_equals(tokens[3].type, Token_Type.FLOAT);
        expect_near(cast(float) tokens[3].float_value, 10.0, 0.0001);
    });

    test("tokenize string literal", () {
        tokens, success, error_message := tokenize("\"Neon Horizon\"");
        expect_true(success);
        expect_equals(tokens.count, 2);
        expect_equals(tokens[0].type, Token_Type.STRING);
        expect_equals(tokens[0].string_value, "Neon Horizon");
    });

    test("tokenize operators and delimiters", () {
        tokens, success, error_message := tokenize("= : -> | - , / . %");
        expect_true(success);
        expect_equals(tokens.count, 10);
        expect_equals(tokens[0].type, Token_Type.EQUALS);
        expect_equals(tokens[1].type, Token_Type.COLON);
        expect_equals(tokens[2].type, Token_Type.ARROW);
        expect_equals(tokens[3].type, Token_Type.PIPE);
        expect_equals(tokens[4].type, Token_Type.MINUS);
        expect_equals(tokens[5].type, Token_Type.COMMA);
        expect_equals(tokens[6].type, Token_Type.SLASH);
        expect_equals(tokens[7].type, Token_Type.DOT);
        expect_equals(tokens[8].type, Token_Type.PERCENT);
    });


    test("tokenize comments and newlines", () {
        text := "# This is a comment\nbpm = 128 // inline comment\n\nname = \"Track\"";
        tokens, success, error_message := tokenize(text);
        expect_true(success);
        expect_equals(tokens[0].type, Token_Type.NEWLINE);
        expect_equals(tokens[1].type, Token_Type.IDENTIFIER);
        expect_equals(tokens[1].text, "bpm");
        expect_equals(tokens[2].type, Token_Type.EQUALS);
        expect_equals(tokens[3].type, Token_Type.INTEGER);
        expect_equals(tokens[3].integer_value, 128);
        expect_equals(tokens[4].type, Token_Type.NEWLINE);
        expect_equals(tokens[5].type, Token_Type.IDENTIFIER);
        expect_equals(tokens[5].text, "name");
        expect_equals(tokens[6].type, Token_Type.EQUALS);
        expect_equals(tokens[7].type, Token_Type.STRING);
        expect_equals(tokens[7].string_value, "Track");
    });

    test("tokenize step grid", () {
        tokens, success, error_message := tokenize("kick | x . . . x . . . |");
        expect_true(success);
        expect_equals(tokens[0].type, Token_Type.IDENTIFIER);
        expect_equals(tokens[0].text, "kick");
        expect_equals(tokens[1].type, Token_Type.PIPE);
        expect_equals(tokens[2].type, Token_Type.STEP_HIT);
        expect_equals(tokens[2].text, "x");
        expect_equals(tokens[3].type, Token_Type.DOT);
        expect_equals(tokens[4].type, Token_Type.DOT);
        expect_equals(tokens[5].type, Token_Type.DOT);
        expect_equals(tokens[6].type, Token_Type.STEP_HIT);
        expect_equals(tokens[10].type, Token_Type.PIPE);
    });

    test("tokenize musical notes", () {
        tokens, success, error_message := tokenize("C2 C#2 Eb2 F#3 Bb4");
        expect_true(success);
        expect_equals(tokens.count, 6);
        expect_equals(tokens[0].text, "C2");
        expect_equals(tokens[1].text, "C#2");
        expect_equals(tokens[2].text, "Eb2");
        expect_equals(tokens[3].text, "F#3");
        expect_equals(tokens[4].text, "Bb4");
    });

    test("tokenize source location tracking", () {
        text := "bpm = 128\nname = \"Track\"";
        tokens, success, error_message := tokenize(text, "song.song");
        expect_true(success);
        expect_equals(tokens[0].location.line_number, 1);
        expect_equals(tokens[0].location.column_number, 1);
        expect_equals(tokens[2].location.line_number, 1);
        expect_equals(tokens[2].location.column_number, 7);
        expect_equals(tokens[4].location.line_number, 2);
        expect_equals(tokens[4].location.column_number, 1);
        expect_equals(tokens[5].location.line_number, 2);
        expect_equals(tokens[5].location.column_number, 6);
    });


    test("tokenize invalid character", () {
        tokens, success, error_message := tokenize("valid @ invalid", "test.song");
        expect_true(!success);
        expect_equals(tokens[tokens.count - 1].type, Token_Type.ERROR);
    });
}
