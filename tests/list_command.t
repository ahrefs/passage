  $ . ./setup_fixtures.sh

Should succeed - no path specified
  $ passage list
  00/.secret_starting_with_dot
  00/secret1
  01/00/secret1
  01/00/secret2
  01/secret1
  02/secret1
  $ passage ls
  00/.secret_starting_with_dot
  00/secret1
  01/00/secret1
  01/00/secret2
  01/secret1
  02/secret1

Should succeed - curr dir as path
  $ passage list .
  00/.secret_starting_with_dot
  00/secret1
  01/00/secret1
  01/00/secret2
  01/secret1
  02/secret1
  $ passage ls .
  00/.secret_starting_with_dot
  00/secret1
  01/00/secret1
  01/00/secret2
  01/secret1
  02/secret1

Should succeed - single-level path
  $ passage list 01
  01/00/secret1
  01/00/secret2
  01/secret1
  $ passage ls 01
  01/00/secret1
  01/00/secret2
  01/secret1

Should succeed - single-level path with trailing slash
  $ passage list 01/
  01/00/secret1
  01/00/secret2
  01/secret1
  $ passage ls 01/
  01/00/secret1
  01/00/secret2
  01/secret1

Should succeed - multi-level path
  $ passage list 01/00/secret2
  01/00/secret2
  $ passage ls 01/00/secret2
  01/00/secret2

Should succeed - valid secret path that ends with ..
  $ passage list 01/..
  00/.secret_starting_with_dot
  00/secret1
  01/00/secret1
  01/00/secret2
  01/secret1
  02/secret1
  $ passage ls 01/..
  00/.secret_starting_with_dot
  00/secret1
  01/00/secret1
  01/00/secret2
  01/secret1
  02/secret1

Should succeed - valid secret path that includes .. in the middle
  $ passage list 01/../00
  00/.secret_starting_with_dot
  00/secret1
  $ passage ls 01/../00
  00/.secret_starting_with_dot
  00/secret1

Should fail - path that goes out of the secrets dir
  $ passage list ..
  passage: PATH argument: the path is out of the secrets dir -
           $TESTCASE_ROOT/fixtures
  Usage: passage list [OPTION]… [PATH]
  Try 'passage list --help' or 'passage --help' for more information.
  [124]
  $ passage ls ..
  passage: PATH argument: the path is out of the secrets dir -
           $TESTCASE_ROOT/fixtures
  Usage: passage ls [OPTION]… [PATH]
  Try 'passage ls --help' or 'passage --help' for more information.
  [124]

  $ passage list ../
  passage: PATH argument: the path is out of the secrets dir -
           $TESTCASE_ROOT/fixtures
  Usage: passage list [OPTION]… [PATH]
  Try 'passage list --help' or 'passage --help' for more information.
  [124]
  $ passage ls ../
  passage: PATH argument: the path is out of the secrets dir -
           $TESTCASE_ROOT/fixtures
  Usage: passage ls [OPTION]… [PATH]
  Try 'passage ls --help' or 'passage --help' for more information.
  [124]

  $ passage list /..
  passage: PATH argument: the path is out of the secrets dir -
           $TESTCASE_ROOT/fixtures
  Usage: passage list [OPTION]… [PATH]
  Try 'passage list --help' or 'passage --help' for more information.
  [124]
  $ passage ls /..
  passage: PATH argument: the path is out of the secrets dir -
           $TESTCASE_ROOT/fixtures
  Usage: passage ls [OPTION]… [PATH]
  Try 'passage ls --help' or 'passage --help' for more information.
  [124]

  $ passage list /../
  passage: PATH argument: the path is out of the secrets dir -
           $TESTCASE_ROOT/fixtures
  Usage: passage list [OPTION]… [PATH]
  Try 'passage list --help' or 'passage --help' for more information.
  [124]
  $ passage ls /../
  passage: PATH argument: the path is out of the secrets dir -
           $TESTCASE_ROOT/fixtures
  Usage: passage ls [OPTION]… [PATH]
  Try 'passage ls --help' or 'passage --help' for more information.
  [124]


Should fail - single-level invalid path
  $ passage list invalid_path
  No secrets at $TESTCASE_ROOT/fixtures/secrets/invalid_path
  [1]
  $ passage ls invalid_path
  No secrets at $TESTCASE_ROOT/fixtures/secrets/invalid_path
  [1]

Should fail - multi-level invalid path
  $ passage list 01/invalid_path
  No secrets at $TESTCASE_ROOT/fixtures/secrets/01/invalid_path
  [1]
  $ passage ls 01/invalid_path
  No secrets at $TESTCASE_ROOT/fixtures/secrets/01/invalid_path
  [1]
