# wasip122

A command-line tool to convert WebAssembly modules from WASI Preview 1 (WASI 0.1) to WASI Preview 2 (WASI 0.2).

## Overview

This tool helps migrate existing WebAssembly applications that were built for WASI Preview 1 to the newer WASI Preview 2 standard. It uses the `wit-component` crate and WASI Preview 1 component adapter to perform the conversion.

## Installation

### Prerequisites

- Rust toolchain (latest stable)
- `wasm32-wasip2` target installed: `rustup target add wasm32-wasip2`
- `wasmtime` CLI (for running examples)

### Build from source

```bash
git clone <repository-url>
cd wasip122
cargo build --release
```

The binary will be available at `target/release/wasip122`.

## Usage

```bash
wasip122 -o <output.wasm> <input.wasm>
```

### Arguments

- `<input.wasm>`: Path to the WASI Preview 1 WebAssembly module
- `-o, --output <output.wasm>`: Path for the converted WASI Preview 2 module

### Example

```bash
# Convert a WASI Preview 1 module to Preview 2
wasip122 -o hello_p2.wasm hello_p1.wasm

# Run the converted module
wasmtime run hello_p2.wasm
```

## Examples

The `examples/` directory contains sample programs in Rust and Go that demonstrate the conversion process:

```bash
# Build and test examples
make examples
```

This will:
1. Compile Rust and Go programs to WASI Preview 1
2. Convert them to WASI Preview 2 using wasip122
3. Run the converted modules with wasmtime

## Development

### Building for WASI Preview 2

```bash
cargo build --target wasm32-wasip2 --release
```

### Running tests

```bash
cargo test
```

## License

See [LICENSE](LICENSE) file.
