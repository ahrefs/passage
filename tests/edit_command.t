  $ . ./setup_fixtures.sh

Set up scripts to be used in place of $EDITOR
  $ APPEND_HELLO="./append_hello.sh"
  $ OVERWRITE_WITH_BYE="./overwrite_with_bye.sh"
  $ OVERWRITE_WITH_LONG_TEXT="./overwrite_with_long_text.sh"
  $ CLEAR_FILE="./clear_file.sh"
  $ OVERWRITE_WITH_LONG_TEXT="./overwrite_with_long_text.sh"
  $ echo 'echo HELLO >> $1' > $APPEND_HELLO && chmod +x $APPEND_HELLO
  $ echo 'echo BYE > $1' > $OVERWRITE_WITH_BYE && chmod +x $OVERWRITE_WITH_BYE
  $ echo 'i=0; while [ $i -lt 500 ] ; do echo "line $i" >> $1; i=$((i+1)); done' > $OVERWRITE_WITH_LONG_TEXT && chmod +x $OVERWRITE_WITH_LONG_TEXT
  $ echo 'printf "" > $1' > $CLEAR_FILE && chmod +x $CLEAR_FILE

Should succeed - edit a secret that does not yet exist
  $ EDITOR=$APPEND_HELLO passage edit new_secret
  $ passage get new_secret
  HELLO

  $ EDITOR=$OVERWRITE_WITH_BYE passage edit new_secret
  $ passage get new_secret
  BYE

Newly created secrets should have permissions 0o644
  $ stat -c "%a" $PASSAGE_DIR/secrets/new_secret.age
  644

Should succeed - edit an existing secret
  $ EDITOR=$APPEND_HELLO passage edit new_secret
  $ passage get new_secret
  BYE
  HELLO

  $ EDITOR=$OVERWRITE_WITH_BYE passage edit new_secret
  $ passage get new_secret
  BYE

Should fail - setting secret as an empty file
  $ EDITOR=$CLEAR_FILE passage edit new_secret
  I: secret unchanged
  [1]
  $ passage get new_secret
  BYE

Should fail - editing an existing secret which user is not authorised to view
  $ UNAUTHORISED_USER="unauthorised"
  $ setup_identity $UNAUTHORISED_USER false
  $ EDITOR=$APPEND_HELLO PASSAGE_IDENTITY=$UNAUTHORISED_USER.key passage edit new_secret
  age: error: no identity matched any of the recipients
  age: report unexpected or unhelpful errors at https://filippo.io/age/report
  E: failed to decrypt new_secret : Failure("age --decrypt --identity $TESTCASE_ROOT/unauthorised.key : exit code 1")
  [1]
  $ passage get new_secret
  BYE

After editing a secret such that the length of the encrypted text is shorter than before:
newly encrypted text should not have leftover content from previous encrypted text
  $ EDITOR=$OVERWRITE_WITH_LONG_TEXT passage edit long_to_short_secret
  $ passage get long_to_short_secret | wc -l
  500
  $ check_age_file_format $PASSAGE_DIR/secrets/long_to_short_secret.age
  OK: age file starts with expected -----BEGIN AGE ENCRYPTED FILE-----
  OK: age file only has 1 occurrence of -----BEGIN AGE ENCRYPTED FILE-----
  OK: age file ends with expected -----END AGE ENCRYPTED FILE-----
  OK: age file only has 1 occurrence of -----END AGE ENCRYPTED FILE-----

  $ EDITOR=$OVERWRITE_WITH_BYE passage edit long_to_short_secret
  $ passage get long_to_short_secret
  BYE
  $ check_age_file_format $PASSAGE_DIR/secrets/long_to_short_secret.age
  OK: age file starts with expected -----BEGIN AGE ENCRYPTED FILE-----
  OK: age file only has 1 occurrence of -----BEGIN AGE ENCRYPTED FILE-----
  OK: age file ends with expected -----END AGE ENCRYPTED FILE-----
  OK: age file only has 1 occurrence of -----END AGE ENCRYPTED FILE-----
