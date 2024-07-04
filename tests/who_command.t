  $ . ./setup_fixtures.sh

Should succeed - no path specified
  $ passage who
  bobby.bob
  dobby.dob
  robby.rob
  tommy.tom
  W: no keys found for user.with.missing.key
  user.with.missing.key

Should succeed - curr dir as path
  $ passage who .
  bobby.bob
  dobby.dob
  robby.rob
  tommy.tom
  W: no keys found for user.with.missing.key
  user.with.missing.key

Should succeed - subdir with .keys file
  $ passage who 01/00
  poppy.pop
  robby.rob

Should succeed - passing specific secret with .keys file in dir
  $ passage who 01/00/secret1
  poppy.pop
  robby.rob

Should fail with non_existent path
  $ passage who non_existent_path
  E: no such secret non_existent_path
  [1]

Should succeed - valid secret path that ends with ..
  $ passage who 01/..
  bobby.bob
  dobby.dob
  robby.rob
  tommy.tom
  W: no keys found for user.with.missing.key
  user.with.missing.key

Should succeed - valid secret path that includes .. in the middle
  $ passage who 01/../00
  bobby.bob
  dobby.dob
  robby.rob
  tommy.tom
  W: no keys found for user.with.missing.key
  user.with.missing.key

Should fail - empty .keys file
  $ echo "" > "$PASSAGE_DIR/secrets/02/.keys"
  $ passage who 02
  E: no recipients found for 02
  [1]

Should succeed - path that goes out of secrets dir is mapped to top
  $ passage who ..
  bobby.bob
  dobby.dob
  robby.rob
  tommy.tom
  W: no keys found for user.with.missing.key
  user.with.missing.key

  $ passage who ../
  bobby.bob
  dobby.dob
  robby.rob
  tommy.tom
  W: no keys found for user.with.missing.key
  user.with.missing.key

  $ passage who /..
  bobby.bob
  dobby.dob
  robby.rob
  tommy.tom
  W: no keys found for user.with.missing.key
  user.with.missing.key

  $ passage who /../
  bobby.bob
  dobby.dob
  robby.rob
  tommy.tom
  W: no keys found for user.with.missing.key
  user.with.missing.key

Should succeed - subdir recipient
  $ passage who /03
  @root
  host/a
  poppy.pop

Should succeed - with groups names
  $ passage who @root
  robby.rob
  tommy.tom

Should fail - with groups that don't exist
  $ passage who @non_existent_group
  E: group "@non_existent_group" doesn't exist
  [1]

Should succeed - expand groups and show all users with -f or --expand-groups flag
  $ passage who -f 03
  host/a
  poppy.pop
  robby.rob
  tommy.tom

  $ passage who --expand-groups 03
  host/a
  poppy.pop
  robby.rob
  tommy.tom

Should warn about non-existant group members
  $ passage who @with_issues
  poppy.pop
  W: no keys found for no.user
  no.user
  W: no keys found for this.one.doesnt.exist
  this.one.doesnt.exist

  $ passage who 05
  @with_issues
  $ passage who -f 05
  W: no keys found for no.user
  no.user
  poppy.pop
  W: no keys found for this.one.doesnt.exist
  this.one.doesnt.exist
