  $ . ./setup_fixtures.sh

Should fail - replace a non-existing secret in a new folder - redirects to passage create or new
  $ echo 'secret' | passage replace folder/new
  E: No recipients found (use "passage {create,new} folder/new_secret_name" to use recipients associated with $PASSAGE_IDENTITY instead)
  [1]

Should succeed - replace a secret that does not yet exist in a folder where we are listed on the .keys
  $ echo "new secret" | passage replace 00/new_secret_singleline
  $ passage get 00/new_secret_singleline
  new secret
  $ cat<<EOF | passage replace 00/new_secret_multiline
  > new secret line 1
  > new secret line 2
  > new secret line 3\123\65
  > EOF
  $ passage cat 00/new_secret_multiline
  
  
  new secret line 1
  new secret line 2
  new secret line 3\123\65

Newly created secrets should have permissions 0o644
  $ check_permissions $PASSAGE_DIR/secrets/00/new_secret_singleline.age
  644
  $ check_permissions $PASSAGE_DIR/secrets/00/new_secret_multiline.age
  644

Should fail - replace a secret that does not yet exist in a folder where we are NOT listed on the .keys (invariant)
  $ echo "new secret" | passage replace 01/00/new_secret_singleline
  E: user is not a recipient of 01/00. Please ask someone to add you as a recipient.
  E: refusing to replace secret: violates invariant
  [1]
  $ passage get 01/00/new_secret_singleline
  E: no such secret: 01/00/new_secret_singleline
  [1]
  $ cat<<EOF | passage replace 01/00/new_secret_multiline
  > new secret line 1
  > new secret line 2
  > new secret line 3\123\65
  > EOF
  E: user is not a recipient of 01/00. Please ask someone to add you as a recipient.
  E: refusing to replace secret: violates invariant
  [1]
  $ passage cat 01/00/new_secret_multiline
  E: no such secret: 01/00/new_secret_multiline
  [1]

Should succeed - replacing an existing secret in a folder where we are listed on the .keys
  $ echo "replaced secret" | passage replace 00/new_secret_singleline
  $ passage get 00/new_secret_singleline
  replaced secret

  $ cat<<EOF | passage replace 00/new_secret_multiline
  > replaced secret line 1
  > replaced secret line 2
  > replaced secret line 3\123\65
  > EOF
  $ passage cat 00/new_secret_multiline
  
  
  replaced secret line 1
  replaced secret line 2
  replaced secret line 3\123\65

Should fail - replacing an existing secret in a folder where we are NOT listed on the .keys (invariant)
  $ echo "replaced secret" | passage replace 01/00/secret1
  E: user is not a recipient of 01/00. Please ask someone to add you as a recipient.
  E: refusing to replace secret: violates invariant
  [1]
  $ passage get 01/00/secret1
  age: error: no identity matched any of the recipients
  age: report unexpected or unhelpful errors at https://filippo.io/age/report
  E: failed to decrypt 01/00/secret1 : Failure("age --decrypt --identity $TESTCASE_ROOT/bobby.bob.key : exit code 1")
  [1]
  $ cat<<EOF | passage replace 01/00/secret2
  > replaced secret line 1
  > replaced secret line 2
  > replaced secret line 3\123\65
  > EOF
  E: user is not a recipient of 01/00. Please ask someone to add you as a recipient.
  E: refusing to replace secret: violates invariant
  [1]
  $ passage cat 01/00/secret2
  age: error: no identity matched any of the recipients
  age: report unexpected or unhelpful errors at https://filippo.io/age/report
  E: failed to decrypt 01/00/secret2 : Failure("age --decrypt --identity $TESTCASE_ROOT/bobby.bob.key : exit code 1")
  [1]

Should succeed - replacing a secret with comments, single and multi-line
  $ echo "new secret\n\nnew comments\nmultiple comments" | passage create 01/new_secret_singleline_with_comments
  $ echo "replaced secret" | passage replace 01/new_secret_singleline_with_comments
  $ passage cat 01/new_secret_singleline_with_comments
  replaced secret
  
  new comments
  multiple comments

  $ echo "\nnew comments\nmultiple comments\n\nnew secret\nnew secret line 2" | passage create 01/new_secret_multiline_with_comments
  $ cat<<EOF | passage replace 01/new_secret_multiline_with_comments
  > replaced secret line 1
  > replaced secret line 2
  > replaced secret line 3\123\65
  > EOF
  $ passage cat 01/new_secret_multiline_with_comments
  
  new comments
  multiple comments
  
  replaced secret line 1
  replaced secret line 2
  replaced secret line 3\123\65

