#![no_std]

use core::panic::PanicInfo;

#[panic_handler]
fn panic(_info: &PanicInfo) -> ! {
    loop {}
}

// WASI Preview 1のrandom_get実装
#[no_mangle]
pub unsafe extern "C" fn random_get(buf: *mut u8, buf_len: u32) -> u32 {
    // 簡単なLinear Congruential Generator
    static mut SEED: u32 = 12345;
    
    for i in 0..buf_len {
        SEED = SEED.wrapping_mul(1103515245).wrapping_add(12345);
        let random_byte = (SEED >> 16) as u8;
        core::ptr::write(buf.add(i as usize), random_byte);
    }
    
    0 // WASI_SUCCESS
}

// プロセス終了
#[no_mangle]
pub unsafe extern "C" fn proc_exit(exit_code: u32) -> ! {
    loop {}
}

// エントリーポイント
#[no_mangle]
pub unsafe extern "C" fn _start() {
    // 何もしない - 私たちはlibrary
}

// メモリ管理は不要（自動でmemoryがエクスポートされる）