# Passage - Suggested Commands

## Development Commands (always use via Makefile)
- `make build` - Build the project
- `make test` - Run all tests
- `make fmt` - Format code with OCamlformat
- `make promote` - Run tests and promote expected outputs
- `make clean` - Clean build artifacts

## When running in worktrees
- Use `opam exec -- make <command>` if the switch is not linked
- Link switch: `opam sw link /home/me/code/opensource/passage`

## Task Completion Check
- `make clean build test fmt` must pass with exit code 0

## Single Test
- `dune runtest tests/command_name.t`

## System Utils
- Standard Linux: `git`, `ls`, `cd`, `rg` (ripgrep for search)
