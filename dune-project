(lang dune 3.9)

(generate_opam_files true)

(name passage)

(using menhir 2.1)

(license "MIT")

(version "0.3.2")

(source
 (github ahrefs/passage))

(authors "Ahrefs Pte Ltd <github@ahrefs.com>")

(maintainers "Ahrefs Pte Ltd <github@ahrefs.com>")

(package
 (name passage)
 (synopsis "Passage - used to store and manage access to shared secrets")
 (description "Passage - used to store and manage access to shared secrets")
 (depends
  bos
  (cmdliner
   (>= 2.0.0))
  (ocaml
   (>= 4.14))
  conf-age
  dune
  fileutils
  fpath
  (menhir
   (>= 20231231))
  (ppx_expect :with-test)
  (ocamlformat
   (and
    :with-dev-setup
    (= 0.28.1)))
  qrc
  re
  sedlex))
