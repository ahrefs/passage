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
  secret_ghi
  secret_jkl
  secret_mno
  I: skipped 4 secrets, failed to search 0 secrets and matched 3 secrets
  $ passage search "abc"
  secret_abc
  I: skipped 4 secrets, failed to search 0 secrets and matched 1 secrets

Path specified - should search only in specified path
  $ passage search "comment" 00
  I: skipped 0 secrets, failed to search 0 secrets and matched 0 secrets

Regex specified as pattern  - should list all multiline secrets
  $ passage search -v "secret: line (1|2)"
  I: skipped 01/00/secret1
  I: skipped 01/00/secret2
  I: skipped 03/secret1
  I: skipped 05/secret1
  secret_def
  secret_jkl
  secret_mno
  I: skipped 4 secrets, failed to search 0 secrets and matched 3 secrets

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
