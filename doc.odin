/*
Package ini provides a parser (and lexer) for .ini files.

Format implemented:
 - All the following rules where a character is matched, can have that character escaped with a `\` and it will be considered plain text
 - Even a `\` at the end of a line will escape the newline, adding it to the current key/value/section
 - Sections are case-insensitive and transformed to lowercase
 - Anything between `[` at the start of a line and a `]` is a new section
 - A `[` with no matching `]` before the end of the line is illegal
 - Anything after a section, until a new section, is in that section
 - Comments start with a `#` or `;` at the beginning of a line and end at the end of that line
 - Keys are case-insensitive and transformed to lowercase
 - Keys start at the beginning of a line, until either a `:` or a `=` and thus can not contain those characters
 - Each key must have a matching `:` or `=`
 - Values are optional (defaults to an empty string)
 - Values can contain any character, are trimmed of whitespace, and end at the end of the line
 - Values can be wrapped in `'` or `"`, these will be stripped, but whitespace in them is sustained
 - If a value contains a `'` or `"`, a matching end quote has to be there, otherwise it should be escaped

Example usage:

```odin
package main

import "core:fmt"
import "core:os"
import "pkg:ini"

config_file_path :: "config.ini"

main :: proc() {
	config, ok := get_config().?
    if !ok {
        return
    }

	defer ini.ini_delete(&config)

    for k, v in config {
        fmt.printf("%q: %q\n", k, v)
    }
}

get_config :: proc() -> Maybe(ini.INI) {
	bytes, ok := os.read_entire_file_from_filename(config_file_path)
	if !ok {
		fmt.printf("[ERROR]: could not read %q\n", config_file_path)
		return nil
	}
	defer delete(bytes)

	ini, res := ini.parse(bytes)
    using res.pos
    switch res.err {
        case .EOF:              return ini
        case .IllegalToken:     fmt.printf("[ERROR]: Illegal token encountered in %q at %d:%d", config_file_path, line+1, col+1)
        case .KeyWithoutEquals: fmt.printf("[ERROR]: Key token found, but not assigned in %q at %d:%d", config_file_path, line+1, col+1)
        case .ValueWithoutKey:  fmt.printf("[ERROR]: Value token found, but not preceeded by a key token in %q at %d:%d", config_file_path, line+1, col+1)
        case .UnexpectedEquals: fmt.printf("[ERROR]: Equals sign found in an unexpected location in %q at %d:%d", config_file_path, line+1, col+1)
    }

    return nil
}
```
*/
package ini
