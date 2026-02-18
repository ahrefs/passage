# Passage - Project Overview

## Purpose
Passage is a command-line tool for storing and managing access to shared secrets using age encryption. It supports multiple recipients, group management, and template substitution.

## Tech Stack
- **Language**: OCaml 4.14.0 or higher
- **Build System**: Dune (via Makefile wrappers)
- **CLI Framework**: Cmdliner
- **Encryption**: age (external tool)
- **Key Libraries**: Bos (shell), Fpath (paths), FileUtil, Re (regex), Sedlex (lexer), Menhir (parser)
- **Testing**: ppx_expect (expect tests), cram tests (.t files)

## Codebase Structure
- `bin/` - CLI application (main.ml with all commands as Cmdliner modules, prompt.ml, comment_input.ml, retry.ml)
- `lib/` - Core library (exposed as `Passage` module): commands.ml, storage.ml, config.ml, secret.ml, age.ml, path.ml, shell.ml, invariant.ml, validation.ml, util.ml, dirtree.ml, exn.ml, template system
- `lib_test/` - Unit/expect tests
- `tests/` - Cram integration tests (.t files)
- `completions/` - Shell completion scripts (bash + zsh)
