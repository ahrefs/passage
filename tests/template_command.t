  $ . ./setup_fixtures.sh

Set default target file
  $ TARGET="target.txt"

Should succeed - template with only 1 secret
 Single line secret without comments
  $ setup_singleline_secret_without_comments single_secret
  $ passage template $PASSAGE_DIR/templates/single_secret.txt $TARGET
  $ cat $TARGET
  this is a template with a single secret
  {{{ this_should_not_be_substituted }}}
  TEXT BEFORE SECRET(single_secret) secret: single lineTEXT AFTER SECRET

 Single line secret with comments - comments should not be substituted
  $ passage rm -f single_secret
  $ setup_singleline_secret_with_comments single_secret
  $ passage template $PASSAGE_DIR/templates/single_secret.txt $TARGET
  $ cat $TARGET
  this is a template with a single secret
  {{{ this_should_not_be_substituted }}}
  TEXT BEFORE SECRET(single_secret) secret: single lineTEXT AFTER SECRET

 Multiline secret without comments
  $ passage rm -f single_secret
  $ setup_multiline_secret_without_comments single_secret
  $ passage template $PASSAGE_DIR/templates/single_secret.txt $TARGET
  $ cat $TARGET
  this is a template with a single secret
  {{{ this_should_not_be_substituted }}}
  TEXT BEFORE SECRET(single_secret) secret: line 1
  (single_secret) secret: line 2TEXT AFTER SECRET

 Multiline secret with comments - comments should not be substituted
  $ passage rm -f single_secret
  $ setup_multiline_secret_with_comments single_secret
  $ passage template $PASSAGE_DIR/templates/single_secret.txt $TARGET
  $ cat $TARGET
  this is a template with a single secret
  {{{ this_should_not_be_substituted }}}
  TEXT BEFORE SECRET(single_secret) secret: line 1
  (single_secret) secret: line 2TEXT AFTER SECRET

Should succeed - template with multiple secrets
  $ setup_singleline_secret_with_comments multiple_secrets_1
  $ setup_multiline_secret_with_comments multiple_secrets_2
  $ passage template $PASSAGE_DIR/templates/multiple_secrets.txt $TARGET
  $ cat $TARGET
  this is a template with multiple_secrets
  {{{ this_should_not_be_substituted }}}
  first secret: (multiple_secrets_1) secret: single line
  
  second secret:
  (multiple_secrets_2) secret: line 1
  (multiple_secrets_2) secret: line 2
  
  end of file

Should fail - invalid template file
  $ passage template non_existent_template $TARGET
  E: failed to substitute file : Sys_error("non_existent_template: No such file or directory")
  [1]

Should fail - no identity file
  $ PASSAGE_IDENTITY=dfsd.key passage template $PASSAGE_DIR/templates/multiple_secrets.txt
  E: failed to substitute file : Failure("unable to decrypt secret: no identity file found (dfsd.key). Is passage setup? Try 'passage init'.")
  [1]

Should fail - no identity file
  $ PASSAGE_IDENTITY=poppy.pop.key passage template $PASSAGE_DIR/templates/multiple_secrets.txt
  E: failed to substitute file : Failure("unable to decrypt secret: age --decrypt --identity '$TESTCASE_ROOT/poppy.pop.key' : exit code 1")
  [1]

Should fail - unable to decrypt a secret
  $ passage template $PASSAGE_DIR/templates/inaccessible_secret.txt $TARGET 2>&1 | grep -m 1 "^E: could not"
  E: could not decrypt secret 01/00/secret3

Should succeed - path is normalized
  $ echo "secret" | passage create 00/secret
  $ passage template $PASSAGE_DIR/templates/crazy_secret.txt $TARGET
  $ cat $TARGET
  okay secret: secret

TEMPLATE
Set default target file
  $ TARGET="target.txt"

Should succeed - template with secrets owned by the @root group should work as intended for all recipients
  $ PASSAGE_IDENTITY=poppy.pop.key passage template $PASSAGE_DIR/templates/single_secret_for_groups.txt $TARGET
  $ cat $TARGET
  this is a template with a single secret
  {{{ this_should_not_be_substituted }}}
  TEXT BEFORE SECRET-(03/secret1) secret: single line-TEXT AFTER SECRET
  $ PASSAGE_IDENTITY=robby.rob.key passage template $PASSAGE_DIR/templates/single_secret_for_groups.txt $TARGET
  $ cat $TARGET
  this is a template with a single secret
  {{{ this_should_not_be_substituted }}}
  TEXT BEFORE SECRET-(03/secret1) secret: single line-TEXT AFTER SECRET
  $ PASSAGE_IDENTITY=poppy.pop.key passage template $PASSAGE_DIR/templates/single_secret_for_groups.txt $TARGET
  $ cat $TARGET
  this is a template with a single secret
  {{{ this_should_not_be_substituted }}}
  TEXT BEFORE SECRET-(03/secret1) secret: single line-TEXT AFTER SECRET
