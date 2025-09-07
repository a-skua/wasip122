# WASM Component Debugger Design Plan

## 目的
Go P2 vs Rust P2のアダプター内部動作差異を特定

## 必要な機能

### 1. Component Interface Tracing
```rust
// wasi:io/poll初期化フローのトレース
// wasi:clocks/monotonic-clock初期化フローのトレース  
// ImportAlloc状態変化の記録
```

### 2. 関数呼び出しフロー記録
```
runtime.rt0_go
├── runtime.schedinit
│   ├── runtime.goenvs
│   │   ├── args_sizes_get ← ここでクラッシュ
│   │   └── environ_sizes_get
│   └── [Poll初期化]
└── main関数
```

### 3. アダプター状態スナップショット
```rust
// State::with_import_alloc呼び出し前後の状態
// ImportAlloc variant変化の詳細記録
// wasi_cli_get_arguments実行フロー
```

## 実装アプローチ

### Option A: wasmtime plugin
```rust
// wasmtimeにカスタムWASIプロバイダー組み込み
// アダプター呼び出しをフック
```

### Option B: 独立デバッガー
```rust
// wasm-toolsベースでカスタムインタープリター
// 実行しながらトレース情報収集
```

### Option C: アダプター改造
```rust
// WASI adapter自体にデバッグログ追加
// wasip122ツールで独自ビルド版使用
```

## 推奨: Option C
- 最も確実
- アダプター内部状態に完全アクセス
- ImportAlloc state corruption の瞬間を捉えられる