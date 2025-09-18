  $ . ./setup_fixtures.sh

Should substitute single secret in template
  $ passage subst "The secret is: {{{00/secret1}}}"
  The secret is: (00/secret1) secret: single line

Should substitute multiple secrets in template
  $ passage subst "Secret1: {{{00/secret1}}} and Secret2: {{{01/secret1}}}"
  Secret1: (00/secret1) secret: single line and Secret2: (01/secret1) secret: single line

Should substitute singleline secret without trailing newline
  $ passage subst "Singleline: {{{00/.secret_starting_with_dot}}}"
  Singleline: (00/.secret_starting_with_dot) secret: single line

Should handle template with no substitutions
  $ passage subst "This is just plain text"
  This is just plain text

Should fail for non-existent secret
  $ passage subst "Missing: {{{non/existent}}}"
  E: could not decrypt secret non/existent
  E: failed to substitute : Unix_error open($TESTCASE_ROOT/fixtures/secrets/non/existent.age) No such file or directory
  [1]

Should handle complex template with mixed content
  $ passage subst "Config: host={{{00/.secret_starting_with_dot}}}, pass={{{01/secret1}}}, done."
  Config: host=(00/.secret_starting_with_dot) secret: single line, pass=(01/secret1) secret: single line, done.

Should handle empty template
  $ passage subst ""


Should handle template with only whitespace around substitutions
  $ passage subst "  {{{00/.secret_starting_with_dot}}}  "
    (00/.secret_starting_with_dot) secret: single line  
