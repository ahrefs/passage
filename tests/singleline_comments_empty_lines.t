  $ . ./setup_fixtures.sh

Single-line secrets are documented as "secret, empty line, comments until end of file",
but empty lines inside the comments are rejected.

Create a single-line secret with an empty line in its comments
  $ printf "secret\n\ncomment 1\n\ncomment 2\n" | passage create 00/singleline_empty_line_comments
  E: this secret is in an invalid format: empty lines are not allowed in comments
  [1]

Edit a single-line secret to add an empty line in its comments
  $ ADD_EMPTY_LINE_COMMENTS="./add_empty_line_comments.sh"
  $ echo 'printf "secret\n\ncomment 1\n\ncomment 2\n" > $1' > $ADD_EMPTY_LINE_COMMENTS && chmod +x $ADD_EMPTY_LINE_COMMENTS
  $ setup_singleline_secret_with_comments 00/singleline_with_comments
  $ EDITOR=$ADD_EMPTY_LINE_COMMENTS passage edit 00/singleline_with_comments
  E: this secret is in an invalid format: empty lines are not allowed in comments
  [1]

An existing secret with an empty line in its comments (e.g. written before validation existed)
  $ printf "secret\n\ncomment 1\n\ncomment 2\n" | age -e -a -R $PASSAGE_DIR/keys/$BOBBY.pub -o $PASSAGE_DIR/secrets/02/existing.age
  $ passage cat 02/existing
  secret
  
  comment 1
  
  comment 2
  $ passage healthcheck 2>&1 | grep 02/existing
  ❌ 02/existing [ invalid format: empty lines are not allowed in comments ]

Editing it without changing anything
  $ EDITOR=true passage edit 02/existing
  E: this secret is in an invalid format: empty lines are not allowed in comments
  [1]
