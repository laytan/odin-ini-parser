package main

import "core:fmt"
import "core:os"

import ini ".."

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
