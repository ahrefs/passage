# Task Completion Checklist

When completing development tasks on this OCaml project, ensure:

## Code Quality
1. **Format code**: Run `make fmt` or `dune fmt --auto-promote` to apply OCamlformat
2. **Build successfully**: Run `make build` or `dune build` to ensure compilation
3. **Run tests**: Execute `make test` or `dune runtest` to verify all tests pass
4. **Promote test outputs**: Use `make promote` if test outputs need updating

## Testing Requirements
- Tests use cram-style testing in `.t` files
- Test fixtures are in `tests/fixtures/` and should not be modified unless necessary
- New functionality should include appropriate test coverage
- Run specific tests with `dune runtest tests/specific_test.t`

## Dependencies
- Age encryption tool must be installed (`apt install age`)
- OCaml >= 4.14 required
- All opam dependencies installed via `opam install . --deps-only --with-dev-setup`

## Code Review Points
- Follow established patterns in `bin/main.ml` for CLI commands
- Use library modules in `lib/` for core functionality
- Maintain separation between CLI orchestration and business logic
- Ensure proper error handling and user-friendly error messages