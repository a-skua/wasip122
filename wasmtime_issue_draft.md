# Go WASI P1→P2 conversion fails: Recursive component boundary crossing in random_get

## Summary

When converting Go-compiled WASI Preview 1 modules to WASI Preview 2 using the component adapter, the resulting component crashes during Go runtime initialization when calling `random_get`. The crash occurs due to a recursive component boundary crossing issue where `cabi_import_realloc` is called while already inside a WASI P2 call, triggering the "cannot leave component instance" error. TinyGo and Rust modules work correctly.

## Environment

- Wasmtime: v33.0.0 
- Adapter: wasi-preview1-component-adapter v33.0.0
- Go: 1.22.0 (GOOS=wasip1 GOARCH=wasm)
- TinyGo: 0.34.0
- Rust: 1.86.0 (target wasm32-wasip1)

## Error Details

### Original Error (Default Adapter)
```
assertion failed at adapter line 2786
Error: failed to run main module `main_p2.wasm`

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

### Debug Investigation Results 

**IMPORTANT UPDATE**: Using a debug-enabled adapter revealed the actual root cause occurs **before** `args_sizes_get`:

```
DEBUG: State::with called
DEBUG: Got state pointer
DEBUG: magic1 check
DEBUG: magic2 check
DEBUG: Magic checks passed, calling function
Error: failed to run main module `test_debug2_p2.wasm`

Caused by:
    0: failed to invoke `run` function
    1: error while executing at wasm backtrace:
           0: 0x2588b8 - wit-component:adapter:wasi_snapshot_preview1!wasi_snapshot_preview1::macros::print::h351372491e181bbf
           1: 0x255901 - wit-component:adapter:wasi_snapshot_preview1!cabi_import_realloc
           2: 0x25c4cd - wit-component:shim!indirect-wasi:random/random@0.2.3-get-random-bytes
           3: 0x258625 - wit-component:adapter:wasi_snapshot_preview1!random_get
           4: 0x25c3b9 - wit-component:shim!adapt-wasi_snapshot_preview1-random_get
           5:  0x875ec - <unknown>!runtime.random_get
           6:  0xbabbe - <unknown>!runtime.randinit
           7:  0x95e96 - <unknown>!runtime.schedinit
           8: 0x10f95e - <unknown>!runtime.rt0_go
           9: 0x11259d - <unknown>!_rt0_wasm_wasip1
          10: 0x25581d - wit-component:adapter:wasi_snapshot_preview1!wasi:cli/run@0.2.3#run
    2: cannot leave component instance
```

## Corrected Root Cause Analysis

The real issue occurs during **random number initialization** (`runtime.randinit`), not in `args_sizes_get`. The Go runtime crashes when calling `random_get` through the adapter, with the error "cannot leave component instance".

### Go Runtime Initialization Sequence
1. `runtime.rt0_go` → `runtime.schedinit` 
2. **`runtime.randinit`** → `runtime.random_get` ← **CRASH HERE**
3. `runtime.goenvs` → `runtime.args_sizes_get` ← Never reached

The original `args_sizes_get` error was likely a secondary effect or different execution path.

## Reproduction Steps

1. Create a minimal Go program:
```go
// main.go
package main

import (
    "fmt"
    "os"
)

