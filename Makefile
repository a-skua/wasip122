SRC := $(shell find src -name '*.rs') Cargo.toml

NAME := wasip122
MODE := release

.PHONY: examples
examples: examples/go/main_p2.wasm examples/rust/main_p2.wasm examples/tinygo/main_p2.wasm
	@for wa in $^; do \
		echo "[$$wa]"; \
		wasmtime run $$wa foo bar; \
	done

target/wasm32-wasip2/release/$(NAME).wasm: $(SRC)
	cargo build --target wasm32-wasip2 --release

target/wasm32-wasip2/debug/$(NAME).wasm: $(SRC)
	cargo build --target wasm32-wasip2

%_p2.wasm: %.wasm target/wasm32-wasip2/$(MODE)/$(NAME).wasm
	wasmtime run --dir . $(word 2, $^) -o $@ $<

examples/rust/%.wasm: examples/rust/%.rs
	rustc --target wasm32-wasip1 -o $@ $<

examples/go/%.wasm: examples/go/%.go
	env GOOS=wasip1 GOARCH=wasm go build -o $@ $<

examples/tinygo/%.wasm: examples/tinygo/%.go
	tinygo build -target=wasip1 -o $@ $<
