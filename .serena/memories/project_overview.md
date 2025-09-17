# Project Overview

## Purpose
Passage is a command-line tool for storing and managing access to shared secrets. It's designed to securely encrypt and decrypt secrets using age encryption, with support for multiple recipients and group management.

## Tech Stack
- **Language**: OCaml (>= 4.14)
- **Build System**: Dune (3.9+)
- **Encryption**: age (via conf-age)
- **Key Libraries**: 
  - cmdliner (CLI parsing)
  - devkit (utilities)
  - lwt (async)
  - re2 (regex)
  - menhir (parser generator)
  - qrc (QR codes)

## Architecture
- **bin/main.ml**: Main CLI entry point with all commands and argument parsing
- **lib/**: Core library modules:
  - `config.ml`: Configuration and environment variables
  - `storage.ml`: Secret storage, encryption/decryption, recipient management
  - `secret.ml`: Secret data structures and parsing
  - `age.ml`: age encryption wrapper
  - `template.ml` + `template_*.ml`: Template substitution system
  - `path.ml`: Path utilities
  - `shell.ml`: System interaction
  - `dirtree.ml`: Directory tree operations

## Key Features
- Age-based encryption with multiple recipients
- Template substitution with `{{{secret_name}}}` syntax
- Group-based recipient management
- Single-line and multi-line secret formats
- Clipboard and QR code output support
- Interactive editing with $EDITOR