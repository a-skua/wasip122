# 🔧 WASIアダプター改造による根本原因調査 - 引き継ぎ資料

## 📋 **現在の状況サマリー**

### **根本原因特定完了**
✅ **問題**: GoのWASI P1→P2変換でアダプターがクラッシュ  
✅ **原因**: Goランタイムが要求する複雑なWASI P2インターフェースがアダプターの`ImportAlloc`状態管理を破壊  
✅ **証拠**: 最小限のGoプログラムでも同じエラー、Rust/TinyGoは正常動作  

### **技術的詳細**
- **クラッシュ場所**: wasmtime adapter line 2786 `unreachable!()` in `args_sizes_get`
- **直接原因**: `ImportAlloc`が期待される`CountAndDiscardStrings`ではない状態
- **根本原因**: Go P2が要求する複雑インターフェース群
  - `wasi:io/poll@0.2.3` (非同期I/O)
  - `wasi:clocks/monotonic-clock@0.2.3` (高精度タイマー)
  - `wasi:cli/terminal-*` (ターミナル制御)

## 🎯 **次のアクション: アダプター改造デバッグ**

### **目的**
複雑インターフェース初期化のどの段階で`ImportAlloc`状態が破壊されるかを特定

### **アプローチ決定理由**
1. **実行ログ取得困難**: WASM環境でRUST_LOGなど効かない
2. **WAT静的解析限界**: 1000行以上の手動解析は非現実的
3. **アダプター改造**: 最も確実、内部状態に完全アクセス可能

## 🛠️ **実装手順**

### **Phase 1: 環境準備**
```bash
# 1. 適切なディレクトリでwasmtime クローン
cd ~/dev  # またはお好みの場所
git clone https://github.com/bytecodealliance/wasmtime.git
cd wasmtime
git checkout v33.0.0  # 現在使用中のバージョン

# 2. アダプターディレクトリ確認
ls crates/wasi-preview1-component-adapter/src/
# 主要ファイル:
# - lib.rs (メイン実装、args_sizes_get関数)
# - macros.rs (assert_fail実装)
```

### **Phase 2: デバッグコード追加**
```rust
// crates/wasi-preview1-component-adapter/src/lib.rs
// args_sizes_get関数 (line 511-545) を改造

pub unsafe extern "C" fn args_sizes_get(argc: &mut Size, argv_buf_size: &mut Size) -> Errno {
    // デバッグ出力: 関数開始
    debug_log(b"DEBUG: args_sizes_get START\n");
    
    State::with(|state| {
        // デバッグ出力: ImportAlloc呼び出し前
        debug_log(b"DEBUG: before with_import_alloc\n");
        
        let (len, alloc) = state.with_import_alloc(alloc, || unsafe {
            // デバッグ出力: wasi_cli_get_arguments前
            debug_log(b"DEBUG: calling wasi_cli_get_arguments\n");
            
            let mut list = WasmStrList { base: std::ptr::null(), len: 0 };
            wasi_cli_get_arguments(&mut list);
            
            // デバッグ出力: wasi_cli_get_arguments後
            debug_log(b"DEBUG: wasi_cli_get_arguments completed\n");
            
            list.len
        });
        
        // デバッグ出力: ImportAlloc variant確認
        match alloc {
            ImportAlloc::CountAndDiscardStrings { strings_size, alloc: _ } => {
                debug_log(b"DEBUG: SUCCESS - Got CountAndDiscardStrings\n");
                *argc = len;
                *argv_buf_size = strings_size + len;
            }
            ImportAlloc::SeparateStringsAndPointers { .. } => {
                debug_log(b"DEBUG: ERROR - Got SeparateStringsAndPointers\n");
                unreachable!();
            }
            ImportAlloc::OneAlloc { .. } => {
                debug_log(b"DEBUG: ERROR - Got OneAlloc\n");
                unreachable!();
            }
        }
        Ok(())
    })
}

// デバッグ出力ヘルパー関数追加
unsafe fn debug_log(msg: &[u8]) {
    use crate::bindings::wasi::io::streams::OutputStream;
    
    // stderr にメッセージ出力
    if let Ok(stderr) = crate::bindings::wasi::cli::stderr::get_stderr() {
        let _ = stderr.blocking_write_and_flush(msg);
    }
}
```

### **Phase 3: ビルド・統合**
```bash
# 3. アダプターをビルド
cd crates/wasi-preview1-component-adapter
cargo build --release --target wasm32-wasip1

# 4. 生成されたアダプターバイナリの場所確認
find . -name "*.wasm" | grep adapter

# 5. wasip122でカスタムアダプター使用するよう修正
# wasip122/src/main.rs を変更してカスタムアダプターバイナリを読み込み
```

### **Phase 4: デバッグ実行**
```bash
# 6. 改造版でテスト
cd wasip122
cargo run -- -o examples/go/main_debug_p2.wasm examples/go/main.wasm

# 7. デバッグログ付きで実行
wasmtime run examples/go/main_debug_p2.wasm 2> go_debug.log

# 8. Rustとの比較
cargo run -- -o examples/rust/main_debug_p2.wasm examples/rust/main.wasm
wasmtime run examples/rust/main_debug_p2.wasm 2> rust_debug.log

# 9. ログ比較でバグ発生タイミング特定
diff go_debug.log rust_debug.log
```

## 🔍 **期待される発見**

### **仮説A: wasi_cli_get_arguments内でImportAlloc破壊**
```
DEBUG: args_sizes_get START
DEBUG: before with_import_alloc  
DEBUG: calling wasi_cli_get_arguments
[ここで複雑インターフェース初期化が割り込む]
DEBUG: wasi_cli_get_arguments completed
DEBUG: ERROR - Got SeparateStringsAndPointers  ← 状態破壊確認
```

### **仮説B: with_import_alloc自体にバグ**
```
DEBUG: args_sizes_get START
DEBUG: before with_import_alloc
[ここでクラッシュまたは状態異常]
```

## 📁 **重要ファイル一覧**

### **現在のプロジェクト**
- `ERROR_INVESTIGATION_REPORT.md` - 調査の全記録
- `examples/go-minimal/main.go` - 最小再現ケース
- `wasm_debugger_plan.md` - デバッグ戦略

### **改造対象**
- `wasmtime/crates/wasi-preview1-component-adapter/src/lib.rs:511-545`
- `wasip122/src/main.rs` (カスタムアダプター使用)

## 🎯 **成功条件**

1. **デバッグログでImportAlloc状態変化を捉える**
2. **Go vs Rustでの状態遷移差異を特定**
3. **具体的なバグ発生タイミングと原因を判明**

## 🚨 **潜在的な課題**

- **ビルド複雑性**: wasmtimeのビルド環境構築
- **出力方法**: WASMからのstderr出力がうまく行くか
- **バイナリサイズ**: デバッグ版アダプターのサイズ増加

## 💡 **代替案**

もし技術的困難に遭遇した場合:
1. **wasmtime issue報告**: 現在の調査結果で十分な情報
2. **TinyGo使用**: 回避策として実用的
3. **静的解析**: WATファイルの手動確認

---

**引き継ぎ日**: 2025年6月20日  
**調査者**: Claude (C.V.釘宮モード)  
**次セッション目標**: アダプター改造でImportAlloc状態破壊の瞬間を捉える  
**予想調査時間**: 2-3時間 (環境構築含む)

---

*べ、別に完璧な引き継ぎ資料を作ったわけじゃないんだから！でも...これで確実にバグの正体を暴けるはずよ。あんたならきっとできるわ...！* 💫