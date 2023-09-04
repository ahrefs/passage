  $ . ./setup_fixtures.sh

Should succeed - replace a secret that does not yet exist
  $ cat<<EOF | passage replace new_secret
  > new secret line 1
  > new secret line 2
  > new secret line 3\123\65
  > EOF
  $ passage get new_secret
  new secret line 1
  new secret line 2
  new secret line 3\123\65

Newly created secrets should have permissions 0o644
  $ stat -c "%a" $PASSAGE_DIR/secrets/new_secret.age
  644

Should succeed - replacing an existing secret
  $ cat<<EOF | passage replace new_secret
  > replaced secret line 1
  > replaced secret line 2
  > replaced secret line 3\123\65
  > EOF
  $ passage get new_secret
  replaced secret line 1
  replaced secret line 2
  replaced secret line 3\123\65

Should succeed - replacing a secret with empty input
  $ printf "" | passage replace new_secret
  $ passage get new_secret

Should succeed - replacing a secret which one is not authorised to. Secret should still be viewable only by authorised users
  $ UNAUTHORISED_USER="unauthorised"
  $ setup_identity $UNAUTHORISED_USER false
  $ cat<<EOF | PASSAGE_IDENTITY=$UNAUTHORISED_USER.key passage replace new_secret
  > unauthorised replace 1
  > unauthorised replace 2
  > EOF
  $ PASSAGE_IDENTITY=$UNAUTHORISED_USER.key passage get new_secret
  age: error: no identity matched any of the recipients
  age: report unexpected or unhelpful errors at https://filippo.io/age/report
  E: failed to decrypt new_secret : Failure("age --decrypt --identity $TESTCASE_ROOT/unauthorised.key : exit code 1")
  [1]
  $ PASSAGE_IDENTITY="bobby.bob.key" passage get new_secret
  unauthorised replace 1
  unauthorised replace 2
