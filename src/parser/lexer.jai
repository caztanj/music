tokenize :: (source_text: string, filename: string = "") -> [..] Token, bool, string {
    tokens: [..] Token;
    lexer: Lexer;
    lexer.filename = filename;
    lexer.source_text = source_text;
    lexer.cursor_index = 0;
    lexer.current_line_number = 1;
    lexer.current_column_number = 1;

    while true {
        token := next_token(*lexer);
        array_add(*tokens, token);

        if token.type == .END_OF_FILE {
            break;
        }

        if token.type == .ERROR {
            return tokens, false, lexer.error_message;
        }
    }

    return tokens, true, "";
}

next_token :: (lexer: *Lexer) -> Token {
    skip_horizontal_whitespace(lexer);

    while true {
        character := peek_character(lexer);

        if character == 0 {
            token: Token;
            token.type = .END_OF_FILE;
            token.text = "";
            token.location = Source_Location.{filename = lexer.filename, line_number = lexer.current_line_number, column_number = lexer.current_column_number};

            return token;
        }

        if character == #char "#" {
            skip_comment(lexer);
            continue;
        }

        if character == #char "/" && peek_next_character(lexer) == #char "/" {
            skip_comment(lexer);
            continue;
        }

        if character == #char "\r" || character == #char "\n" {
            location := Source_Location.{filename = lexer.filename, line_number = lexer.current_line_number, column_number = lexer.current_column_number};

            while true {
                next_character := peek_character(lexer);
                if next_character == #char "\r" || next_character == #char "\n" {
                    advance_character(lexer);
                } else if next_character == #char " " || next_character == #char "\t" {
                    advance_character(lexer);
                } else if next_character == #char "#" {
                    skip_comment(lexer);
                } else if next_character == #char "/" && peek_next_character(lexer) == #char "/" {
                    skip_comment(lexer);
                } else {
                    break;
                }
            }

            token: Token;
            token.type = .NEWLINE;
            token.text = "\n";
            token.location = location;

            return token;
        }

        if character == #char " " || character == #char "\t" {
            skip_horizontal_whitespace(lexer);
            continue;
        }

        break;
    }

    location := Source_Location.{filename = lexer.filename, line_number = lexer.current_line_number, column_number = lexer.current_column_number};
    character := peek_character(lexer);

    if character == #char "[" {
        advance_character(lexer);
        token: Token;
        token.type = .OPEN_BRACKET;
        token.text = "[";
        token.location = location;

        return token;
    }

    if character == #char "]" {
        advance_character(lexer);
        token: Token;
        token.type = .CLOSE_BRACKET;
        token.text = "]";
        token.location = location;

        return token;
    }

    if character == #char "(" {
        advance_character(lexer);
        token: Token;
        token.type = .OPEN_PARENTHESIS;
        token.text = "(";
        token.location = location;

        return token;
    }

    if character == #char ")" {
        advance_character(lexer);
        token: Token;
        token.type = .CLOSE_PARENTHESIS;
        token.text = ")";
        token.location = location;

        return token;
    }

    if character == #char "=" {
        advance_character(lexer);
        token: Token;
        token.type = .EQUALS;
        token.text = "=";
        token.location = location;

        return token;
    }

    if character == #char ":" {
        advance_character(lexer);
        token: Token;
        token.type = .COLON;
        token.text = ":";
        token.location = location;

        return token;
    }

    if character == #char "|" {
        advance_character(lexer);
        token: Token;
        token.type = .PIPE;
        token.text = "|";
        token.location = location;

        return token;
    }

    if character == #char "," {
        advance_character(lexer);
        token: Token;
        token.type = .COMMA;
        token.text = ",";
        token.location = location;

        return token;
    }

    if character == #char "-" {
        advance_character(lexer);
        if peek_character(lexer) == #char ">" {
            advance_character(lexer);
            token: Token;
            token.type = .ARROW;
            token.text = "->";
            token.location = location;

            return token;
        }

        token: Token;
        token.type = .MINUS;
        token.text = "-";
        token.location = location;

        return token;
    }

    if character == #char "/" {
        advance_character(lexer);
        token: Token;
        token.type = .SLASH;
        token.text = "/";
        token.location = location;

        return token;
    }

    if character == #char "%" {
        advance_character(lexer);
        token: Token;
        token.type = .PERCENT;
        token.text = "%";
        token.location = location;

        return token;
    }

    if character == #char "^" {
        advance_character(lexer);
        token: Token;
        token.type = .CARET;
        token.text = "^";
        token.location = location;

        return token;
    }

    if character == #char "!" {
        advance_character(lexer);
        token: Token;
        token.type = .EXCLAMATION;
        token.text = "!";
        token.location = location;

        return token;
    }

    if character == #char "\"" {

        return scan_string(lexer);
    }

    if character == #char "." {
        if is_digit(peek_next_character(lexer)) {
            return scan_number(lexer);
        }

        advance_character(lexer);
        token: Token;
        token.type = .DOT;
        token.text = ".";
        token.location = location;

        return token;
    }

    if is_digit(character) {
        return scan_number(lexer);
    }

    if (character == #char "x" || character == #char "X") && !is_identifier_continue(peek_next_character(lexer)) {
        advance_character(lexer);
        token: Token;
        token.type = .STEP_HIT;
        if character == #char "x" {
            token.text = "x";
        } else {
            token.text = "X";
        }
        token.location = location;

        return token;
    }

    if is_identifier_start(character) {
        return scan_identifier(lexer);
    }

    advance_character(lexer);
    lexer.has_error = true;
    lexer.error_message = sprint("(%, line %, column %): Unexpected character '%'", lexer.filename, location.line_number, location.column_number, character);

    token: Token;
    token.type = .ERROR;
    token.text = "";
    token.location = location;

    return token;
}

