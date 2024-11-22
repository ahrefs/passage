  $ . ./setup_fixtures.sh

Should fail - replace comments of a non-existing secret in a new folder - redirects to passage create or new
  $ echo "comment" | passage replace-cmt folder/new
  E: No recipients found (use "passage {create,new} folder/new_secret_name" to use recipients associated with $PASSAGE_IDENTITY instead)
  [1]

Should fail - replace comments of a non-existing secret
  $ echo "comment" | passage replace-cmt 00/secret2
  E: no such secret: 00/secret2
  [1]

Should succeed - replacing a the comments on a single-line secret without comments
  $ echo "replaced comments" | passage replace-cmt 00/secret1
  $ passage cat 00/secret1
  (00/secret1) secret: single line
  
  replaced comments

Should succeed - replacing a the comments on a single-line secret with comments
  $ echo "replaced again comments" | passage replace-cmt 00/secret1
  $ passage cat 00/secret1
  (00/secret1) secret: single line
  
  replaced again comments

Should succeed - replacing single-line comments with multiline comments
  $ echo "replaced again comments\nline 2" | passage replace-cmt 00/secret1
  $ passage cat 00/secret1
  (00/secret1) secret: single line
  
  replaced again comments
  line 2

Should succeed - replacing multiline comments with multiline comments
  $ echo "new comments\nline 2 of said new comments" | passage replace-cmt 00/secret1
  $ passage cat 00/secret1
  (00/secret1) secret: single line
  
  new comments
  line 2 of said new comments

Should succeed - replacing multiline comments with multiline comments - in multiline secret
  $ setup_multiline_secret_with_comments 00/secret2
  $ echo "new comments\nline 2 of said new comments" | passage replace-cmt 00/secret2
  $ passage cat 00/secret2
  
  new comments
  line 2 of said new comments
  
  (00/secret2) secret: line 1
  (00/secret2) secret: line 2

Should fail - comments with empty lines in the middle
  $ echo "uno commento\n\ndos commentos" | passage replace-cmt 00/secret1
  The comments are in an invalid format: secrets cannot have empty lines in the middle of the comments
  [1]
  $ passage cat 00/secret1
  (00/secret1) secret: single line
  
  new comments
  line 2 of said new comments
