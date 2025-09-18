SRC := $(shell find src -name '*.rs') Cargo.toml

NAME := wasip122
VERSION := $(shell yq '.package.version' -p toml < Cargo.toml)

.PHONY: examples
examples: \
	examples/rust/hello_p2.wasm \
	examples/rust/args_p2.wasm \
	examples/rust/env_p2.wasm \
	examples/tinygo/hello_p2.wasm \
	examples/tinygo/args_p2.wasm \
	examples/tinygo/env_p2.wasm \
	examples/go/hello_p2_fix.wasm \
	examples/go/args_p2_fix.wasm \
	examples/go/env_p2_fix.wasm \
	examples/go/color_p2_fix.wasm
	@for wa in $^; do \
		echo "[$$wa]"; \
		wasmtime run --env=FOO=bar $$wa foo bar; \
	done

.PHONY: build
build: target/wasm32-wasip2/release/$(NAME).wasm

.PHONY: push
push: target/wasm32-wasip2/release/$(NAME).wasm
	wkg oci push ghcr.io/a-skua/$(NAME):$(VERSION) $<

.PHONY: wat
wat: \
	examples/rust/hello.wat \
	examples/rust/args.wat \
	examples/rust/env.wat \
	examples/tinygo/hello.wat \
	examples/tinygo/args.wat \
	examples/tinygo/env.wat \
	examples/go/hello.wat \
	examples/go/args.wat \
	examples/go/env.wat

target/wasm32-wasip2/release/$(NAME).wasm: $(SRC)
	cargo build --target wasm32-wasip2 --release

%_fix.wasm: %.wasm
	./bin/fix-mem.rb $< $@

%_p2.wasm: %.wasm target/wasm32-wasip2/release/$(NAME).wasm
	wasmtime run --dir . $(word 2, $^) -o $@ $<

examples/rust/%.wasm: examples/rust/%.rs
	rustc --target wasm32-wasip1 -o $@ $<

examples/go/%.wasm: examples/go/%.go
	env GOOS=wasip1 GOARCH=wasm go build -o $@ $<

examples/tinygo/%.wasm: examples/tinygo/%.go
	env GOOS=wasip1 GOARCH=wasm tinygo build -o $@ $<

%.wat: %.wasm
	wasm-tools print $< -o $@

.PHONY: clean
clean:
	cargo clean
	rm -f examples/**/*.wasm examples/**/*.wat
