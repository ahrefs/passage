  $ . ./setup_fixtures.sh

Set up secrets with initial recipients for add-who testing based on edit state
  $ APPEND_ROBBY="./APPEND_ROBBY.sh"
  $ echo 'echo robby.rob >> $1' > $APPEND_ROBBY && chmod +x $APPEND_ROBBY
  $ APPEND_BOBBY="./APPEND_BOBBY.sh"
  $ echo 'echo bobby.bob >> $1' > $APPEND_BOBBY && chmod +x $APPEND_BOBBY
  $ EDITOR=$APPEND_ROBBY passage edit-who 02/secret1
  I: refreshed 1 secrets, skipped 0, failed 0
  $ PASSAGE_IDENTITY=robby.rob.key EDITOR=$APPEND_BOBBY passage edit-who 01/00
  I: refreshed 2 secrets, skipped 0, failed 0

Should succeed - add a single recipient to a secret
  $ passage who 02/secret1
  bobby.bob
  robby.rob
  $ passage add-who 02/secret1 poppy.pop
  I: refreshed 1 secrets, skipped 0, failed 0
  I: added 1 recipient
  $ passage who 02/secret1
  bobby.bob
  poppy.pop
  robby.rob

Should succeed - add multiple recipients to a secret
  $ passage who 01/00/secret1
  bobby.bob
  poppy.pop
  robby.rob
  $ passage add-who 01/00/secret1 tommy.tom host/a
  I: refreshed 2 secrets, skipped 0, failed 0
  I: added 2 recipients
  $ passage who 01/00/secret1
  bobby.bob
  host/a
  poppy.pop
  robby.rob
  tommy.tom

Should succeed - add a group to a secret
  $ passage who 02/secret1
  bobby.bob
  poppy.pop
  robby.rob
  $ passage add-who 02/secret1 @root
  I: refreshed 1 secrets, skipped 0, failed 0
  I: added 1 recipient
  $ passage who 02/secret1
  @root
  bobby.bob
  poppy.pop
  robby.rob

Should succeed - no changes when adding existing recipients
  $ passage who 02/secret1
  @root
  bobby.bob
  poppy.pop
  robby.rob
  $ passage add-who 02/secret1 bobby.bob poppy.pop
  I: no changes made - all specified recipients are already present

Should fail - add non-existent recipient
  $ passage add-who 02/secret1 nonexistent.user
  Invalid recipient: nonexistent.user does not exist
  [1]

Should fail - add non-existent group
  $ passage add-who 02/secret1 @nonexistent.group
  Invalid recipient: @nonexistent.group does not exist
  [1]

Should fail - add multiple non-existent recipients
  $ passage add-who 02/secret1 nonexistent.user another.fake.user
  Invalid recipients: nonexistent.user, another.fake.user do not exist
  [1]

Should fail - add recipients to non-existent secret
  $ passage add-who nonexistent/secret bobby.bob
  E: no such secret: nonexistent/secret
  [1]

Should fail - add recipients when user is not a recipient
  $ passage who 03/secret1
  @root
  host/a
  poppy.pop
  $ PASSAGE_IDENTITY=bobby.bob.key passage add-who 03/secret1 poppy.pop
  E: user is not a recipient of 03. Please ask someone to add you as a recipient.
  E: refusing to add recipients: violates invariant
  [1]
