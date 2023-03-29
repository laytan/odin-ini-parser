package ini

import "core:fmt"
import "core:unicode"
import "core:unicode/utf8"

TokenType :: enum {
	Illegal,
	EOF, // The last token parsed, caller should not call again.
	Comment,
	Section,
	Assign,
	Key,
	Value,
}

Pos :: struct {
	line:   int,
	col:    int,
	offset: int,
}

Token :: struct {
	type:  TokenType,
	value: []byte,
	pos:   Pos,
}

// Lexer tokenizes the given data into .ini semantic tokens.
// The given data is not writen to or modified.
Lexer :: struct {
	data:         []byte,
	ch:           rune, // The current character being checked.
	cursor:       int, // The current offset/index (rune based) in data.
	bytes_cursor: int, // The current offset/index (byte based) in data.
	line:         int, // The current line number.
	bol:          int, // The offset/index that is the beginning of the current line.
}

lexer_init :: proc(using l: ^Lexer, d: []byte) {
	l.data = d
	lexer_read(l)
	l.cursor = 0
}

make_lexer :: proc(data: []byte) -> Lexer {
	l: Lexer
	lexer_init(&l, data)
	return l
}

lexer_next :: proc(using l: ^Lexer) -> Token {
	lexer_skip_whitespace(l)

	t: Token
	t.pos = lexer_pos(l)

	switch {
	case ch == 0:
		t.type = .EOF
	case (ch == ';' || ch == '#') && bol == cursor:
		t.type = .Comment
		s, _ := lexer_read_until(l, '\n')
		t.value = data[s:bytes_cursor - 1]
	// [section], if a matching ] is not found, this sets the whole line to illegal.
	case ch == '[':
		s, ok := lexer_read_until(l, ']')
		if ok {
			t.type = .Section
			lexer_read(l)
		} else {
			t.type = .Illegal
		}
		t.value = data[s:bytes_cursor - 1]
	case ch == ':' || ch == '=':
		t.type = .Assign
		t.value = data[cursor:cursor + 1]
		lexer_read(l)
	case ch == '"' || ch == '\'':
		t.type = .Value
		if s, is_terminated := lexer_read_until(l, ch); is_terminated {
			t.value = data[s + 1:bytes_cursor - 1]
		} else {
			t.value = data[s:bytes_cursor - 1]
		}
		lexer_read(l)
	case:
		if s, is_key := lexer_read_until(l, ':', '='); is_key {
			t.type = .Key
			// // Trim the whitespace between the key and the '='.
			t.value = trim_trailing_right(data[s:bytes_cursor - 1])
		} else {
			t.type = .Value
			t.value = data[s:bytes_cursor - 1]
		}
	}

	return t
}

lexer_read :: proc(using l: ^Lexer) {
	read_ch, size := utf8.decode_rune(l.data[bytes_cursor:])
	// EOF.
	if size == 0 {
		ch = 0
		return
	}

	bytes_cursor += size
	cursor += 1
	ch = read_ch
	lexer_check_newline(l)
}

lexer_check_newline :: proc(using l: ^Lexer) {
	if ch != '\n' {
		return
	}

	line += 1
	bol = cursor + 1
}

lexer_skip_whitespace :: proc(using l: ^Lexer) {
	for unicode.is_space(ch) {
		lexer_read(l)
	}
}

lexer_pos :: proc(using l: ^Lexer) -> Pos {
    return Pos{line = line, col = cursor-bol, offset = cursor}
}

// Reads until a non-escaped rune in check, a newline or the eof.
// This returns the cursor where it started reading and the type of match.
// any match in check returns true.
// newline and eof return false.
lexer_read_until :: proc(using l: ^Lexer, check: ..rune) -> (int, bool) {
	start_byte := bytes_cursor - 1
	escaped := ch == '\\'
	for ch != 0 {
		lexer_read(l)

		if !escaped {
			if ch == '\n' {
				return start_byte, false
			}

			for c in check {
				if c == ch {
					return start_byte, true
				}
			}
		}

        escaped = escaped ? false : ch == '\\'
	}

	return start_byte, false
}

// iterates per-rune in reverse, reslicing any trailing whitespace.
@(private = "file")
trim_trailing_right :: proc(k: []byte) -> []byte {
	key := k
	i := len(key)
	for i > 0 {
		key_rune, key_rune_size := utf8.decode_last_rune(key[:i])
		i -= key_rune_size

        if !unicode.is_space(key_rune) {
            break
        }

		key = key[:i]
	}

	return key
}