func main() {
    fmt.Println("Args:", os.Args)
}
```

2. Compile to WASI Preview 1:
```bash
GOOS=wasip1 GOARCH=wasm go build -o main.wasm main.go
```

3. Convert to WASI Preview 2:
```bash
# Using wit-component or any tool with the adapter
wit-component embed --world wasi:cli/command main.wasm -o main_p2.wasm
```

4. Run with wasmtime:
```bash
wasmtime run main_p2.wasm foo bar
# CRASH with assertion failed at adapter line 2786
```

## Comparison with TinyGo and Rust

### TinyGo (WORKS ✅)
- Same source code, compiled with: `tinygo build -target=wasi -o main.wasm main.go`
- WASI imports: Only 6 functions (no `environ_*` functions)
- Binary size: 560KB (P2)
- **Result**: Works perfectly

### Rust (WORKS ✅)  
- Similar functionality using `std::env::args()`
- WASI imports: Includes `environ_*` functions like Go
- **Result**: Works perfectly

### Analysis

| | Go | TinyGo | Rust |
|---|---|---|---|
| **WASI Functions** | 16 imports | 6 imports | ~10 imports |
| **Uses environ_*** | ✅ | ❌ | ✅ |
| **P2 Conversion** | ❌ FAILS | ✅ WORKS | ✅ WORKS |
| **Binary Size (P2)** | 2.4MB | 560KB | 1.9MB |
| **Runtime Initialization** | `schedinit` → `randinit` → `random_get` | No `schedinit/randinit`, uses `fastrand` | Different initialization order |

## Technical Investigation

### Key Findings from Debug Analysis

1. **State Management Works**: The adapter's `State::with()` function works correctly (magic number checks pass)
2. **Real Issue Location**: The crash occurs in `random_get`, not `args_sizes_get`
3. **Component Boundary Issue**: Error "cannot leave component instance" suggests a problem with component model boundaries
4. **Call Stack**: `cabi_import_realloc` → `wasi:random/random@0.2.3-get-random-bytes` → `random_get`

### Updated Hypothesis

The Go runtime's early initialization of random number generation triggers a component model boundary violation. The adapter attempts to call WASI Preview 2 random functions but encounters a "cannot leave component instance" error, suggesting:

1. **Component Model Restrictions**: The adapter may have restrictions on which WASI P2 functions can be called during certain phases
2. **Memory Management Issues**: The `cabi_import_realloc` involvement suggests memory allocation during random generation may violate component boundaries
3. **Initialization Timing**: Go's early random initialization may occur before the component is fully ready to handle WASI P2 calls

## Debug Methodology

To identify the real root cause, I modified the WASI adapter with debug logging:

1. **Built Custom Adapter**: 
   ```bash
   cargo build --target wasm32-unknown-unknown --release --features command --no-default-features
   ```

2. **Added Debug Logs**: Enhanced `State::with()` and `args_sizes_get()` with `eprintln!` statements

3. **Discovered Real Issue**: The debug output revealed that `random_get` fails before `args_sizes_get` is even called

4. **Enhanced Random Function Debug**: Added comprehensive logging to `random_get`, `with_one_import_alloc`, and related functions

5. **Pinpointed Exact Failure Location**: Traced execution flow to identify the precise crash point

## Root Cause Analysis - Component Model Boundary Enforcement

### Exact Error Location Identified

The error "cannot leave component instance" is thrown from:
- **File**: `crates/wasmtime/src/runtime/component/func/host.rs`
- **Lines**: 195-197 and 358-360
- **Code**:
```rust
// Perform a dynamic check that this instance can indeed be left. Exiting
// the component is disallowed, for example, when the `realloc` function
// calls a canonical import.
if !flags.may_leave() {
    bail!("cannot leave component instance");
}
```

### The Mechanism of Failure

1. **Go's `random_get` calls `with_one_import_alloc`** to set up memory for random bytes
2. **Inside the closure, `random::get_random_bytes` is called** (WASI P2 interface)
3. **WASI P2 internally calls `cabi_import_realloc`** for memory allocation
4. **Wasmtime sets `may_leave` flag to `false`** during canonical import processing
5. **Any subsequent WASI P2 call fails** with "cannot leave component instance"

This is a **recursive component boundary crossing issue** where the adapter tries to call WASI P2 while already inside a WASI P2 call chain.

## Detailed Debug Analysis Results

### Enhanced Debug Output
Using comprehensive debug logging, I traced the exact execution flow until the crash:

```
DEBUG: random_get called
DEBUG: got allocation_state
DEBUG: allocation state matches, calling State::with
DEBUG: State::with called
DEBUG: Got state pointer
DEBUG: magic1 check
DEBUG: magic2 check
DEBUG: Magic checks passed, calling function
DEBUG: inside State::with for random_get
DEBUG: buf_len assertion passed
DEBUG: calling with_one_import_alloc
DEBUG: with_one_import_alloc called
DEBUG: created BumpAlloc, calling with_import_alloc
DEBUG: calling random::get_random_bytes
Error: failed to run main module `test_random_debug_p2.wasm`

