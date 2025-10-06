  $ . ./setup_fixtures.sh

Should fail - edit comments of a non-existing secret
  $ echo "new comment" | passage edit-comments 00/nonexistent
  E: no such secret: 00/nonexistent.  Use "new" or "create" for new secrets.
  [1]
  $ echo "new comment" | passage edit-comments newfolder/secret
  E: no such secret: newfolder/secret.  Use "new" or "create" for new secrets.
  [1]

Should succeed - edit comments on a single-line secret without existing comments
  $ setup_singleline_secret_without_comments "00/test_secret"
  $ echo "first comment" | passage edit-comments 00/test_secret
  $ passage cat 00/test_secret
  (00/test_secret) secret: single line
  
  first comment

Should succeed - edit comments on a single-line secret with existing comments
  $ echo "updated comment" | passage edit-comments 00/test_secret
  $ passage cat 00/test_secret
  (00/test_secret) secret: single line
  
  updated comment

Should succeed - edit multiline comments on a single-line secret
  $ echo "line 1 of comment\nline 2 of comment" | passage edit-comments 00/test_secret
  $ passage cat 00/test_secret
  (00/test_secret) secret: single line
  
  line 1 of comment
  line 2 of comment

Should succeed - remove comments from single-line secret
  $ echo "" | passage edit-comments 00/test_secret
  $ passage cat 00/test_secret
  (00/test_secret) secret: single line

Should succeed - add comments back to single-line secret
  $ echo "restored comment" | passage edit-comments 00/test_secret
  $ passage cat 00/test_secret
  (00/test_secret) secret: single line
  
  restored comment

Should succeed - edit comments on multiline secret without existing comments
  $ setup_multiline_secret_without_comments "00/multiline_test"
  $ echo "multiline comment" | passage edit-comments 00/multiline_test
  $ passage cat 00/multiline_test
  
  multiline comment
  
  (00/multiline_test) secret: line 1
  (00/multiline_test) secret: line 2

Should succeed - edit comments on multiline secret with existing comments
  $ setup_multiline_secret_with_comments "00/multiline_with_comments"
  $ echo "updated multiline comment\nsecond line" | passage edit-comments 00/multiline_with_comments
  $ passage cat 00/multiline_with_comments
  
  updated multiline comment
  second line
  
  (00/multiline_with_comments) secret: line 1
  (00/multiline_with_comments) secret: line 2

Should succeed - remove comments from multiline secret
  $ echo "" | passage edit-comments 00/multiline_with_comments
  $ passage cat 00/multiline_with_comments
  
  
  (00/multiline_with_comments) secret: line 1
  (00/multiline_with_comments) secret: line 2

Should fail - comments with empty lines in the middle
  $ echo "first line\n\nsecond line" | passage edit-comments 00/test_secret
  E: empty lines are not allowed in the middle of the comments
  [1]

Should verify secret content unchanged after failed comment edit
  $ passage cat 00/test_secret
  (00/test_secret) secret: single line
  
  restored comment

Should fail - trying to set unchanged comments
  $ echo "restored comment" | passage edit-comments 00/test_secret
  I: comments unchanged

Should fail - edit comments when user is not a recipient
  $ UNAUTHORISED_USER="unauthorised"
  $ setup_identity $UNAUTHORISED_USER
  $ echo "unauthorised comment" | PASSAGE_IDENTITY=$UNAUTHORISED_USER.key passage edit-comments 00/secret1
  E: user is not a recipient of 00. Please ask one of the following to add you as a recipient:
    bobby.bob
    dobby.dob
    robby.rob
    tommy.tom
    user.with.missing.key
  E: refusing to edit comments: violates invariant
  [1]
