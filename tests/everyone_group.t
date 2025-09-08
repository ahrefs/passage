  $ . ./setup_fixtures.sh

WHO should return all the identities
  $ passage who 04
  @everyone
  $ passage who -f 04
  bobby.bob
  dobby.dob
  host/a
  poppy.pop
  robby.rob
  tommy.tom
  $ passage who @everyone
  bobby.bob
  dobby.dob
  host/a
  poppy.pop
  robby.rob
  tommy.tom

GET, CAT - should allow all the users to decrypt
  $ PASSAGE_IDENTITY=bobby.bob.key passage get 04/secret1
  (04/secret1) secret: single line
  $ PASSAGE_IDENTITY=dobby.dob.key passage get 04/secret1
  (04/secret1) secret: single line
  $ PASSAGE_IDENTITY=poppy.pop.key passage get 04/secret1
  (04/secret1) secret: single line
  $ PASSAGE_IDENTITY=robby.rob.key passage get 04/secret1
  (04/secret1) secret: single line
  $ PASSAGE_IDENTITY=tommy.tom.key passage get 04/secret1
  (04/secret1) secret: single line
  $ PASSAGE_IDENTITY=user.with.missing.key passage get 04/secret1
  E: failed to decrypt 04/secret1 : Failure("no identity file found. Is passage setup? Try 'passage init'.")
  [1]

EDIT - should allow everyone to edit an existing secret
  $ OVERWRITE_WITH_BYE="./overwrite_with_bye.sh"
  $ echo 'echo BYE > $1' > $OVERWRITE_WITH_BYE && chmod +x $OVERWRITE_WITH_BYE

  $ passage get 04/secret1
  (04/secret1) secret: single line

  $ PASSAGE_IDENTITY=bobby.bob.key EDITOR=$OVERWRITE_WITH_BYE passage edit 04/secret1
  $ PASSAGE_IDENTITY=dobby.dob.key EDITOR=$OVERWRITE_WITH_BYE passage edit 04/secret1
  I: secret unchanged
  [1]
  $ PASSAGE_IDENTITY=robby.rob.key EDITOR=$OVERWRITE_WITH_BYE passage edit 04/secret1
  I: secret unchanged
  [1]
  $ PASSAGE_IDENTITY=tommy.tom.key EDITOR=$OVERWRITE_WITH_BYE passage edit 04/secret1
  I: secret unchanged
  [1]
  $ passage get 04/secret1
  BYE

EDIT-WHO - should work as expected
  $ ROBBY_ONLY="./ROBBY_ONLY.sh"
  $ echo 'echo robby.rob > $1' > $ROBBY_ONLY && chmod +x $ROBBY_ONLY
  $ EVERYONE_AGAIN="./EVERYONE_AGAIN.sh"
  $ echo 'echo @everyone >> $1' > $EVERYONE_AGAIN && chmod +x $EVERYONE_AGAIN

  $ PASSAGE_IDENTITY=dobby.dob.key EDITOR=$ROBBY_ONLY passage edit-who 04/secret1
  I: refreshed 1 secrets, skipped 0, failed 0
  $ passage who 04/secret1
  robby.rob
  $ passage get 04/secret1
  age: error: no identity matched any of the recipients
  age: report unexpected or unhelpful errors at https://filippo.io/age/report
  E: failed to decrypt 04/secret1 : Failure("age --decrypt --identity $TESTCASE_ROOT/bobby.bob.key : exit code 1")
  [1]
  $ PASSAGE_IDENTITY=robby.rob.key passage get 04/secret1
  BYE
  $ PASSAGE_IDENTITY=robby.rob.key EDITOR=$EVERYONE_AGAIN passage edit-who 04/secret1
  I: refreshed 1 secrets, skipped 0, failed 0
  $ passage get 04/secret1
  BYE

WHAT - works fine for @everyone
  $ passage what @everyone
  04/secret1

REFRESH - works where @everyone is too
  $ PASSAGE_IDENTITY=poppy.pop.key passage refresh -v
  I: skipped 00/.secret_starting_with_dot
  I: skipped 00/secret1
  I: refreshed 01/00/secret1
  I: refreshed 01/00/secret2
  I: skipped 01/secret1
  I: skipped 02/secret1
  I: refreshed 03/secret1
  I: refreshed 04/secret1
  I: refreshed 05/secret1
  I: refreshed 5 secrets, skipped 4, failed 0

TEMPLATE
Set default target file
  $ TARGET="target.txt"

Should succeed - template with secrets owned by the @everyone group
  $ passage template $PASSAGE_DIR/templates/single_secret_for_everyone.txt $TARGET
  $ cat $TARGET
  this is a template with a single secret
  {{{ this_should_not_be_substituted }}}
  TEXT BEFORE SECRET-BYE-TEXT AFTER SECRET
  $ PASSAGE_IDENTITY=robby.rob.key passage template $PASSAGE_DIR/templates/single_secret_for_everyone.txt $TARGET
  $ cat $TARGET
  this is a template with a single secret
  {{{ this_should_not_be_substituted }}}
  TEXT BEFORE SECRET-BYE-TEXT AFTER SECRET
  $ PASSAGE_IDENTITY=poppy.pop.key passage template $PASSAGE_DIR/templates/single_secret_for_everyone.txt $TARGET
  $ cat $TARGET
  this is a template with a single secret
  {{{ this_should_not_be_substituted }}}
  TEXT BEFORE SECRET-BYE-TEXT AFTER SECRET
