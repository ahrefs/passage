# Code Style and Conventions

## OCaml Formatting
- Uses OCamlformat 0.26.2 with custom configuration in `.ocamlformat`
- Line length: 120 characters (`m=120`)
- Max indent: 2 spaces (`max-indent=2`)
- Cases indented by 2 spaces (`cases-exp-indent=2`)
- Sparse type declarations and let-and bindings
- Multi-line-only parentheses for tuples
- Preserve expression grouping

## Code Structure Patterns
- CLI commands organized as modules in `bin/main.ml`
- Each command has its own module (e.g., `Create`, `Edit`, `Get`, etc.)
- Cmdliner used for argument parsing with `term` and `info` definitions
- Error handling typically uses `Result` types or exceptions with clear messages

## Naming Conventions
- Module names: PascalCase (e.g., `Secret_name`, `Edit_cmd`)
- Function names: snake_case (e.g., `get_secret`, `encrypt_exn`)
- Variable names: snake_case with descriptive names
- File names: snake_case.ml

## Architecture Patterns
- Library modules provide core functionality
- Main binary orchestrates CLI and calls library functions  
- Storage abstraction in `storage.ml` handles all file system operations
- Configuration centralized in `config.ml` with environment variable support
- Template system separated into lexer, parser, AST, and processor