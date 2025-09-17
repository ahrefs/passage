# Passage Codebase Refactoring Analysis

## Key Redundancies Identified

### 1. Path/Name Conversion Functions
- `show_path` appears in both main.ml and invariant.ml - identical implementation
- `show_name` appears in both main.ml and invariant.ml - identical implementation  
- These are used extensively throughout the codebase for display/conversion

### 2. Validation Logic Duplication
- validate_secret, validate_comments in main.ml Prompt module
- Secret.Validation module in lib/secret.ml
- Recipients validation in main.ml that could be unified

### 3. Recipient Management
- get_expanded_recipient_names_from_folder in invariant.ml
- get_expanded_recipient_names in storage.ml
- Similar logic patterns repeated

### 4. General Utilities in Main
- diff_intersect_lists - general list utility
- with_secure_tmpfile - secure temporary file handling
- encrypt_with_retry - retry logic pattern

### 5. User Interaction (Prompt module)
- Currently in main.ml but is reusable
- Contains TTY detection, user input, validation loops

## Abstraction Opportunities

1. **Display module** - for all show_* functions
2. **Validation module** - unified validation for all types
3. **Recipients module** - centralized recipient management
4. **Utils module** - general list/file utilities
5. **Prompt module** - move to lib for reuse
6. **Retry module** - generalized retry patterns