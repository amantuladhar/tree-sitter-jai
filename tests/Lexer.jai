Lexer :: struct {
    src: string;
    tokens: [..]Token;
    error_reporter: *Error_Reporter;
    line: int = 1;
    start: int = 0; // current token start position
    current : int = 0; // where is cursor right now
}

Token :: struct {
    type  : Token_Type;
    value : string;
    line  : int;
    start : int;
}

parse_lex_tokens :: (src: string, error_reporter: *Error_Reporter, do_print: bool = false) -> Lexer {
    lexer := Lexer.{src = src, error_reporter = error_reporter};
    scan(*lexer);
    if do_print print_tokens(lexer.tokens);
    return lexer;
}

#scope_module

scan :: (using lexer: *Lexer) {
    while !is_at_end(lexer) {
        start = current;
        current_char := consume(lexer);

        if is_space(current_char) {
            if current_char == #char "\n" line += 1;
            continue;
        }
        if is_alpha(current_char) || current_char == #char "_" { ident_or_keyword(lexer); continue; }
        if is_digit(current_char) { number(lexer); continue; }

        if current_char == {
            case #char "("; add_token(lexer, .LPAREN);
            case #char ")"; add_token(lexer, .RPAREN);
            case #char "{"; add_token(lexer, .LCURLY);
            case #char "}"; add_token(lexer, .RCURLY);
            case #char ";"; add_token(lexer, .SEMICOLON);
            case #char "~"; add_token(lexer, .BITWISE_NOT);
            case #char ","; add_token(lexer, .COMMA);
            case #char "+";
                if peek(lexer) == #char "=" {
                    consume(lexer);
                    add_token(lexer, .PLUS_EQUAL);
                    continue;
                }
                if peek(lexer) == #char "+" {
                    consume(lexer);
                    add_token(lexer, .PLUS_PLUS);
                    continue;
                }
                add_token(lexer, .PLUS);
            case #char "*";
                if peek(lexer) == #char "=" {
                    consume(lexer);
                    add_token(lexer, .MULTIPLY_EQUAL);
                    continue;
                }
                add_token(lexer, .MULTIPLY);
            case #char "%";
                if peek(lexer) == #char "=" {
                    consume(lexer);
                    add_token(lexer, .MOD_EQUAL);
                    continue;
                }
                add_token(lexer, .MOD);
            case #char "&";
                if peek(lexer) == #char "&" {
                    consume(lexer);
                    add_token(lexer, .AND);
                    continue;
                }
                if peek(lexer) == #char "=" {
                    consume(lexer);
                    add_token(lexer, .BITWISE_AND_EQUAL);
                    continue;
                }
                add_token(lexer, .BITWISE_AND);
            case #char "|";
                if peek(lexer) == #char "|" {
                    consume(lexer);
                    add_token(lexer, .OR);
                    continue;
                }
                if peek(lexer) == #char "=" {
                    consume(lexer);
                    add_token(lexer, .BITWISE_OR_EQUAL);
                    continue;
                }
                add_token(lexer, .BITWISE_OR);
            case #char "^";
                if peek(lexer) == #char "=" {
                    consume(lexer);
                    add_token(lexer, .BITWISE_XOR_EQUAL);
                    continue;
                }
                add_token(lexer, .BITWISE_XOR);
            case #char ">";
                if peek(lexer) == #char ">" {
                    consume(lexer);
                    if peek(lexer) == #char "=" {
                        consume(lexer);
                        add_token(lexer, .RIGHT_SHIFT_EQUAL);
                        continue;
                    }
                    add_token(lexer, .RIGHT_SHIFT);
                    continue;
                }
                if peek(lexer) == #char "=" {
                    consume(lexer);
                    add_token(lexer, .GREATER_EQUAL);
                    continue;
                }
                add_token(lexer, .GREATER);
            case #char "<";
                if peek(lexer) == #char "<" {
                    consume(lexer);
                    if peek(lexer) == #char "=" {
                        consume(lexer);
                        add_token(lexer, .LEFT_SHIFT_EQUAL);
                        continue;
                    }
                    add_token(lexer, .LEFT_SHIFT);
                    continue;
                }
                if peek(lexer) == #char "=" {
                    consume(lexer);
                    add_token(lexer, .LESS_EQUAL);
                    continue;
                }
                add_token(lexer, .LESS);
            case #char "/";
                if peek(lexer) == #char "/" || peek(lexer) == #char "*" {
                    comment(lexer);
                    continue;
                }
                if peek(lexer) == #char "=" {
                    consume(lexer);
                    add_token(lexer, .DIVIDE_EQUAL);
                    continue;
                }
                add_token(lexer, .DIVIDE);
            case #char "-";
                if peek(lexer) == #char "=" {
                    consume(lexer);
                    add_token(lexer, .MINUS_EQUAL);
                    continue;
                }
                if peek(lexer) == #char "-" {
                    consume(lexer);
                    add_token(lexer, .MINUS_MINUS);
                    continue;
                }
                add_token(lexer, .MINUS);
            case #char "=";
                if peek(lexer) == #char "=" {
                    consume(lexer);
                    add_token(lexer, .EQUAL_EQUAL);
                    continue;
                }
                add_token(lexer, .ASSIGN);
            case #char "!";
                if peek(lexer) == #char "=" {
                    consume(lexer);
                    add_token(lexer, .NOT_EQUAL);
                    continue;
                }
                add_token(lexer, .NOT);
            case #char "?"; add_token(lexer, .QUESTION_MARK);
            case #char ":"; add_token(lexer, .COLON);
            case; lex_err(lexer, "Unexpected character %", to_string(*current_char, 1));
        }
    }
}

