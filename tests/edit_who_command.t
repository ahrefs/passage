  $ . ./setup_fixtures.sh

Set up script to be used in place of $EDITOR
  $ APPEND_ROBBY="./APPEND_ROBBY.sh"
  $ echo 'echo robby.rob >> $1' > $APPEND_ROBBY && chmod +x $APPEND_ROBBY
  $ APPEND_BOBBY="./APPEND_BOBBY.sh"
  $ echo 'echo bobby.bob >> $1' > $APPEND_BOBBY && chmod +x $APPEND_BOBBY
  $ KEEP_RECIPIENTS="./KEEP_RECIPIENTS.sh"
  $ printf 'printf "bobby.bob\nrobby.rob" > $1' > $KEEP_RECIPIENTS && chmod +x $KEEP_RECIPIENTS

Should succeed - edit recipients when the user is a recipient of the folder. Refreshes the secrets
  $ PASSAGE_IDENTITY=robby.rob.key passage get 02/secret1
  age: error: no identity matched any of the recipients
  age: report unexpected or unhelpful errors at https://filippo.io/age/report
  E: failed to decrypt 02/secret1 : Failure("age --decrypt --identity $TESTCASE_ROOT/robby.rob.key : exit code 1")
  [1]
  $ passage who 02/secret1
  bobby.bob
  $ EDITOR=$APPEND_ROBBY passage edit-who 02/secret1
  I: refreshed 1 secrets, skipped 0, failed 0
  $ passage who 02/secret1
  bobby.bob
  robby.rob
  $ PASSAGE_IDENTITY=robby.rob.key passage get 02/secret1
  (02/secret1) secret: single line

Should succeed - don't refresh secrets if recipients are not changed
  $ initial_hash=$(md5sum "$PASSAGE_DIR/secrets/02/secret1.age" | awk '{ print $1 }')
  $ passage who 02/secret1
  bobby.bob
  robby.rob
  $ EDITOR=$KEEP_RECIPIENTS passage edit-who 02/secret1
  I: no changes made to the recipients
  $ passage who 02/secret1
  bobby.bob
  robby.rob
  $ new_hash=$(md5sum "$PASSAGE_DIR/secrets/02/secret1.age" | awk '{ print $1 }')
  $ if [ "$initial_hash" = "$new_hash" ]; \
  >  then echo "The hashes are the same."; \
  >  else echo "The hashes are different."; \
  >  fi
  The hashes are the same.

Should fail - edit recipients when the user is not a recipient of the folder
  $ passage who 03/secret1
  @root
  host/a
  poppy.pop
  $ EDITOR=$APPEND_ROBBY passage edit-who 03/secret1
  E: user is not a recipient of 03. Please ask one of the following to add you as a recipient:
    host/a
    poppy.pop
    robby.rob
    tommy.tom
  E: refusing to edit recipients: violates invariant
  [1]

Should succeed - use path to edit recipients instead of secret name
  $ passage get 01/00/secret1
  age: error: no identity matched any of the recipients
  age: report unexpected or unhelpful errors at https://filippo.io/age/report
  E: failed to decrypt 01/00/secret1 : Failure("age --decrypt --identity $TESTCASE_ROOT/bobby.bob.key : exit code 1")
  [1]
  $ passage who 01/00
  poppy.pop
  robby.rob
  $ PASSAGE_IDENTITY=robby.rob.key EDITOR=$APPEND_BOBBY passage edit-who 01/00
  I: refreshed 2 secrets, skipped 0, failed 0
  $ passage who 01/00/secret1
  bobby.bob
  poppy.pop
  robby.rob
  $ passage get 01/00/secret1
  (01/00/secret1) secret: single line

Should succeed - refresh after edits for groups - should work as expected
  $ ROBBY_ONLY="./ROBBY_ONLY.sh"
  $ echo 'echo robby.rob > $1' > $ROBBY_ONLY && chmod +x $ROBBY_ONLY
  $ ROOT_AGAIN="./ROOT_AGAIN.sh"
  $ echo 'echo @root >> $1' > $ROOT_AGAIN && chmod +x $ROOT_AGAIN

  $ PASSAGE_IDENTITY=robby.rob.key EDITOR=$ROBBY_ONLY passage edit-who 03/secret1
  I: refreshed 1 secrets, skipped 0, failed 0
  $ passage who 03/secret1
  robby.rob
  $ passage get 03/secret1
  age: error: no identity matched any of the recipients
  age: report unexpected or unhelpful errors at https://filippo.io/age/report
  E: failed to decrypt 03/secret1 : Failure("age --decrypt --identity $TESTCASE_ROOT/bobby.bob.key : exit code 1")
  [1]
  $ PASSAGE_IDENTITY=robby.rob.key passage get 03/secret1
  (03/secret1) secret: single line
  $ PASSAGE_IDENTITY=robby.rob.key EDITOR=$ROOT_AGAIN passage edit-who 03/secret1
  I: refreshed 1 secrets, skipped 0, failed 0
  $ passage who 03/secret1
  @root
  robby.rob
  $ PASSAGE_IDENTITY=tommy.tom.key passage get 03/secret1
  (03/secret1) secret: single line

Should fail - adding a group that doesn't exist
  $ NO_GROUP="./NO_GROUP.sh"
  $ echo 'echo @no_group >> $1' > $NO_GROUP && chmod +x $NO_GROUP
  $ PASSAGE_IDENTITY=robby.rob.key EDITOR=$NO_GROUP passage edit-who 03/secret1
  Invalid recipient: @no_group does not exist
  [1]

Should not fail - adding a group that already exists
  $ PASSAGE_IDENTITY=robby.rob.key EDITOR=$ROOT_AGAIN passage edit-who 03/secret1
  I: no changes made to the recipients
