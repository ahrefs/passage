# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Passage is a command-line tool for storing and managing access to shared secrets using age encryption. It supports multiple recipients, group management, and template substitution.

## Essential Commands

### Development Workflow
- `make build` - Build the project (uses `dune build`)
- `make test` - Run all tests (uses `dune runtest`)
- `make fmt` - Format code with OCamlformat (uses `dune fmt --auto-promote`)
- `make promote` - Run tests and promote expected outputs
- `make clean` - Clean build artifacts

### Testing
- Tests use cram-style testing in `.t` files
- Run single test: `dune runtest tests/command_name.t`
- Test the compiled binary: `./_build/default/bin/main.exe <command>`
- Test fixtures in `tests/fixtures/` with sample keys and secrets
- Use `make promote` when test outputs need updating

### Dependencies
- Requires `age` encryption tool: `apt install age`
- Install OCaml dependencies: `opam install . --deps-only --with-dev-setup`

## Code Architecture

### Structure
- **bin/main.ml**: Main CLI entry point with all commands organized as modules (Create, Edit, Get, etc.)
- **lib/**: Core library modules:
  - `storage.ml`: Secret storage, encryption/decryption, recipient management
  - `config.ml`: Configuration and environment variables
  - `secret.ml`: Secret data structures and parsing
  - `template.ml` + related files: Template substitution system with `{{{secret_name}}}` syntax
  - `age.ml`: Age encryption wrapper

### Key Patterns
- CLI commands are modules in main.ml using cmdliner for argument parsing
- Library modules provide core functionality, main binary orchestrates CLI calls
- Storage abstraction handles all filesystem operations
- Template system supports both single-line and multi-line secrets with comments

### Code Style
- OCamlformat 0.26.2 with 120-character line length.
- 2-space indentation, snake_case for functions/variables
- Error handling via Result types or descriptive exceptions
- Module names in PascalCase (e.g., `Secret_name`, `Edit_cmd`)

## Task Completion

When completing tasks:
1. Run `make fmt` to format code
2. Run `make build` to ensure compilation
3. Run `make test` to verify tests pass

The project requires age encryption tool and follows established CLI command patterns in main.ml.
