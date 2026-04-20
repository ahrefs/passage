#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

echo "==> Cleaning build artifacts and stale coverage data..."
dune clean
find . -name '*.coverage' -delete 2> /dev/null || true
mkdir -p _coverage

echo "==> Running test suite..."
BISECT_FILE=$(pwd)/_coverage/ dune runtest --instrument-with bisect_ppx --force -j 1 "$@" || true

echo "==> Generating coverage report..."
bisect-ppx-report html --coverage-path . --tree
echo "Report generated in _coverage/index.html"
bisect-ppx-report summary --per-file --coverage-path .
