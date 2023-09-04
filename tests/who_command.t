  $ . ./setup_fixtures.sh

Should succeed - no path specified
  $ passage who
  W: no keys found for user.with.missing.key
  bobby.bob
  robby.rob
  dobby.dob
  tommy.tom
  user.with.missing.key

Should succeed - curr dir as path
  $ passage who .
  W: no keys found for user.with.missing.key
  bobby.bob
  robby.rob
  dobby.dob
  tommy.tom
  user.with.missing.key

Should succeed and should list contents of .keys file in parent directory if specified dir does not have .keys
  $ passage who 00
  W: no keys found for user.with.missing.key
  bobby.bob
  robby.rob
  dobby.dob
  tommy.tom
  user.with.missing.key

Should succeed and should list contents of .keys file in parent directory if specified dir does not have .keys, even if subdir has .keys
  $ passage who 01
  W: no keys found for user.with.missing.key
  bobby.bob
  robby.rob
  dobby.dob
  tommy.tom
  user.with.missing.key

Should succeed - subdir with .keys file
  $ passage who 01/00
  robby.rob
  poppy.pop

Should succeed - passing specific secret with .keys file in dir
  $ passage who 01/00/secret1
  robby.rob
  poppy.pop

Should succeed even with non_existent path
  $ passage who non_existent_path
  W: no keys found for user.with.missing.key
  bobby.bob
  robby.rob
  dobby.dob
  tommy.tom
  user.with.missing.key

Should succeed even with non_existent path (multi-level)
  $ passage who 01/00/non_existent_path
  robby.rob
  poppy.pop

Should succeed - valid secret path that ends with ..
  $ passage who 01/..
  W: no keys found for user.with.missing.key
  bobby.bob
  robby.rob
  dobby.dob
  tommy.tom
  user.with.missing.key

Should succeed - valid secret path that includes .. in the middle
  $ passage who 01/../00
  W: no keys found for user.with.missing.key
  bobby.bob
  robby.rob
  dobby.dob
  tommy.tom
  user.with.missing.key

Should fail - empty .keys file
  $ passage who 02
  E: no usable keys found for $TESTCASE_ROOT/fixtures/secrets/02
  [1]

Should fail - cannot find any usable .keys file
  $ PASSAGE_SECRETS=./fixtures/secrets/00 passage who .
  E: failed to get recipients : Failure("$TESTCASE_ROOT/fixtures/secrets/00 doesn't exist, i.e. no keys specified for $TESTCASE_ROOT/fixtures/secrets/00")
  [1]

Should fail - path that goes out of secrets dir
  $ passage who ..
  passage: PATH argument: the path is out of the secrets dir -
           $TESTCASE_ROOT/fixtures
  Usage: passage who [OPTION]… [PATH]
  Try 'passage who --help' or 'passage --help' for more information.
  [124]

  $ passage who ../
  passage: PATH argument: the path is out of the secrets dir -
           $TESTCASE_ROOT/fixtures
  Usage: passage who [OPTION]… [PATH]
  Try 'passage who --help' or 'passage --help' for more information.
  [124]

  $ passage who /..
  passage: PATH argument: the path is out of the secrets dir -
           $TESTCASE_ROOT/fixtures
  Usage: passage who [OPTION]… [PATH]
  Try 'passage who --help' or 'passage --help' for more information.
  [124]

  $ passage who /../
  passage: PATH argument: the path is out of the secrets dir -
           $TESTCASE_ROOT/fixtures
  Usage: passage who [OPTION]… [PATH]
  Try 'passage who --help' or 'passage --help' for more information.
  [124]

Should fail - sneaky path
  $ passage who /../01
  W: no keys found for user.with.missing.key
  bobby.bob
  robby.rob
  dobby.dob
  tommy.tom
  user.with.missing.key
