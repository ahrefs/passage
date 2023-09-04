  $ . ./setup_fixtures.sh

Should succeed - no path specified
  $ passage show
  $TESTCASE_ROOT/fixtures/secrets
  |-- 00
  |   |-- .secret_starting_with_dot
  |   `-- secret1
  |-- 01
  |   |-- 00
  |   |   |-- secret1
  |   |   `-- secret2
  |   `-- secret1
  `-- 02
      `-- secret1

Should succeed - curr dir as path
  $ passage show .
  $TESTCASE_ROOT/fixtures/secrets
  |-- 00
  |   |-- .secret_starting_with_dot
  |   `-- secret1
  |-- 01
  |   |-- 00
  |   |   |-- secret1
  |   |   `-- secret2
  |   `-- secret1
  `-- 02
      `-- secret1

Should succeed - single-level path
  $ passage show 01
  $TESTCASE_ROOT/fixtures/secrets/01
  |-- 00
  |   |-- secret1
  |   `-- secret2
  `-- secret1

Should succeed - single-level path with trailing slash
  $ passage show 01/
  $TESTCASE_ROOT/fixtures/secrets/01
  |-- 00
  |   |-- secret1
  |   `-- secret2
  `-- secret1

Should succeed - multi-level path
  $ passage show 01/00
  $TESTCASE_ROOT/fixtures/secrets/01/00
  |-- secret1
  `-- secret2

Should succeed - valid secret path that ends with ..
  $ passage show 01/..
  $TESTCASE_ROOT/fixtures/secrets
  |-- 00
  |   |-- .secret_starting_with_dot
  |   `-- secret1
  |-- 01
  |   |-- 00
  |   |   |-- secret1
  |   |   `-- secret2
  |   `-- secret1
  `-- 02
      `-- secret1

Should succeed - valid secret path that includes .. in the middle
  $ passage show 01/../00
  $TESTCASE_ROOT/fixtures/secrets/00
  |-- .secret_starting_with_dot
  `-- secret1

Should fail - path that goes out of secrets dir
  $ passage show ..
  passage: PATH argument: the path is out of the secrets dir -
           $TESTCASE_ROOT/fixtures
  Usage: passage show [OPTION]… [PATH]
  Try 'passage show --help' or 'passage --help' for more information.
  [124]

  $ passage show ../
  passage: PATH argument: the path is out of the secrets dir -
           $TESTCASE_ROOT/fixtures
  Usage: passage show [OPTION]… [PATH]
  Try 'passage show --help' or 'passage --help' for more information.
  [124]

  $ passage show /..
  passage: PATH argument: the path is out of the secrets dir -
           $TESTCASE_ROOT/fixtures
  Usage: passage show [OPTION]… [PATH]
  Try 'passage show --help' or 'passage --help' for more information.
  [124]

  $ passage show /../
  passage: PATH argument: the path is out of the secrets dir -
           $TESTCASE_ROOT/fixtures
  Usage: passage show [OPTION]… [PATH]
  Try 'passage show --help' or 'passage --help' for more information.
  [124]

Should fail - single-level invalid path
  $ passage show invalid_path
  No secrets at this path : $TESTCASE_ROOT/fixtures/secrets/invalid_path
  [1]

Should fail - multi-level invalid path
  $ passage show 01/invalid_path
  No secrets at this path : $TESTCASE_ROOT/fixtures/secrets/01/invalid_path
  [1]

# Should fail and suggest using get command
  $ passage show 01/00/secret2
  Did you mean : passage get 01/00/secret2
  [1]
