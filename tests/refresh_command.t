  $ . ./setup_fixtures.sh

Encrypt a secret file with identity
  $ TEST_SECRET=test_secret
  $ cat <<EOF | age -r $(age-keygen -y $PASSAGE_IDENTITY) > $PASSAGE_DIR/secrets/$TEST_SECRET.age
  > secret line 1
  > secret line 2
  > secret line 3\123\65
  > EOF

Should refresh $TEST_SECRET
Should skip 01/00/secret1.age, 01/00/secret2.age, 02/secret1.age
Should fail to refresh 00/secret1.age, 01/secret1.age
  $ passage refresh
  age: error: failed to read header: parsing age header: failed to read intro: EOF
  age: report unexpected or unhelpful errors at https://filippo.io/age/report
  W: failed to refresh 00/.secret_starting_with_dot : Failure("age --decrypt --identity $TESTCASE_ROOT/bobby.bob.key : exit code 1")
  age: error: failed to read header: parsing age header: failed to read intro: EOF
  age: report unexpected or unhelpful errors at https://filippo.io/age/report
  W: failed to refresh 00/secret1 : Failure("age --decrypt --identity $TESTCASE_ROOT/bobby.bob.key : exit code 1")
  I: skipping 01/00/secret1
  I: skipping 01/00/secret2
  age: error: failed to read header: parsing age header: failed to read intro: EOF
  age: report unexpected or unhelpful errors at https://filippo.io/age/report
  W: failed to refresh 01/secret1 : Failure("age --decrypt --identity $TESTCASE_ROOT/bobby.bob.key : exit code 1")
  I: skipping 02/secret1
  I: refreshed 1 secrets, skipped 3, failed 3
  $ passage refresh -v
  Attempting to refresh 00/.secret_starting_with_dot
  age: error: failed to read header: parsing age header: failed to read intro: EOF
  age: report unexpected or unhelpful errors at https://filippo.io/age/report
  W: failed to refresh 00/.secret_starting_with_dot : Failure("age --decrypt --identity $TESTCASE_ROOT/bobby.bob.key : exit code 1")
  Attempting to refresh 00/secret1
  age: error: failed to read header: parsing age header: failed to read intro: EOF
  age: report unexpected or unhelpful errors at https://filippo.io/age/report
  W: failed to refresh 00/secret1 : Failure("age --decrypt --identity $TESTCASE_ROOT/bobby.bob.key : exit code 1")
  Attempting to refresh 01/00/secret1
  I: skipping 01/00/secret1
  Attempting to refresh 01/00/secret2
  I: skipping 01/00/secret2
  Attempting to refresh 01/secret1
  age: error: failed to read header: parsing age header: failed to read intro: EOF
  age: report unexpected or unhelpful errors at https://filippo.io/age/report
  W: failed to refresh 01/secret1 : Failure("age --decrypt --identity $TESTCASE_ROOT/bobby.bob.key : exit code 1")
  Attempting to refresh 02/secret1
  I: skipping 02/secret1
  Attempting to refresh test_secret
  I: refreshed 1 secrets, skipped 3, failed 3

Refreshed secrets should have the same permissions as before (0o644)
  $ stat -c "%a" $PASSAGE_DIR/secrets/$TEST_SECRET.age
  644

Secret content should be the same before and after refresh.
  $ passage get $TEST_SECRET
  secret line 1
  secret line 2
  secret line 3\123\65
Secret should be viewable by those specified in .keys after refresh
  $ PASSAGE_IDENTITY="robby.rob.key" passage get $TEST_SECRET
  secret line 1
  secret line 2
  secret line 3\123\65

Should fail - refreshing invalid directory with no secrets
  $ passage refresh invalid_dir
  E: No secrets at $TESTCASE_ROOT/fixtures/secrets/invalid_dir
  [1]

  $ passage refresh
  age: error: failed to read header: parsing age header: failed to read intro: EOF
  age: report unexpected or unhelpful errors at https://filippo.io/age/report
  W: failed to refresh 00/.secret_starting_with_dot : Failure("age --decrypt --identity $TESTCASE_ROOT/bobby.bob.key : exit code 1")
  age: error: failed to read header: parsing age header: failed to read intro: EOF
  age: report unexpected or unhelpful errors at https://filippo.io/age/report
  W: failed to refresh 00/secret1 : Failure("age --decrypt --identity $TESTCASE_ROOT/bobby.bob.key : exit code 1")
  I: skipping 01/00/secret1
  I: skipping 01/00/secret2
  age: error: failed to read header: parsing age header: failed to read intro: EOF
  age: report unexpected or unhelpful errors at https://filippo.io/age/report
  W: failed to refresh 01/secret1 : Failure("age --decrypt --identity $TESTCASE_ROOT/bobby.bob.key : exit code 1")
  I: skipping 02/secret1
  I: refreshed 1 secrets, skipped 3, failed 3

Should succeed - refreshing a specific secret
  $ passage refresh -v $TEST_SECRET
  Attempting to refresh test_secret
  I: refreshed 1 secrets, skipped 0, failed 0

Refreshing a path that has the same name as a secret - should refresh secrets in the path instead of the specific secret
  $ setup_singleline_secret_without_comments dir/secret1
  $ setup_singleline_secret_without_comments dir/secret2
 Create a secret named 'dir', which is also the name of an existing directory
  $ setup_singleline_secret_without_comments dir
  $ passage refresh -v dir
  Attempting to refresh dir/secret1
  Attempting to refresh dir/secret2
  I: refreshed 2 secrets, skipped 0, failed 0
