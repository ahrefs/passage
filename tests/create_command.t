  $ . ./setup_fixtures.sh

Setup
  $ echo 'contents' | passage create 00/secret
  $ passage get 00/secret
  contents

Should fail - create existing secret
  $ echo 'contents' | passage create 00/secret
  E: refusing to create: a secret by that name already exists
  [1]

Should succeed - create a secret in a new folder, with info about recipients added and default recipients to add
  $ echo 'contents' | passage create new/secret
  
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
  $ echo 'secret\n\ncomment' | passage create new/single-line
  $ passage get new/single-line
  secret
  $ echo "\ncomment\n\nsecret\nsecret" | passage create new/multi-line
  $ passage get new/multi-line
  secret
  secret

Should fail - create secret with wrong format
  $ echo '' | passage create new/empty
  This secret is in an invalid format: empty secrets are not allowed
  [1]
  $ echo 'secret\ncomment' | passage create new/legacy-single-line
  This secret is in an invalid format: legacy single line secret format. Please use the correct format
  [1]
  $ echo '\nsecret\ncomment' | passage create new/multi-line-no-secret
  This secret is in an invalid format: multiline: empty secret
  [1]

Should fail - create secret in a directory where we are not a recipient (invariant)
  $ echo 'secret' | passage create 01/00/neww
  E: user is not a recipient of 01/00. Please ask someone to add you as a recipient.
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
