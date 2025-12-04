## 0.3.1 (2025-12-04)
- Add installion state on `passage healthcheck command`
- Add `x-maintenance-intent` policy
- Add centos 10 to opam ci exclusions

## 0.3.0 (2025-12-02)
- Refactor passage to be lib-first. Commands and utility functions are now available for usage by lib users
- Update os availability in opam. Not available in macos anymore.

## 0.2.0 (2025-11-26)
- Update refresh command to handle users and groups via the @<user_or_group> target syntax
- Add --version flag to passage command
- Fix the command description for `new`

## 0.1.8 (2025-10-21)
- deep refactor of the code
  - more code moved to the lib, cleaner main.ml file
  - more abstractions, less indirection
  - updated the editor for reusability and robustness
  - removed lwt, since we don't really have true async code
  - use bos for command running and stdin/stdout/stderr handling
- removed lwt
- updated completions (bash and zsh)

## 0.1.7 (2025-09-15)
- Add --comment flag to the create command
- Add edit-comments command
- Show recipients in "user is not recipient" error
- Add add-who and rm-who commands
- Add groups suggestions to recipients suggestions
- Add `my` command
- Add better handling of bad setup for get and ls
- Improve error handling and message for missing setup
- Better error message when passage isn't setup
- Update Makefile
- Improve README and run linting
- Catch `realpath` error and raise friendlier exception
- Update bash completions
- Add zsh completions

## 0.1.6 (2024-11-28)
- fix small bug with the input_and_validate_loop fn and empty secrets

## 0.1.5 (2024-11-26)
- Add replace-comment command
- Make new and edit commands usage uniform
- Remove bash completions opam install. Moved to debian package.

## 0.1.4 (2024-08-26)
- Add bash completions on install

## 0.1.3 (2024-07-24)
- Add the public_name stanza to the passage lib

## 0.1.2 (2024-07-15)
- Update test config and add opam ci exclusions

## 0.1.1 (2024-07-11)
- Fix merlin dep and template parser

## 0.1.0 (2024-07-07)
- Open source passage
