  $ . ./setup_fixtures.sh

Set up scripts to be used in place of $EDITOR
  $ APPEND_HELLO="./append_hello.sh"
  $ OVERWRITE_WITH_BYE="./overwrite_with_bye.sh"
  $ LONG_TEXT="./long_text.sh"
  $ CLEAR_FILE="./clear_file.sh"
  $ MALFORMED_MULTILINE1="./malformed_multiline1.sh"
  $ MALFORMED_MULTILINE2="./malformed_multiline2.sh"
  $ LEGACY_SINGLELINE="./legacy_singleline.sh"
  $ echo 'echo HELLO >> $1' > $APPEND_HELLO && chmod +x $APPEND_HELLO
  $ echo 'echo BYE > $1' > $OVERWRITE_WITH_BYE && chmod +x $OVERWRITE_WITH_BYE
  $ echo 'printf "secret\n\n"; i=0; while [ $i -lt 500 ] ; do echo "line $i"; i=$((i+1)); done' >> $LONG_TEXT && chmod +x $LONG_TEXT
  $ echo 'echo "" > $1' > $CLEAR_FILE && chmod +x $CLEAR_FILE
  $ echo 'printf "\ncommments" > $1' > $MALFORMED_MULTILINE1 && chmod +x $MALFORMED_MULTILINE1
  $ echo 'printf "\ncomments\n\n" > $1' > $MALFORMED_MULTILINE2 && chmod +x $MALFORMED_MULTILINE2
  $ echo 'printf "secret\ncomment1\ncomment2" > $1' > $LEGACY_SINGLELINE && chmod +x $LEGACY_SINGLELINE
  $ echo "HELLO" | passage create 00/existing_secret
  $ $LONG_TEXT | passage create 00/long_to_short_secret

Should fail - edit a secret that does not yet exist
  $ EDITOR=$APPEND_HELLO passage edit non_existent_secret
  E: no such secret: non_existent_secret.  Use "new" or "create" for new secrets.
  [1]
  $ passage get non_existent_secret
  E: no such secret: non_existent_secret
  [1]

Should succeed - edit an existing secret
  $ passage get 00/existing_secret
  HELLO

  $ EDITOR=$OVERWRITE_WITH_BYE passage edit 00/existing_secret
  $ passage get 00/existing_secret
  BYE

Should fail - passing in malformed secrets
  $ EDITOR=$CLEAR_FILE passage edit 00/existing_secret
  This secret is in an invalid format: empty secrets are not allowed
  [1]
  $ EDITOR=$MALFORMED_MULTILINE1 passage edit 00/existing_secret
  This secret is in an invalid format: multiline: empty secret
  [1]
  $ EDITOR=$MALFORMED_MULTILINE2 passage edit 00/existing_secret
  This secret is in an invalid format: multiline: empty secret
  [1]
  $ EDITOR=$LEGACY_SINGLELINE passage edit 00/existing_secret
  This secret is in an invalid format: legacy single line secret format. Please use the correct format
  [1]
  $ passage get 00/existing_secret
  BYE

Should fail - editing an existing secret which user is not authorised to view (invariant)
  $ UNAUTHORISED_USER="unauthorised"
  $ setup_identity $UNAUTHORISED_USER
  $ EDITOR=$APPEND_HELLO PASSAGE_IDENTITY=$UNAUTHORISED_USER.key passage edit 00/existing_secret
  E: user is not a recipient of 00. Please ask someone to add you as a recipient.
  E: refusing to edit secret: violates invariant
  [1]
  $ passage get 00/existing_secret
  BYE

After editing a secret such that the length of the encrypted text is shorter than before:
newly encrypted text should not have leftover content from previous encrypted text
  $ passage cat 00/long_to_short_secret | wc -l
  502
  $ check_age_file_format $PASSAGE_DIR/secrets/00/long_to_short_secret.age
  OK: age file starts with expected -----BEGIN AGE ENCRYPTED FILE-----
  OK: age file only has 1 occurrence of -----BEGIN AGE ENCRYPTED FILE-----
  OK: age file ends with expected -----END AGE ENCRYPTED FILE-----
  OK: age file only has 1 occurrence of -----END AGE ENCRYPTED FILE-----

  $ EDITOR=$OVERWRITE_WITH_BYE passage edit 00/long_to_short_secret
  $ passage get 00/long_to_short_secret
  BYE
  $ check_age_file_format $PASSAGE_DIR/secrets/00/long_to_short_secret.age
  OK: age file starts with expected -----BEGIN AGE ENCRYPTED FILE-----
  OK: age file only has 1 occurrence of -----BEGIN AGE ENCRYPTED FILE-----
  OK: age file ends with expected -----END AGE ENCRYPTED FILE-----
  OK: age file only has 1 occurrence of -----END AGE ENCRYPTED FILE-----

EDIT - should allow users of a group to edit an existing secret
  $ PASSAGE_IDENTITY=robby.rob.key passage get 03/secret1
  (03/secret1) secret: single line

  $ PASSAGE_IDENTITY=robby.rob.key EDITOR=$OVERWRITE_WITH_BYE passage edit 03/secret1
  $ PASSAGE_IDENTITY=tommy.tom.key EDITOR=$OVERWRITE_WITH_BYE passage edit 03/secret1
  I: secret unchanged
  [1]
  $ PASSAGE_IDENTITY=robby.rob.key passage get 03/secret1
  BYE
