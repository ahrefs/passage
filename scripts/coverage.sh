#!/usr/bin/env bash
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

echo "==> Cleaning build artifacts and stale coverage data..."
dune clean

mkdir -p _coverage
export BISECT_FILE
BISECT_FILE=$(pwd)/_coverage/
find "$BISECT_FILE" -name '*.coverage' -delete 2> /dev/null || true

echo "==> Running test suite..."
dune runtest --instrument-with bisect_ppx --force "$@" || true

echo "==> Generating coverage report..."
bisect-ppx-report summary --coverage-path "$BISECT_FILE" --per-file
bisect-ppx-report html --coverage-path "$BISECT_FILE" --tree
echo "Report generated in file://$(pwd)/_coverage/index.html"
