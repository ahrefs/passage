  $ . ./setup_fixtures.sh

Should succeed - append to a secret that does not yet exist
  $ cat<<EOF | passage append new_secret
  > secret line 1
  > secret line 2
  > secret line 3\123\65
  > EOF
  $ passage get new_secret
  secret line 1
  secret line 2
  secret line 3\123\65

Newly created secrets should have permissions 0o644
  $ stat -c "%a" $PASSAGE_DIR/secrets/new_secret.age
  644

Should succeed - append to existing secret
  $ cat<<EOF | passage append new_secret
  > secret line 4
  > secret line 5
  > secret line 6
  > EOF
  $ passage get new_secret
  secret line 1
  secret line 2
  secret line 3\123\65
  secret line 4
  secret line 5
  secret line 6

Should fail - append to existing secret with no user input specified
  $ printf "" | passage append new_secret
  I: secret unchanged
  [1]
  $ passage get new_secret
  secret line 1
  secret line 2
  secret line 3\123\65
  secret line 4
  secret line 5
  secret line 6

Should fail - append to existing secret which user is not authorised to view
  $ UNAUTHORISED_USER="unauthorised"
  $ setup_identity $UNAUTHORISED_USER
  $ cat<<EOF | PASSAGE_IDENTITY=$UNAUTHORISED_USER.key passage append new_secret
  > unauthorised append 1
  > unauthorised append 2
  > EOF
  age: error: no identity matched any of the recipients
  age: report unexpected or unhelpful errors at https://filippo.io/age/report
  E: failed to decrypt new_secret : Failure("age --decrypt --identity $TESTCASE_ROOT/unauthorised.key : exit code 1")
  [1]
  $ passage get new_secret
  secret line 1
  secret line 2
  secret line 3\123\65
  secret line 4
  secret line 5
  secret line 6
