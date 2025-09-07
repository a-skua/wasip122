wit_bindgen::generate!({
    world: "wrapper",
    path: "wit",
    with: {
        "wasi:random/random@0.2.0": generate,
    },
});

use exports::random::wrapper::wrapper_random::Guest;

struct Component;

impl Guest for Component {
    fn get_random_bytes(len: u32) -> Vec<u8> {
        eprintln!("🔍 WRAPPER: random_get called with len={}", len);
        
        // Get stack trace info
        eprintln!("🔍 WRAPPER: Call from Go runtime initialization");
        
        // Call the actual WASI random function
        let result = wasi::random::random::get_random_bytes(len as u64);
        
        eprintln!("🔍 WRAPPER: random_get returning {} bytes", result.len());
        result
    }
}

export!(Component);