#scope_file

lex_err :: (using lexer: *Lexer, msg_fmt: string, args: .. Any) {
    error_report(error_reporter, line, start, msg_fmt, .. args);
}

print_tokens :: (tokens: []Token) {
    print("\n -- Lexer -- \n");
    for tokens print("%\n", it);
    print("\n");
}

comment :: (using lexer: *Lexer) {
    if peek(lexer) == {
        case #char "/";
            while !is_at_end(lexer) && peek(lexer) != #char "\n" {
                consume(lexer);
            }
            line += 1;
        case #char "*";
            consume(lexer);
            while !is_at_end(lexer) {
                c := consume(lexer);
                if c == #char "\n" line += 1;
                if c == #char "*" && peek(lexer) == #char "/" break;
            }
            consume(lexer); // consume closing /, if not found, this is an error
        case; lex_err(lexer, "unable to parse comment\n");
    }
}

number :: (using lexer: *Lexer) {
    found_alpha := false;
    while !is_at_end(lexer) && (is_digit(peek(lexer)) || is_alpha(peek(lexer))) {
        if is_alpha(peek(lexer)) found_alpha = true;
        consume(lexer);
    }
    str := slice(src, start, current-start);
    if found_alpha lex_err(lexer, "Invalid number found %", str);

    token := Token.{ .INT_LITERAL, str, line, start};
    array_add(*tokens, token);
}

ident_or_keyword :: (using lexer: *Lexer) {
    while !is_at_end(lexer) && is_alnum(peek(lexer)) consume(lexer);
    str := slice(src, start, current-start);
    token_type := find_keyword_or_ident(str);
    token := Token.{ token_type, str, line, start};
    array_add(*tokens, token);
}

eat_whitespace :: (lexer: *Lexer) {
    while is_space(peek(lexer)) {
        token := consume(lexer);
        if token == #char "\n" lexer.line += 1;
    }
}

find_keyword_or_ident :: (str: string) -> Token_Type {
    if str == {
        case "int"; return .INT;
        case "void"; return .VOID;
        case "return"; return .RETURN;
        case "if"; return .IF;
        case "else"; return .ELSE;
        case "goto"; return .GOTO;
        case "for"; return .FOR;
        case "do"; return .DO;
        case "while"; return .WHILE;
        case "break"; return .BREAK;
        case "continue"; return .CONTINUE;
        case "switch"; return .SWITCH;
        case "case"; return .CASE;
        case "default"; return .DEFAULT;
        case; return .IDENT;
    }
}

add_token :: (using lexer: *Lexer, type: Token_Type) {
    array_add(*tokens, .{ type, slice(src, start, current-start), line, start });
}

consume :: (using lexer: *Lexer) -> u8 {
    defer current += 1;
    c := peek(lexer);
    if c == #char "\n" line += 1;
    return c;
}

peek :: (using lexer: *Lexer, offset: int = 0) -> u8 {
    return src.data[current + offset];
}

is_at_end :: (using lexer: *Lexer) -> bool {
    return current >= src.count;
}

#import "Basic";
#import "String";
#import "Compiler_Util";
#import "File";
#import "Error_Reporter";
#import "Not_Basic";
