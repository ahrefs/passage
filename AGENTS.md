# AGENTS.md

## Project Overview

Passage is a command-line tool for storing and managing access to shared secrets using age encryption. It supports multiple recipients, group management, and template substitution.

## Essential Commands

### Development Workflow

If there's a `make` command available, don't use dune or opam directly. Available commands:
- `make build` - Build the project (uses `dune build`)
- `make test` - Run all tests (uses `dune runtest`)
- `make fmt` - Format code with OCamlformat (uses `dune fmt --auto-promote`)
- `make promote` - Run tests and promote expected outputs
- `make clean` - Clean build artifacts

### Testing
- Tests use cram-style testing in `.t` files
- Run single test: `dune runtest tests/command_name.t`
- Test the compiled binary: `dune exec passage`
- Use `make promote` when test outputs need updating

### Dependencies
- Dependencies should already be installed before you start working on this project, but if you find they are missing:
- Requires `age` encryption tool: `apt install age`
- Install OCaml dependencies: `opam install . --deps-only --with-dev-setup`

## Code Architecture

### Structure

**bin/** - CLI application:
- `main.ml` - Entry point with all commands as Cmdliner modules (Add_who, Create, Edit_cmd, Get, Healthcheck, Init, List_, New, Realpath, Refresh, Replace, Rm, Search, Show, Subst, Template_cmd, What, Who, etc.)
- `prompt.ml` - Terminal prompts, yes/no dialogs, stdin input validation, editor integration for interactive editing
- `comment_input.ml` - Helper for capturing multi-line comment input from users
- `retry.ml` - Encryption retry logic with error recovery

**lib/** - Core library (exposed as `Passage` module):
- `commands.ml` - High-level command implementations (Init, Get, List_, Recipients, Refresh, Template, Realpath, Rm, Search, Show, Edit, Create, Replace)
- `storage.ml` - Secret storage abstraction with Secret_name, Keys, and Secrets submodules for filesystem operations, encryption/decryption, recipient management
- `config.ml` - Configuration via environment variables (PASSAGE_DIR, PASSAGE_KEYS, PASSAGE_SECRETS, PASSAGE_IDENTITY)
- `secret.ml` - Secret data structures (Singleline/Multiline kinds), parsing, and validation
- `age.ml` - Age encryption wrapper (Key module, recipient type, encrypt/decrypt operations)
- `path.ml` - Path abstraction for safe filesystem path manipulation
- `shell.ml` - Shell command execution, clipboard operations (xclip), process management
- `invariant.ml` - Security invariants (permission checks, recipient verification before operations)
- `validation.ml` - Input validation for secrets, comments, and recipients
- `util.ml` - Utility functions (Show, Recipients, Secret helper submodules)
- `dirtree.ml` - Directory tree representation for the `show` command's tree output
- `exn.ml` - Exception handling utilities
- Template system:
  - `template.ml` - Template parsing and secret substitution
  - `template_ast.ml` - AST types (Iden for `{{{secret}}}`, Text for literals)
  - `template_lexer.ml` - Sedlex-based Unicode lexer
  - `template_parser.mly` - Menhir parser for `{{{secret_name}}}` syntax

### Key Patterns
- This repo is meant to be lib-first, so it can be used by lib consumers too, not only in the `bin` folder. Make sure that the patterns used in `/lib` code reflect the best practices for that.
- Library modules provide core functionality, main binary orchestrates CLI calls
- CLI commands are modules in main.ml using cmdliner for argument parsing
- Storage abstraction handles all filesystem operations
- Template system supports both single-line and multi-line secrets with comments

### Code Style
- Follow @.cursor/rules/code-style.mdc
- Don't add comments to code if:
  - You are repeating prompt instructions or explaining your thought process, rather than the functionality being implemented
  - You are explainining very simple logics or repeating what imperative, self-documenting code is doing
  - You are commenting on simple code branches

### Cyclic dependencies

On some cases, using functions from the util modules can result in cyclic dependencies. Some files have workarounds already, eg by copying some of the functions code rather than using the function.This is ok, as long as you are not copying a huge piece of code over.

When this situation arises, present your solution idea and ask for guidance on what to do.

## Task Completion

**CRUCIAL**:
- If you make changes that affect the repo structure, edit this file and add them to the `Structure` section above.
- If you're adding new features, make sure that they are correctly tested, and that those tests pass.
- No task is complete until `make clean build test fmt` runs successfully (i.e. exit status code 0).

If you are asked not to introduce any functional changes, then you are not allowed to edit existing tests, only add new ones (in case you need new test cases). In this case, old tests must not be changed, even if new tests are added.
