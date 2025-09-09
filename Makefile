SRC := $(shell find src -name '*.rs') Cargo.toml

NAME := wasip122

.PHONY: examples
examples: \
	examples/rust/hello_p2.wasm \
	examples/rust/args_p2.wasm \
	examples/rust/env.wasm \
	examples/tinygo/hello_p2.wasm \
	examples/tinygo/args_p2.wasm \
	examples/tinygo/env.wasm \
	examples/go/hello_p2.wasm \
	examples/go/args_p2.wasm \
	examples/go/env.wasm
	@for wa in $^; do \
		echo "[$$wa]"; \
		wasmtime run --env=FOO=bar $$wa foo bar; \
	done

.PHONY: build
build: target/wasm32-wasip2/release/$(NAME).wasm

target/wasm32-wasip2/release/$(NAME).wasm: $(SRC)
	cargo build --target wasm32-wasip2 --release

%_p2.wasm: %.wasm target/wasm32-wasip2/release/$(NAME).wasm
	wasmtime run --dir . $(word 2, $^) -o $@ $<

examples/rust/%.wasm: examples/rust/%.rs
	rustc --target wasm32-wasip1 -o $@ $<

examples/go/%.wasm: examples/go/%.go
	env GOOS=wasip1 GOARCH=wasm go build -o $@ $<

examples/tinygo/%.wasm: examples/go/%.go
	env GOOS=wasip1 GOARCH=wasm tinygo build -o $@ $<
