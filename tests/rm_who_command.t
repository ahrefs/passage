  $ . ./setup_fixtures.sh

Set up secrets with multiple recipients for testing removal based on edit state
  $ passage add-who 02/secret1 poppy.pop robby.rob @root
  I: refreshed 1 secrets, skipped 0, failed 0
  I: added 3 recipients
  $ PASSAGE_IDENTITY=robby.rob.key passage add-who 01/00/secret1 host/a tommy.tom bobby.bob
  I: refreshed 2 secrets, skipped 0, failed 0
  I: added 3 recipients

RM-WHO COMMAND TESTS

Should succeed - remove a single recipient from a secret
  $ passage who 02/secret1
  @root
  bobby.bob
  poppy.pop
  robby.rob
  $ passage rm-who 02/secret1 poppy.pop
  I: refreshed 1 secrets, skipped 0, failed 0
  I: removed 1 recipient
  $ passage who 02/secret1
  @root
  bobby.bob
  robby.rob

Should succeed - remove multiple recipients from a secret
  $ passage who 01/00/secret1
  bobby.bob
  host/a
  poppy.pop
  robby.rob
  tommy.tom
  $ passage rm-who 01/00/secret1 host/a tommy.tom
  I: refreshed 2 secrets, skipped 0, failed 0
  I: removed 2 recipients
  $ passage who 01/00/secret1
  bobby.bob
  poppy.pop
  robby.rob

Should succeed - remove a group from a secret
  $ passage who 02/secret1
  @root
  bobby.bob
  robby.rob
  $ passage rm-who 02/secret1 @root
  I: refreshed 1 secrets, skipped 0, failed 0
  I: removed 1 recipient
  $ passage who 02/secret1
  bobby.bob
  robby.rob

Should succeed - no changes when removing non-existent recipients
  $ passage who 02/secret1
  bobby.bob
  robby.rob
  $ passage rm-who 02/secret1 nonexistent.user
  W: recipients not found: nonexistent.user

Should succeed - warn about some non-existent recipients but remove others
  $ passage who 01/00/secret1
  bobby.bob
  poppy.pop
  robby.rob
  $ passage rm-who 01/00/secret1 poppy.pop nonexistent.user
  W: recipients not found: nonexistent.user
  I: refreshed 2 secrets, skipped 0, failed 0
  I: removed 1 recipient
  $ passage who 01/00/secret1
  bobby.bob
  robby.rob

Should fail - remove all recipients from a secret
  $ passage who 02/secret1
  bobby.bob
  robby.rob
  $ PASSAGE_IDENTITY=robby.rob.key passage rm-who 02/secret1 bobby.bob robby.rob
  E: cannot remove all recipients - at least one recipient must remain
  [1]

Should fail - remove recipients from non-existent secret
  $ passage rm-who nonexistent/secret bobby.bob
  E: no such secret: nonexistent/secret
  [1]

Should fail - remove recipients when user is not a recipient
  $ passage who 03/secret1
  @root
  host/a
  poppy.pop
  $ PASSAGE_IDENTITY=bobby.bob.key passage rm-who 03/secret1 robby.rob
  E: user is not a recipient of 03. Please ask one of the following to add you as a recipient:
    host/a
    poppy.pop
    robby.rob
    tommy.tom
  E: refusing to remove recipients: violates invariant
  [1]
