  $ . ./setup_fixtures.sh
Set up secrets without comments
  $ setup_singleline_secret_without_comments "secret_abc"
  $ setup_multiline_secret_without_comments "secret_def"
Set up secrets with comments
  $ setup_singleline_secret_with_comments "secret_ghi"
  $ setup_multiline_secret_with_comments "secret_jkl"
  $ setup_multiline_secret_with_comments "secret_mno"

No path specified - should search all secrets and list secrets with comments
  $ passage search "comment"
  W: failed to search 00/.secret_starting_with_dot : Failure("age --decrypt --identity $TESTCASE_ROOT/bobby.bob.key : exit code 1")
  W: failed to search 00/secret1 : Failure("age --decrypt --identity $TESTCASE_ROOT/bobby.bob.key : exit code 1")
  W: failed to search 01/secret1 : Failure("age --decrypt --identity $TESTCASE_ROOT/bobby.bob.key : exit code 1")
  I: skipped 3 secrets, failed to search 3 secrets and matched 3 secrets
  secret_ghi
  secret_jkl
  secret_mno

Path specified - should search only in specified path
  $ passage search "comment" 00
  W: failed to search 00/.secret_starting_with_dot : Failure("age --decrypt --identity $TESTCASE_ROOT/bobby.bob.key : exit code 1")
  W: failed to search 00/secret1 : Failure("age --decrypt --identity $TESTCASE_ROOT/bobby.bob.key : exit code 1")
  I: skipped 0 secrets, failed to search 2 secrets and matched 0 secrets

Regex specified as pattern  - should list all multiline secrets
  $ passage search -v "secret: line (1|2)"
  W: failed to search 00/.secret_starting_with_dot : Failure("age --decrypt --identity $TESTCASE_ROOT/bobby.bob.key : exit code 1")
  W: failed to search 00/secret1 : Failure("age --decrypt --identity $TESTCASE_ROOT/bobby.bob.key : exit code 1")
  I: skipped 01/00/secret1
  I: skipped 01/00/secret2
  W: failed to search 01/secret1 : Failure("age --decrypt --identity $TESTCASE_ROOT/bobby.bob.key : exit code 1")
  I: skipped 02/secret1
  I: skipped 3 secrets, failed to search 3 secrets and matched 3 secrets
  secret_def
  secret_jkl
  secret_mno

Invalid regex specified as pattern
  $ passage search "["
  passage: PATTERN argument: missing ]: [
  Usage: passage search [--verbose] [OPTION]… PATTERN [PATH]
  Try 'passage search --help' or 'passage --help' for more information.
  [124]
  $ passage search "**"
  passage: PATTERN argument: no argument for repetition operator: *
  Usage: passage search [--verbose] [OPTION]… PATTERN [PATH]
  Try 'passage search --help' or 'passage --help' for more information.
  [124]
