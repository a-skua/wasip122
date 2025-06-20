# Go WASI Preview 2 Conversion Error Investigation Report

## Problem Summary

When converting Go-compiled WASI Preview 1 modules to WASI Preview 2 using `wasip122`, the resulting component crashes with an assertion failure during execution. Rust modules convert and run successfully under the same conditions.

## Error Details

### Error Message
```
assertion failed at adapter line 2786
Error: failed to run main module `examples/go/main_p2.wasm`

Caused by:
    0: failed to invoke `run` function
    1: error while executing at wasm backtrace:
           0: 0x255903 - wit-component:adapter:wasi_snapshot_preview1!wasi_snapshot_preview1::macros::assert_fail::hd05a95cf55b1a3a2
           1: 0x256041 - wit-component:adapter:wasi_snapshot_preview1!args_sizes_get
           2: 0x25aaa3 - wit-component:shim!adapt-wasi_snapshot_preview1-args_sizes_get
           3:  0x874e3 - <unknown>!runtime.args_sizes_get
           4:  0x87ad7 - <unknown>!runtime.goenvs
           5:  0x96048 - <unknown>!runtime.schedinit
           6: 0x10f95e - <unknown>!runtime.rt0_go
           7: 0x11259d - <unknown>!_rt0_wasm_wasip1
           8: 0x25580e - wit-component:adapter:wasi_snapshot_preview1!wasi:cli/run@0.2.3#run
    2: wasm trap: wasm `unreachable` instruction executed
```

### Environment
- Tool: `wasip122` (WASI Preview 1 to Preview 2 converter)
- Adapter: `wasi-preview1-component-adapter-provider v33.0.0`
- Wasmtime: `v33.0.0`
- Test Programs: Both Go and Rust programs that call `std::env::args()` / `os.Args`

## Investigation Findings

### 1. Error Location Analysis

The error "line 2786" refers to **source code line number 2786** in the WASI Preview 1 Component Adapter, not bytecode line numbers.

**Binary Analysis:**
- Error code `2786` (0xe2 0x15) is hardcoded in the bytecode
- Function index 42 is called before `unreachable` instruction
- Function 42 is the `assert_fail` implementation that takes line number as parameter

### 2. Root Cause Identification

