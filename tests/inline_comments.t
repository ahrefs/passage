  $ . ./setup_fixtures.sh

Test that config_lines correctly handles comments, empty lines, and whitespace
in .keys, .group, and .pub files.

=== .keys files: empty lines, full-line comments, whitespace, and inline comments ===

  $ cat<<EOF > "$PASSAGE_DIR/secrets/00/.keys"
  > # This is a full-line comment
  >   # Indented full-line comment
  > 
  >   bobby.bob # team lead
  >   robby.rob
  > 
  > EOF
  $ passage who 00
  bobby.bob
  robby.rob

Create and decrypt a secret in the folder with the above .keys
  $ passage get 00/secret1
  (00/secret1) secret: single line

=== .group files: empty lines, full-line comments, whitespace, and inline comments ===

  $ cat<<EOF > "$PASSAGE_DIR/keys/commented.group"
  > # group members
  > 
  >   robby.rob # admin
  >   tommy.tom # regular
  > 
  > EOF
  $ passage who @commented
  robby.rob
  tommy.tom

Use the commented group in a .keys file and verify it resolves correctly
  $ cat<<EOF > "$PASSAGE_DIR/secrets/01/00/.keys"
  > @commented
  > EOF
  $ passage who -f 01/00
  robby.rob
  tommy.tom

=== .pub files: inline comments should be stripped ===

Create a .pub key file with an inline comment appended to the actual key
  $ INLINE_PUB_USER="inline.pub.user"
  $ INLINE_PUB_IDENTITY="$INLINE_PUB_USER.key"
  $ age-keygen > "$INLINE_PUB_IDENTITY" 2> /dev/null
  $ PUBKEY=$(age-keygen -y "$INLINE_PUB_IDENTITY")
  $ echo "$PUBKEY # added 2025-01-01" > "$PASSAGE_DIR/keys/$INLINE_PUB_USER.pub"

The key should still work for encryption - inline comment must be stripped
  $ cat<<EOF > "$PASSAGE_DIR/secrets/00/.keys"
  > bobby.bob
  > $INLINE_PUB_USER
  > EOF
  $ cat<<EOF | passage create 00/inline_pub_secret
  > pub inline comment test
  > EOF
  $ PASSAGE_IDENTITY="$INLINE_PUB_IDENTITY" passage get 00/inline_pub_secret
  pub inline comment test

=== .pub files: leading/trailing whitespace should be trimmed ===

  $ WHITESPACE_USER="whitespace.pub.user"
  $ WHITESPACE_IDENTITY="$WHITESPACE_USER.key"
  $ age-keygen > "$WHITESPACE_IDENTITY" 2> /dev/null
  $ WHITESPACE_PUBKEY=$(age-keygen -y "$WHITESPACE_IDENTITY")
  $ echo "  $WHITESPACE_PUBKEY  " > "$PASSAGE_DIR/keys/$WHITESPACE_USER.pub"

  $ cat<<EOF > "$PASSAGE_DIR/secrets/00/.keys"
  > bobby.bob
  > $WHITESPACE_USER
  > EOF
  $ cat<<EOF | passage create 00/whitespace_pub_secret
  > whitespace pub test
  > EOF
  $ PASSAGE_IDENTITY="$WHITESPACE_IDENTITY" passage get 00/whitespace_pub_secret
  whitespace pub test

=== Mixed: all features together in a .keys file ===

  $ cat<<EOF > "$PASSAGE_DIR/secrets/00/.keys"
  > # This is a full-line comment
  >   bobby.bob # primary
  > 
  >   # Another full-line comment
  >   robby.rob # secondary
  > 
  > EOF
  $ passage who 00
  bobby.bob
  robby.rob
