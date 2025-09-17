# Suggested Commands

## Development Commands

### Building
- `make build` or `dune build` - Build the project
- `make watch` or `dune build -w` - Build with file watching

### Testing
- `make test` or `dune runtest` - Run all tests
- `make promote` or `dune build @runtest --auto-promote` - Run tests and promote expected outputs
- `dune runtest tests/specific_test.t` - Run a single test file

### Code Quality
- `make fmt` or `dune fmt --auto-promote` - Format code according to .ocamlformat
- `make clean` or `dune clean` - Clean build artifacts

### Development Tools
- `make top` or `dune utop .` - Start OCaml REPL with project loaded

### Installation Dependencies
- `opam install . --deps-only --with-dev-setup` - Install all dependencies including dev tools
- `apt install age` - Install age encryption tool (required dependency)

## Testing Individual Components
- Tests are in .t files using cram-style testing
- Fixtures are in `tests/fixtures/` with sample keys and secrets
- Use `dune runtest tests/command_name.t` to test specific commands

## Running the Binary
- After building: `_build/default/bin/main.exe` or via `dune exec passage`