Should succeed - replacing a secret of different kind that has comments
  $ cat<<EOF | passage replace 01/new_secret_singleline_with_comments
  > replaced secret line 1
  > replaced secret line 2
  > replaced secret line 3\123\65
  > EOF
  $ passage cat 01/new_secret_singleline_with_comments
  
  new comments
  multiple comments
  
  replaced secret line 1
  replaced secret line 2
  replaced secret line 3\123\65

  $ echo "replaced secret" | passage replace 01/new_secret_singleline_with_comments
  $ passage cat 01/new_secret_singleline_with_comments
  replaced secret
  
  new comments
  multiple comments

Should succeed - replacing a secret of different kind that has no comments
  $ echo "new secret" | passage create 00/new_secret_singleline_no_comments
  $ cat<<EOF | passage replace 00/new_secret_singleline_no_comments
  > replaced secret line 1
  > replaced secret line 2
  > replaced secret line 3\123\65
  > EOF
  $ passage cat 00/new_secret_singleline_no_comments
  
  
  replaced secret line 1
  replaced secret line 2
  replaced secret line 3\123\65

  $ echo "replaced secret" | passage replace 00/new_secret_singleline_no_comments
  $ passage cat 00/new_secret_singleline_no_comments
  replaced secret

Should fail - replacing a secret with empty input
  $ printf "" | passage replace 00/new_secret_singleline
  E: invalid input, empty secrets are not allowed.
  [1]
  $ passage cat 00/new_secret_singleline
  replaced secret

Should fail - trying to replace a secret which one is not authorised to. (invariant)
  $ UNAUTHORISED_USER="unauthorised"
  $ setup_identity $UNAUTHORISED_USER
  $ cat<<EOF | PASSAGE_IDENTITY=$UNAUTHORISED_USER.key passage replace 00/new_secret_multiline
  > unauthorised replace 1
  > unauthorised replace 2
  > EOF
  E: user is not a recipient of 00. Please ask someone to add you as a recipient.
  E: refusing to replace secret: violates invariant
  [1]
  $ PASSAGE_IDENTITY=$UNAUTHORISED_USER.key passage get 00/new_secret_multiline
  age: error: no identity matched any of the recipients
  age: report unexpected or unhelpful errors at https://filippo.io/age/report
  E: failed to decrypt 00/new_secret_multiline : Failure("age --decrypt --identity $TESTCASE_ROOT/unauthorised.key : exit code 1")
  [1]
  $ PASSAGE_IDENTITY="bobby.bob.key" passage get 00/new_secret_multiline
  replaced secret line 1
  replaced secret line 2
  replaced secret line 3\123\65

Should fail - replacing a secret which doesn't exist in a folder one is not authorised to.
  $ echo "new new new" | PASSAGE_IDENTITY=$UNAUTHORISED_USER.key passage replace 02/all_new_secret_singleline
  E: user is not a recipient of 02. Please ask someone to add you as a recipient.
  E: refusing to replace secret: violates invariant
  [1]
  $ cat<<EOF | PASSAGE_IDENTITY=$UNAUTHORISED_USER.key passage replace 02/all_new_secret_multiline
  > unauthorised replace 1
  > unauthorised replace 2
  > EOF
  E: user is not a recipient of 02. Please ask someone to add you as a recipient.
  E: refusing to replace secret: violates invariant
  [1]
  $ PASSAGE_IDENTITY=$UNAUTHORISED_USER.key passage get 02/all_new_secret_singleline
  E: no such secret: 02/all_new_secret_singleline
  [1]
  $ PASSAGE_IDENTITY=$UNAUTHORISED_USER.key passage get 02/all_new_secret_multiline
  E: no such secret: 02/all_new_secret_multiline
  [1]

Should encrypt for the users in the groups aliases used
  $ passage who 03/secret1
  @root
  host/a
  poppy.pop
  $ passage who @root
  robby.rob
  tommy.tom
  $ echo "wuuut" | PASSAGE_IDENTITY=poppy.pop.key passage replace 03/secret1
  $ PASSAGE_IDENTITY=tommy.tom.key passage get 03/secret1
  wuuut

Should succeed - correctly handle inputs without newline termination
  $ echo "secret\n\nnew comments\nmultiple comments" | passage create 01/new_secret_singleline_with_comments_2
  $ echo -n "wuuut" | passage replace 01/new_secret_singleline_with_comments_2
  $ passage cat 01/new_secret_singleline_with_comments_2
  wuuut
  
  new comments
  multiple comments
