# Release workflow

1. Update changelog in `CHANGES.md` (rename section `# Unreleased` to `## X.Y.Z (DATE)` and add a new `# Unreleased` section).
2. Update version number in `dune-project` and `dune build passage.opam` .
3. Commit changes to `master` with message `v X.Y.Z`.
4. Create an *annotated* tag named `X.Y.Z`.
   Ensure that `git describe --always --dirty --abbrev=7` reports exactly `X.Y.Z`.
   Then push the tag: `git push origin X.Y.Z`.

## To check

 - Ensure that the version number is set correctly. The version number
   should be in `bin/main.ml` in the release tarball, not `%%VERSION%%`.
