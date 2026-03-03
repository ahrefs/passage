  $ . ./setup_fixtures.sh

Should succeed - shows overlap with bobby.bob (default identity)
  $ passage overlap
  Your secrets: 5 total
  
  Recipients with most overlap:
    dobby.dob                      4/5 (80.0%)
    robby.rob                      4/5 (80.0%)
    tommy.tom                      4/5 (80.0%)
    host/a                         1/5 (20.0%)
    poppy.pop                      1/5 (20.0%)

Should succeed - shows overlap with a different identity (robby.rob)
  $ PASSAGE_IDENTITY="robby.rob.key" passage overlap
  Your secrets: 7 total
  
  Recipients with most overlap:
    tommy.tom                      5/7 (71.4%)
    bobby.bob                      4/7 (57.1%)
    dobby.dob                      4/7 (57.1%)
    poppy.pop                      4/7 (57.1%)
    host/a                         2/7 (28.6%)

Should succeed - custom limit restricts results
  $ passage overlap -n 2
  Your secrets: 5 total
  
  Recipients with most overlap:
    dobby.dob                      4/5 (80.0%)
    robby.rob                      4/5 (80.0%)