scan_string :: (lexer: *Lexer) -> Token {
    location := Source_Location.{filename = lexer.filename, line_number = lexer.current_line_number, column_number = lexer.current_column_number};
    advance_character(lexer);

    builder: String_Builder;

    while lexer.cursor_index < lexer.source_text.count {
        character := advance_character(lexer);
        if character == #char "\"" {
            token: Token;
            token.type = .STRING;
            token.location = location;
            token.string_value = builder_to_string(*builder);
            token.text = token.string_value;

            return token;
        }

        if character == #char "\\" {
            if lexer.cursor_index < lexer.source_text.count {
                escaped_character := advance_character(lexer);
                if escaped_character == {
                    case #char "n";
                        append(*builder, #char "\n");

                    case #char "t";
                        append(*builder, #char "\t");

                    case #char "r";
                        append(*builder, #char "\r");

                    case #char "\"";
                        append(*builder, #char "\"");

                    case #char "\\";
                        append(*builder, #char "\\");

                    case;
                        append(*builder, escaped_character);
                }
            }
        } else {
            append(*builder, character);
        }
    }

    lexer.has_error = true;
    lexer.error_message = sprint("(%, line %, column %): Unterminated string literal", lexer.filename, location.line_number, location.column_number);

    token: Token;
    token.type = .ERROR;
    token.location = location;

    return token;
}

scan_number :: (lexer: *Lexer) -> Token {
    location := Source_Location.{filename = lexer.filename, line_number = lexer.current_line_number, column_number = lexer.current_column_number};
    start_index := lexer.cursor_index;
    is_floating_point := false;

    if lexer.cursor_index < lexer.source_text.count && lexer.source_text[lexer.cursor_index] == #char "." {
        is_floating_point = true;
        advance_character(lexer);
    }

    while lexer.cursor_index < lexer.source_text.count {
        character := lexer.source_text[lexer.cursor_index];
        if is_digit(character) {
            advance_character(lexer);
        } else if character == #char "." && !is_floating_point {
            if lexer.cursor_index + 1 < lexer.source_text.count && is_digit(lexer.source_text[lexer.cursor_index + 1]) {
                is_floating_point = true;
                advance_character(lexer);
            } else {
                break;
            }
        } else {
            break;
        }
    }

    number_text: string;
    number_text.data = lexer.source_text.data + start_index;
    number_text.count = lexer.cursor_index - start_index;

    token: Token;
    token.location = location;
    token.text = number_text;

    if is_floating_point {
        token.type = .FLOAT;
        parsed_float, success := string_to_float(number_text);
        token.float_value = parsed_float;
    } else {
        token.type = .INTEGER;
        parsed_integer, success := string_to_int(number_text);
        token.integer_value = parsed_integer;
        token.float_value = cast(float64) parsed_integer;
    }

    return token;
}

scan_identifier :: (lexer: *Lexer) -> Token {
    location := Source_Location.{filename = lexer.filename, line_number = lexer.current_line_number, column_number = lexer.current_column_number};
    start_index := lexer.cursor_index;

    while lexer.cursor_index < lexer.source_text.count {
        character := lexer.source_text[lexer.cursor_index];
        if is_identifier_continue(character) {
            advance_character(lexer);
        } else if character == #char "#" {
            previous_character := lexer.source_text[lexer.cursor_index - 1];
            is_note_letter := (previous_character >= #char "A" && previous_character <= #char "G") || (previous_character >= #char "a" && previous_character <= #char "g");
            if is_note_letter && lexer.cursor_index + 1 < lexer.source_text.count && (is_digit(lexer.source_text[lexer.cursor_index + 1]) || lexer.source_text[lexer.cursor_index + 1] == #char "-") {
                advance_character(lexer);
            } else {
                break;
            }
        } else {
            break;
        }
    }

    identifier_text: string;
    identifier_text.data = lexer.source_text.data + start_index;
    identifier_text.count = lexer.cursor_index - start_index;

    token: Token;
    token.location = location;
    token.text = identifier_text;
    token.type = .IDENTIFIER;

    return token;
}

skip_horizontal_whitespace :: (lexer: *Lexer) {
    while lexer.cursor_index < lexer.source_text.count {
        character := peek_character(lexer);
        if character == #char " " || character == #char "\t" {
            advance_character(lexer);
        } else {
            break;
        }
    }
}

