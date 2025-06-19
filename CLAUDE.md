# CLAUDE.md - Development Context for wasip122

## Project Overview

**wasip122** is a command-line tool written in Rust that converts WebAssembly modules from WASI Preview 1 (WASI 0.1) to WASI Preview 2 (WASI 0.2). This tool is essential for migrating existing WebAssembly applications to the newer WASI standard.

## Core Functionality

The main conversion logic is in `src/main.rs:20-27`:
- Uses `wit-component::ComponentEncoder` to wrap WASI Preview 1 modules
- Applies the WASI Preview 1 component adapter from `wasi-preview1-component-adapter-provider`
- Validates and encodes the result as a WASI Preview 2 component

## Project Structure

```
wasip122/
├── src/main.rs           # Main CLI application logic
├── examples/             # Sample programs for testing
│   ├── go/main.go       # Go WASI Preview 1 example
│   └── rust/main.rs     # Rust WASI Preview 1 example
├── Makefile             # Build automation and examples
├── Cargo.toml           # Rust dependencies and metadata
└── README.md            # User documentation
```

## Key Dependencies

- `clap`: Command-line argument parsing with derive macros
- `wit-component`: Core WebAssembly component manipulation
- `wasi-preview1-component-adapter-provider`: WASI Preview 1 adapter

## Build Targets

- **Host binary**: Built with default Rust target for CLI usage
- **WASI Preview 2**: Built with `wasm32-wasip2` target (the tool itself can run in WASI)

## Development Workflow

1. **Building**: `cargo build --release` for the CLI tool
2. **Testing**: `make examples` builds sample programs and tests conversion
3. **Target installation**: Requires `wasm32-wasip2` target for WASI Preview 2 builds

## Example Usage Pattern

The tool follows a simple input/output pattern:
```bash
wasip122 -o output_p2.wasm input_p1.wasm
```

Input: WASI Preview 1 WebAssembly module (.wasm)
Output: WASI Preview 2 component (.wasm)

## Code Style and Conventions

- Standard Rust formatting and idioms
- Error handling with `Result<(), Box<dyn std::error::Error>>`
- CLI argument parsing using clap derive macros
- File I/O operations are straightforward read/write

## Documentation Rules

**CRITICAL: These rules must be followed for all documentation work:**

1. **All documentation must be written in English** - This is an OSS project with international contributors
2. **Documentation must be kept up-to-date** - Always update relevant documentation as part of any development work, not as a separate task

## When Making Changes

- Update examples in `examples/` if CLI interface changes
- Test with both Rust and Go sample programs via `make examples`
- Ensure proper error handling for file operations and WebAssembly encoding
- **Always update README.md and other documentation** if user-facing functionality changes
- **All documentation updates must be in English**

## Testing Strategy

- Use `make examples` to verify conversions work correctly
- Test with various WASI Preview 1 modules (Go, Rust examples provided)
- Verify output modules run correctly with `wasmtime`

## Common Development Tasks

- Adding new CLI options: Update `Wasm` struct in `src/main.rs:7-13`
- Modifying conversion logic: Update encoder configuration in `src/main.rs:20-27`
- Adding new examples: Create in `examples/` and update Makefile targets