.DEFAULT_GOAL := build

.PHONY: build
build:
	dune build

.PHONY: fmt
fmt:
	dune fmt

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