skip_comment :: (lexer: *Lexer) {
    while lexer.cursor_index < lexer.source_text.count {
        character := peek_character(lexer);
        if character == #char "\n" || character == #char "\r" {
            break;
        }
        advance_character(lexer);
    }
}

peek_character :: (lexer: *Lexer) -> u8 {
    if lexer.cursor_index >= lexer.source_text.count {
        return 0;
    }

    return lexer.source_text[lexer.cursor_index];
}

peek_next_character :: (lexer: *Lexer) -> u8 {
    if lexer.cursor_index + 1 >= lexer.source_text.count {
        return 0;
    }

    return lexer.source_text[lexer.cursor_index + 1];
}

advance_character :: (lexer: *Lexer) -> u8 {
    if lexer.cursor_index >= lexer.source_text.count {
        return 0;
    }

    character := lexer.source_text[lexer.cursor_index];
    lexer.cursor_index += 1;

    if character == #char "\r" {
        if lexer.cursor_index < lexer.source_text.count && lexer.source_text[lexer.cursor_index] == #char "\n" {
            lexer.cursor_index += 1;
        }
        lexer.current_line_number += 1;
        lexer.current_column_number = 1;

        return #char "\n";
    }

    if character == #char "\n" {
        lexer.current_line_number += 1;
        lexer.current_column_number = 1;

        return #char "\n";
    }

    lexer.current_column_number += 1;

    return character;
}

is_identifier_start :: (character: u8) -> bool {
    return is_alpha(character) || character == #char "_";
}

is_identifier_continue :: (character: u8) -> bool {
    return is_alpha(character) || is_digit(character) || character == #char "_";
}

Source_Location :: struct {
    filename: string;
    line_number: s64 = 1;
    column_number: s64 = 1;
}

Token_Type :: enum {
    END_OF_FILE;
    ERROR;
    NEWLINE;
    IDENTIFIER;
    INTEGER;
    FLOAT;
    STRING;
    OPEN_BRACKET;
    CLOSE_BRACKET;
    OPEN_PARENTHESIS;
    CLOSE_PARENTHESIS;
    EQUALS;
    COLON;
    ARROW;
    PIPE;
    MINUS;
    COMMA;
    SLASH;
    DOT;
    PERCENT;
    STEP_HIT;
    CARET;
    EXCLAMATION;
}

Token :: struct {
    type: Token_Type = .END_OF_FILE;
    text: string;
    integer_value: s64 = 0;
    float_value: float64 = 0.0;
    string_value: string;
    location: Source_Location;
}

Lexer :: struct {
    filename: string;
    source_text: string;
    cursor_index: s64 = 0;
    current_line_number: s64 = 1;
    current_column_number: s64 = 1;
    error_message: string;
    has_error: bool = false;
}
