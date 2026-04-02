# Release workflow

1. Update changelog in `CHANGES.md` (rename section `## Unreleased` to `## X.Y.Z (YYYY-MM-DD)` and add a new `## Unreleased` section).
2. Update version number in `dune-project` and `dune build passage.opam` .
3. Commit changes to `master` with message `v X.Y.Z`.
4. Create an *annotated* tag named `X.Y.Z` using `dune-release tag X.Y.Z`:
   Ensure that `git describe --always --dirty --abbrev=7` reports exactly `X.Y.Z`.
5. Create the distribution archive: `dune-release distrib`. Double check that
   the version number is correct in `bin/main.ml` in the created release tarball.
   ```
   $ tar xvf _build/passage-X.Y.Z.tbz passage-X.Y.Z/bin/main.ml --to-stdout | grep version
   passage-X.Y.Z/bin/main.ml
    let info = Cmd.info "passage" ~version:"X.Y.Z" ~envs ~doc ~man in
   ```
6. Create the GitHub release: `dune-release publish`. Verify that the
   release's description contains the appropriate portion of the changelog.
7. Create and submit the opam package: `dune-release opam pkg && dune-release opam submit`

The above steps 4. to 7. can be shortened to `dune-release bistro`.

# Testing the release

Create a new switch configured to use your local opam-repository fork,
checked out to the branch containing the release to check:

```
$ opam repo add my-repo file:///home/me/dev/opam-repository
$ opam switch create my-switch ocaml-base-compiler.5.2.0
$ opam repo remove default --switch=my-switch               # remove the default switch
$ opam repo add my-repo
$ opam update
$ opam list # should only see my-repo
$ opam show passage                                         # verify that the version is X.Y.Z
$ opam install passage
$ passage --version                                         # should output X.Y.Z
```
