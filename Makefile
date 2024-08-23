.DEFAULT_GOAL := build
SHELL := /bin/bash

.PHONY: build
build:
	dune build

.PHONY: fmt
fmt:
	dune build @fmt

.PHONY: test
test:
	dune runtest

.PHONY: promote
promote:
	dune build @runtest --auto-promote

.PHONY: watch
watch:
	dune build -w

.PHONY: clean
clean:
	dune clean

.PHONY: top
top:
	dune utop .

.PHONY: install_bash_completions
install_bash_completions:
	. ./install-bash-completions.sh
