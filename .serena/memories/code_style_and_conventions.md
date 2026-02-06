# Passage - Code Style & Conventions

## Key Principles
- Lib-first: core functionality in `lib/`, CLI orchestration in `bin/`
- Option/Result combinators over verbose pattern matching
- Type-specific comparison (String.equal, Int.equal) not polymorphic (=)
- Labeled arguments for >2 params or unclear args
- No catch-all patterns with variants or booleans
- Module naming: singular, primary type `t`
- No comments for self-documenting code or explaining prompt instructions
- Functions under ~50 lines
- Always use ocamlformat

## Error Handling
- Result types for expected errors
- Exceptions for truly exceptional conditions
- `Exn.die` for formatted error messages
- Never use: List.hd, List.tl, Option.get, Str module, Obj.magic

## Module File Order
1. Global opens
2. Module definitions/aliases
3. Type aliases
4. Function aliases
5. Rest of code

## Testing
- ppx_expect for unit tests (lib_test/)
- Cram tests (.t files) for CLI integration tests (tests/)
- Always test new features

## Task Completion
- Edit AGENTS.md Structure section if repo structure changes
- All changes must pass: `make clean build test fmt`
