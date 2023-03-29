package ini

import "core:strings"
import "core:unicode"
import "core:unicode/utf8"

// INI is a map from string to string which the parser parses into.
// Keys are of the format {section}.{key} where a section is the `[foo]` parts of the ini file but without the brackets.
INI :: distinct map[string]string

ini_delete :: proc(i: ^INI) {
	for k, v in i {
        delete(k)
        delete(v)
	}
	delete(i^)
}

ParseErr :: enum {
	EOF, // Probably not an error (returned when ok).
	IllegalToken,
	KeyWithoutEquals,
	ValueWithoutKey,
	UnexpectedEquals,
}

ParseResult :: struct {
	err: ParseErr,
	pos: Pos,
}

// Parser parses the tokens from the lexer into the ini map.
Parser :: struct {
	lexer:        ^Lexer,
	ini:          ^INI,
	curr_section: []byte,
}

make_parser :: proc(l: ^Lexer, ini: ^INI) -> Parser {
	p: Parser
	p.lexer = l
	p.ini = ini
	return p
}

parse_into :: proc(data: []byte, ini: ^INI) -> ParseResult {
	l := make_lexer(data)
	p := make_parser(&l, ini)
	res := parser_parse(&p)
	return res
}

parse :: proc(data: []byte) -> (INI, ParseResult) {
	ini: INI
	res := parse_into(data, &ini)
	if res.err != .EOF {
		ini_delete(&ini)
	}
	return ini, res
}

parser_parse :: proc(using p: ^Parser) -> ParseResult {
	for t := lexer_next(lexer);; t = lexer_next(lexer) {
		if res, ok := parser_parse_token(p, t).?; ok {
			return res
		}
	}
}

@(private = "file")
parser_parse_token :: proc(using p: ^Parser, t: Token) -> Maybe(ParseResult) {
	switch t.type {
	case .Illegal:
		return ParseResult{.IllegalToken, t.pos}
	case .Key:
		assignment := lexer_next(lexer)
		if assignment.type != .Assign {
			return ParseResult{.KeyWithoutEquals, t.pos}
		}

		key := parser_make_key(p, t.value)

		value := lexer_next(lexer)
		if value.type != .Value {
			// No value, value is empty string.
			ini[key] = ""
			return parser_parse_token(p, value)
		}

		ini[key] = strings.clone(string(value.value))
	case .Section:
		// Trim of the '[' and ']', no bounds check needed because they are required on lexer level.
		#no_bounds_check curr_section = t.value[1:len(t.value) - 1]
	case .Value:
		return ParseResult{.ValueWithoutKey, t.pos}
	case .Assign:
		return ParseResult{.UnexpectedEquals, t.pos}
	// Ignoring comments.
	case .Comment:
	case .EOF:
		return ParseResult{.EOF, t.pos}
	}

	return nil
}

// Creates the key string: {section}{dot}{key}.
@(private = "file")
parser_make_key :: proc(using p: ^Parser, suffix: []byte) -> string {
	keyb := make([]byte, len(suffix) + len(curr_section) + 1)
	n := copy(keyb, curr_section)
	nn := copy(keyb[n:], ".")
	copy(keyb[n + nn:], suffix)
	return string(to_lower(keyb))
}

@(private = "file")
to_lower :: proc(s: []byte) -> []byte {
    s, i, n := s, 0, len(s)

    for i < n {
        ch, ch_size := utf8.decode_rune(s[i:])
        i += ch_size

        lower_ch := unicode.to_lower(ch)
        if ch != lower_ch {
            lower_bytes := transmute([4]byte)lower_ch
            copy(s[i-1:], lower_bytes[:ch_size])
        }
    }

    return s
}
