  $ . ./setup_fixtures.sh

Setup
  $ echo "contents" | passage create 00/secret
  $ passage get 00/secret
  contents

Should fail - create existing secret
  $ echo "contents" | passage create 00/secret
  E: refusing to create: a secret by that name already exists
  [1]

Should succeed - create a secret in a new folder, with info about recipients added and default recipients to add
  $ echo "contents" | passage create new/secret
  
  I: using recipient group @root for secret new/secret
  I: using recipient bobby.bob for secret new/secret
  
  If you are adding a new secret in a new folder, please keep recipients to a minimum and include the following:
  - @root
  - yourself
  - people who help manage the secret, or people who would have access to it anyway
  - people who need access to do their job
  - servers/clusters that will consume the secret
  
  If the secret is a staging secret, its only recipient should be @everyone.
  
Newly created secrets should have permissions 0o644
  $ stat -c "%a" $PASSAGE_DIR/secrets/new/secret.age
  644

Should succeed - handle secrets with comments too
  $ printf "secret\n\ncomment" | passage create new/single-line
  $ passage get new/single-line
  secret
  $ printf "\ncomment\n\nsecret\nsecret" | passage create new/multi-line
  $ passage get new/multi-line
  secret
  secret

Should fail - create secret with wrong format
  $ echo "" | passage create new/empty
  This secret is in an invalid format: empty secrets are not allowed
  [1]
  $ printf "secret\ncomment" | passage create new/legacy-single-line
  This secret is in an invalid format: single-line secrets with comments should have an empty line between the secret and the comments.
  [1]
  $ printf "\nsecret\ncomment" | passage create new/multi-line-no-secret
  This secret is in an invalid format: multiline: empty secret
  [1]

Should fail - create secret in a directory where we are not a recipient (invariant)
  $ echo "secret" | passage create 01/00/neww
  E: user is not a recipient of 01/00. Please ask one of the following to add you as a recipient:
    poppy.pop
    robby.rob
  E: refusing to create: violates invariant
  [1]

Should succeed - secrets created in directories with groups should be encrypted for the all the members
  $ echo "another secret" | PASSAGE_IDENTITY=poppy.pop.key passage create 03/secret2
  $ passage who -f 03/secret2
  host/a
  poppy.pop
  robby.rob
  tommy.tom
  $ PASSAGE_IDENTITY=robby.rob.key passage get 03/secret2
  another secret
  $ PASSAGE_IDENTITY=tommy.tom.key passage get 03/secret2
  another secret

Should succeed - create single-line secret with comment using --comment flag
  $ echo "mysecret" | passage create new/with-comment --comment "This is a test comment"
  $ passage get new/with-comment
  mysecret
  $ passage cat new/with-comment
  mysecret
  
  This is a test comment

Should succeed - create multi-line secret with comment using --comment flag
  $ printf "\n\nsecret line1\nsecret line2" | passage create new/multi-with-comment --comment "Multi-line secret comment"
  $ passage get new/multi-with-comment
  secret line1
  secret line2
  $ passage cat new/multi-with-comment
  
  Multi-line secret comment
  
  secret line1
  secret line2

Should fail - trying to create a secret with comments on the secret text and the --comment flag
  $ echo "\ncomment\n\nsecret line 1\nsecret line 2" | passage create new/multi-comment --comment "Multi-line secret comment"
  E: secret text already contains comments. Either use the secret text with comments or use the --comment flag.
  [1]
