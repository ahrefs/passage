  $ . ./setup_fixtures.sh

Should return nothing for a secret without comments - singleline
  $ setup_singleline_secret_without_comments single_line_no_comments
  $ passage get-comment single_line_no_comments

Should return nothing for a secret without comments - multiline
  $ setup_multiline_secret_without_comments multiline_no_comments
  $ passage get-comment multiline_no_comments

Should return comments for a singleline secret with comments
  $ setup_singleline_secret_with_comments single_line_with_comments
  $ passage get-comment single_line_with_comments
  (single_line_with_comments) comment: line 1
  (single_line_with_comments) comment: line 2

Should return comments for a multiline secret with comments
  $ setup_multiline_secret_with_comments multiline_with_comments
  $ passage get-comment multiline_with_comments
  (multiline_with_comments) comment: line 1
  (multiline_with_comments) comment: line 2

Should fail for a non-existent secret
  $ passage get-comment non_existent_secret
  E: no such secret: non_existent_secret
  [1]