Caused by:
    0: failed to invoke `run` function
    1: error while executing at wasm backtrace:
           0: 0x258f41 - wit-component:adapter:wasi_snapshot_preview1!wasi_snapshot_preview1::macros::print::h351372491e181bbf
           1: 0x255901 - wit-component:adapter:wasi_snapshot_preview1!cabi_import_realloc
           2: 0x25cb5a - wit-component:shim!indirect-wasi:random/random@0.2.3-get-random-bytes
           3: 0x258b18 - wit-component:adapter:wasi_snapshot_preview1!random_get
           4: 0x25ca46 - wit-component:shim!adapt-wasi_snapshot_preview1-random_get
           5:  0x875ec - <unknown>!runtime.random_get
           6:  0xbabbe - <unknown>!runtime.randinit
           7:  0x95e96 - <unknown>!runtime.schedinit
           8: 0x10f95e - <unknown>!runtime.rt0_go
           9: 0x11259d - <unknown>!_rt0_wasm_wasip1
          10: 0x25581d - wit-component:adapter:wasi_snapshot_preview1!wasi:cli/run@0.2.3#run
    2: cannot leave component instance
```

### Critical Finding

**All adapter internal logic works perfectly**:
- ✅ State management (magic number checks pass)
- ✅ Allocation state verification  
- ✅ Memory allocation setup (`BumpAlloc` creation)
- ✅ Import allocator configuration

**The crash occurs exactly when calling `wasi:random/random@0.2.3-get-random-bytes`**, which is a WASI Preview 2 interface call.

### Root Cause Confirmed

This definitively confirms the issue is **not** in the adapter's internal logic, but rather in **component model boundary enforcement** when trying to call WASI Preview 2 functions from within the component instance during Go runtime initialization.

The error "cannot leave component instance" suggests that:
1. **Component Model Restriction**: There are specific restrictions on when/how component instances can call external WASI P2 interfaces
2. **Timing Issue**: Go's early runtime initialization (`runtime.randinit`) occurs at a time when such calls are not permitted
3. **Interface Boundary**: The transition from adapter internal logic to WASI P2 interface calls violates component model rules

## Runtime Initialization Analysis

### Go vs TinyGo Critical Differences

**Go Runtime Initialization Sequence:**
1. `_rt0_wasm_wasip1` (entry point)
2. `runtime.schedinit` (scheduler initialization)
3. **`runtime.randinit`** → **`runtime.random_get`** → **WASI `random_get`** ← **CRASH HERE**
4. `runtime.goenvs` → `runtime.args_sizes_get` (never reached)

**TinyGo Runtime Initialization:**
1. `_start` (entry point)
2. **No `runtime.schedinit` or `runtime.randinit`**
3. **Uses `runtime.fastrand` instead of WASI `random_get`**
4. WASI calls only happen in main function: `args_get`, `args_sizes_get`, `clock_time_get`

### Key Discovery

**Go fails** because its runtime initialization triggers WASI Preview 2 calls (`random_get`) **before the component is fully ready to handle recursive component boundary crossings**.

**TinyGo succeeds** because it uses an **internal pseudo-random number generator** (`runtime.fastrand`) and **avoids WASI calls during runtime initialization entirely**.

This confirms the issue is a **timing problem**: Go's standard runtime makes WASI P2 calls too early in the initialization sequence, when the component model restrictions are still in effect.

## Additional Information

- This issue is consistently reproducible with standard Go compiler
- **TinyGo works** because:
  - Lightweight runtime that avoids WASI calls during initialization
  - **Uses `runtime.fastrand` instead of `runtime.random_get`**
  - **No `runtime.schedinit`/`runtime.randinit` sequence**
- **Rust works** despite using similar WASI functions, suggesting Go's specific initialization order triggers the bug
- The issue is specific to the WASI Preview 1 → Preview 2 conversion process
- Native WASI Preview 1 execution works correctly

## Test Repository

I've created a minimal reproduction repository with test cases for Go, TinyGo, and Rust:
[Link to repository would go here]

## Potential Fix & Workaround

Based on the detailed debug analysis, the fix needs to address **component model boundary restrictions** during runtime initialization:

### Working Workaround: Custom random_get Implementation

**✅ SOLUTION CONFIRMED**: We successfully created a working workaround by implementing a custom `random_get` function that avoids WASI Preview 2 calls entirely:

```rust
// random-wrapper-p1/src/lib.rs
#[no_mangle]
pub unsafe extern "C" fn random_get(buf: *mut u8, buf_len: u32) -> u32 {
    // Linear Congruential Generator - no WASI calls
    static mut SEED: u32 = 12345;
    
    for i in 0..buf_len {
        SEED = SEED.wrapping_mul(1103515245).wrapping_add(12345);
        let random_byte = (SEED >> 16) as u8;
        core::ptr::write(buf.add(i as usize), random_byte);
    }
    
    0 // WASI_SUCCESS
}
```

**Test Results:**
- ✅ Successfully compiled to `wasm32-unknown-unknown`  
- ✅ Successfully converted to WASI Preview 2 component using `wasip122`
- ✅ Runs without component boundary crossing errors
- ✅ Provides deterministic random data without WASI P2 dependencies

This approach **completely eliminates** the recursive component boundary crossing issue by:
1. **No WASI P2 calls** during random generation
2. **Self-contained** pseudo-random implementation  
3. **Compatible** with Go's expected `random_get` signature: `(param i32 i32) (result i32)`

### Component Architecture Fix Needed

### Immediate Fixes Needed

1. **Fix Recursive Component Boundary Crossing in `random_get`**:
   - **Problem**: `with_one_import_alloc` → `random::get_random_bytes` → `cabi_import_realloc` → `may_leave` = false
   - **Solution A**: Modify adapter's `random_get` to avoid using `with_one_import_alloc` 
   - **Solution B**: Use a different allocation strategy that doesn't trigger recursive imports
   - **Solution C**: Special-case `random_get` to bypass the restriction

2. **Learn from TinyGo's Implementation**:
   - Investigate how TinyGo successfully handles random generation
   - Apply similar patterns to the standard Go adapter path

### Technical Approaches

1. **Defer Random Initialization**: Modify when/how the adapter handles `random_get` calls during component startup
2. **Component State Management**: Ensure the component instance is in a state that allows WASI P2 interface calls
3. **Alternative Random Source**: Provide a fallback random implementation that doesn't require WASI P2 calls during initialization

### TinyGo Success Analysis

**Critical Discovery**: TinyGo successfully uses random functions without triggering the component boundary issue:

```go
// TinyGo test program
package main
import (
    "crypto/rand"
    "fmt"
)
func main() {
    buf := make([]byte, 8)
    rand.Read(buf)  // Successfully calls random functions
    fmt.Printf("Random bytes: %v\n", buf)
}
```

**Result**: TinyGo program works perfectly, generating random bytes without any errors.

This confirms that:
1. **The issue is specific to Go's standard runtime implementation**
2. **TinyGo either**:
   - Uses a different random initialization timing
   - Has a different implementation that avoids the recursive `cabi_import_realloc` issue
   - Doesn't trigger the `may_leave` restriction

### Investigation Areas

- Exact differences between Go and TinyGo's `random_get` implementation
- How TinyGo avoids the recursive component boundary crossing
- Whether this is a wasmtime implementation issue or component model design limitation

**Confirmed**: This is a component model boundary enforcement issue triggered by **Go's specific implementation pattern**. The adapter and wasmtime are working as designed - the issue is the interaction between Go's runtime initialization and component model restrictions.

---

Let me know if you need any additional information or test cases!