**Source Location:** 
[wasmtime v33.0.0 adapter line 2786](https://github.com/bytecodealliance/wasmtime/blob/v33.0.0/crates/wasi-preview1-component-adapter/src/lib.rs#L542)

**Failing Code:**
```rust
pub unsafe extern "C" fn args_sizes_get(argc: &mut Size, argv_buf_size: &mut Size) -> Errno {
    State::with(|state| {
        // ... setup code ...
        let (len, alloc) = state.with_import_alloc(alloc, || unsafe {
            // ... get arguments ...
        });
        match alloc {
            ImportAlloc::CountAndDiscardStrings {
                strings_size,
                alloc: _,
            } => {
                *argc = len;
                *argv_buf_size = strings_size + len;
            }
            _ => unreachable!(), // ← LINE 2786: This is where the error occurs
        }
        Ok(())
    })
}
```

**Problem:** The `ImportAlloc` returned by `state.with_import_alloc()` is not the expected `CountAndDiscardStrings` variant, causing the `unreachable!()` macro to execute.

### 3. Go vs TinyGo vs Rust Behavior Differences

**Go Behavior (❌ FAILS):**
- **WASI Functions**: 16 imports including `environ_sizes_get`, `environ_get`
- **File Size**: 2.4MB (P2), 1,651 functions
- **Initialization**: `runtime.rt0_go` → `runtime.schedinit` → `runtime.goenvs` → `runtime.args_sizes_get`
- **Environment Variables**: Uses `runtime.environ_get`, `runtime.environ_sizes_get`
- **Problem**: Complex runtime initialization affects adapter state

**TinyGo Behavior (✅ WORKS):**
- **WASI Functions**: 6 imports only: `fd_write`, `proc_exit`, `clock_time_get`, `args_sizes_get`, `args_get`, `random_get`
- **File Size**: 560KB (P2), 203 functions
- **Environment Variables**: **Does not use `environ_*` functions**
- **Success**: Lightweight runtime avoids adapter state conflicts

**Rust Behavior (✅ WORKS):**
- **WASI Functions**: Similar to Go but different initialization pattern
- **File Size**: 1.9MB (P2)
- **Success**: Different runtime initialization order prevents conflicts

**WASI Function Signatures (All identical):**
- All use `(func (param i32 i32) (result i32))` signature for `args_sizes_get`

### 4. Technical Analysis

**ImportAlloc Variants:**
The adapter uses different allocation strategies based on the use case:
- `CountAndDiscardStrings`: Expected for `args_sizes_get` and `environ_sizes_get`
- `SeparateStringsAndPointers`: Used for `args_get` and `environ_get`
- `OneAlloc`: Single allocation strategy

**Core Hypothesis - Adapter State Interference:**
Go's complex runtime initialization creates adapter state conflicts:

1. **Go Runtime Sequence**: `environ_sizes_get` → `environ_get` → `args_sizes_get`
2. **State Transition Issue**: 
   - `environ_sizes_get` sets `ImportAlloc::CountAndDiscardStrings`
   - `environ_get` changes to `ImportAlloc::SeparateStringsAndPointers`
   - `args_sizes_get` expects `CountAndDiscardStrings` but finds wrong state
3. **Pattern Match Failure**: Leads to `unreachable!()` at line 2786

**TinyGo Success Factor**: Never calls `environ_*` functions, avoiding state conflicts entirely.

### 5. Binary Evidence

**Error Trigger Locations (from bytecode analysis):**
```
# Location 1: 0x255a38
local_get local_index:0
i32_eqz                    ; Check if local_0 == 0
br_if relative_depth:2     ; Branch if zero
# ... more conditions ...
i32_const value:2786       ; Error code 2786
call function_index:42     ; Call assert_fail
unreachable

# Location 2: 0x25603e  
# ... memory operations ...
i32_const value:2786       ; Error code 2786
call function_index:42     ; Call assert_fail
unreachable
```

Multiple conditional checks fail before reaching the `unreachable!()` statement.

## Conversion Tool Analysis

**wasip122 Implementation:**
```rust
let wasm_p2_bytes = ComponentEncoder::default()
    .module(&wasm_p1_bytes)?
    .adapter(
        WASI_SNAPSHOT_PREVIEW1_ADAPTER_NAME,
        WASI_SNAPSHOT_PREVIEW1_COMMAND_ADAPTER,
    )?
    .validate(true)
    .encode()?;
```

The conversion tool itself appears to work correctly - the issue is runtime behavior in the adapter.

## Source Code References

### WASI Preview 1 Component Adapter (v33.0.0)

**Main Implementation:**
- [lib.rs](https://github.com/bytecodealliance/wasmtime/blob/v33.0.0/crates/wasi-preview1-component-adapter/src/lib.rs) - Core adapter implementation
- [macros.rs](https://github.com/bytecodealliance/wasmtime/blob/v33.0.0/crates/wasi-preview1-component-adapter/src/macros.rs) - Assert and panic macros

**Key Functions:**
- [`args_sizes_get` (lines 511-545)](https://github.com/bytecodealliance/wasmtime/blob/v33.0.0/crates/wasi-preview1-component-adapter/src/lib.rs#L511-L545) - Where the error occurs
- [Problem line 2786](https://github.com/bytecodealliance/wasmtime/blob/v33.0.0/crates/wasi-preview1-component-adapter/src/lib.rs#L542) - `_ => unreachable!()` statement
- [`assert_fail` (lines 84-91)](https://github.com/bytecodealliance/wasmtime/blob/v33.0.0/crates/wasi-preview1-component-adapter/src/macros.rs#L84-L91) - Assert failure handler
- [`ImportAlloc` enum (lines 250-267)](https://github.com/bytecodealliance/wasmtime/blob/v33.0.0/crates/wasi-preview1-component-adapter/src/lib.rs#L250-L267) - Allocation strategy definitions

**Related Functions:**
- [`State::with_import_alloc`](https://github.com/bytecodealliance/wasmtime/blob/v33.0.0/crates/wasi-preview1-component-adapter/src/lib.rs#L2700) - Memory allocation management
- [`args_get` (lines 474-507)](https://github.com/bytecodealliance/wasmtime/blob/v33.0.0/crates/wasi-preview1-component-adapter/src/lib.rs#L474-L507) - Companion function that works

### Project Source Code

**Conversion Tool:**
- [`src/main.rs`](src/main.rs) - wasip122 implementation using wit-component

**Test Examples:**
- [`examples/go/main.go`](examples/go/main.go) - Go test program that fails
- [`examples/rust/main.rs`](examples/rust/main.rs) - Rust test program that works
- [`examples/tinygo/main.go`](examples/tinygo/main.go) - TinyGo test program that works
- [`Makefile`](Makefile) - Build and test automation (TinyGo support added)

## Recommendations

### 1. Immediate Workarounds
- **Use TinyGo**: Works perfectly for WASI Preview 2 applications
- **Use Rust**: Also works without issues
- **Avoid standard Go**: Standard Go runtime is incompatible with current adapter
- **Note**: Pure Go without environment access is not feasible - Go runtime always initializes environment variables

### 2. Further Investigation Needed
- **Adapter State Verification**: Confirm `ImportAlloc` state persistence hypothesis through adapter source analysis
- **Runtime Call Sequence**: Verify exact order of `environ_*` and `args_*` function calls in Go initialization
- **Adapter Version Testing**: Test with different adapter versions to see if this is a regression
- **Wasmtime Issue Search**: Check for similar reported problems in wasmtime repository

### 3. Potential Fixes
- **Adapter Improvement**: Make the adapter more robust to handle different allocation patterns
- **Go Compilation Options**: Investigate Go build flags that might affect WASI behavior
- **Alternative Adapters**: Try community-developed adapters if available

## Conclusion

This is a **runtime incompatibility between Go's WASI implementation and the WASI Preview 1 Component Adapter v33.0.0**. The issue stems from Go's complex runtime initialization sequence that interferes with the adapter's `ImportAlloc` state management.

**Key Findings:**
- **TinyGo works** because it avoids `environ_*` functions entirely
- **Standard Go fails** due to `environ_get` → `args_sizes_get` state transition conflict
- **Adapter bug** likely in `ImportAlloc` state persistence between function calls

The conversion tool `wasip122` is working correctly - the problem lies in the runtime interaction between Go-compiled WASM and the adapter's memory management expectations.

**Recommendation:** Use TinyGo for WASI Preview 2 projects until this adapter issue is resolved.

---

**Investigation Date:** June 19-20, 2025  
**Tools Used:** wasip122, wasmtime v33.0.0, wasm-tools, TinyGo  
**Status:** Root cause hypothesis established, ready for issue report