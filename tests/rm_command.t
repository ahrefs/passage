
  $ . ./setup_fixtures.sh

Setup
Will create all this structure to avoid the noise from the recipients notice when creating the first secrets in folders
  $ mkdir -p "$PASSAGE_DIR/secrets/test"
  $ echo "bobby.bob" > "$PASSAGE_DIR/secrets/test/.keys"
  $ mkdir -p "$PASSAGE_DIR/secrets/test2"
  $ echo "bobby.bob" > "$PASSAGE_DIR/secrets/test2/.keys"
  $ mkdir -p "$PASSAGE_DIR/secrets/test2/test_sub"
  $ echo "bobby.bob" > "$PASSAGE_DIR/secrets/test2/test_sub/.keys"
  $ mkdir -p "$PASSAGE_DIR/secrets/folder"
  $ echo "bobby.bob" > "$PASSAGE_DIR/secrets/folder/.keys"

  $ echo 'contents' | passage create test/new_secret
  $ echo 'contents' | passage create test/new_secret1
  $ echo 'contents' | passage create test/new_secret2
  $ echo 'contents' | passage create test/new_secret3
  $ echo 'contents' | passage create test/new_secret4
  $ echo 'contents' | passage create test/new_secret5
  $ echo 'contents' | passage create folder/new_secret
  $ echo 'contents' | passage create test2/single_secret
  $ echo 'contents' | passage create test2/test_sub/new_secret1
  $ echo 'contents' | passage create test2/test_sub/new_secret2

### For these tests we are always going to usee the -f (force) flag to avoid the prompt

Should delete one secret (quietly, unless -v is used)
  $ passage rm test/new_secret
  $ passage rm -v test/new_secret1
  I: removed test/new_secret1
  $ passage get test/new_secret
  E: no such secret: test/new_secret
  [1]
  $ passage get test/new_secret1
  E: no such secret: test/new_secret1
  [1]

Should delete multiple files at once
  $ passage rm test/new_secret2 test/new_secret3
  $ passage get test/new_secret2
  E: no such secret: test/new_secret2
  [1]
  $ passage get test/new_secret3
  E: no such secret: test/new_secret3
  [1]

Should fail if the secret does not exist
  $ passage rm test/new_secret3
  E: no secrets exist at test/new_secret3
  [1]

Should (physically) delete a whole folder
  $ passage ls test
  test/new_secret4
  test/new_secret5
  $ passage realpath | xargs ls | grep test
  test
  test2
  $ passage rm test
  $ passage ls test
  No secrets at test
  [1]
  $ passage realpath | xargs ls | grep test
  test2

Should (physically) delete the whole folder if there is only one secret in that folder
  $ passage ls folder
  folder/new_secret
  $ passage realpath | xargs ls | grep folder
  folder
  $ passage rm folder/new_secret
  $ passage ls folder
  No secrets at folder
  [1]
  $ passage realpath | xargs ls | grep folder
  [1]

  $ passage ls test2/
  test2/single_secret
  test2/test_sub/new_secret1
  test2/test_sub/new_secret2
  $ passage realpath | xargs ls | grep test2
  test2
  $ passage rm test2/single_secret
  $ passage ls test2/
  test2/test_sub/new_secret1
  test2/test_sub/new_secret2
  $ passage realpath | xargs ls | grep test2
  test2
