  $ . ./setup_fixtures.sh

Should show full filesystem path for existing secrets
  $ passage realpath 00/secret1
  $TESTCASE_ROOT/fixtures/secrets/00/secret1.age

Should show full filesystem path for existing directories
  $ passage realpath 00
  $TESTCASE_ROOT/fixtures/secrets/00/

Should show full filesystem path for current directory
  $ passage realpath .
  $TESTCASE_ROOT/fixtures/secrets/

Should show full filesystem path for multiple secrets and directories
  $ passage realpath 00/secret1 01 02/secret1
  $TESTCASE_ROOT/fixtures/secrets/00/secret1.age
  $TESTCASE_ROOT/fixtures/secrets/01/
  $TESTCASE_ROOT/fixtures/secrets/02/secret1.age

Should warn for non-existent secrets/folders
  $ passage realpath non/existent
  W: real path of secret/folder "non/existent" not found

Should handle mix of existing and non-existing paths
  $ passage realpath 00/secret1 non/existent 01
  $TESTCASE_ROOT/fixtures/secrets/00/secret1.age
  $TESTCASE_ROOT/fixtures/secrets/01/
  W: real path of secret/folder "non/existent" not found
