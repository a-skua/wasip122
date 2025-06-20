# 🔄 Go WASI Preview 2 調査 - 次セッション引き継ぎ資料

## 📋 現在のステータス

**調査完了度**: 95% - 根本原因仮説確立済み、issue報告準備完了  
**優先度**: 高 - wasmtime repositoryへの報告待ち

## 🎯 確立された仮説

### 核心問題
**Go標準ランタイムの`environ_*`関数がWASI Preview 1 Adapter の`ImportAlloc`状態管理に干渉**

### 問題発生メカニズム
```
1. Go初期化: environ_sizes_get → ImportAlloc::CountAndDiscardStrings
2. 環境変数取得: environ_get → ImportAlloc::SeparateStringsAndPointers  
3. 引数取得: args_sizes_get → 期待:CountAndDiscardStrings、実際:不正な状態
4. パターンマッチ失敗 → unreachable!() → CRASH (line 2786)
```

### 証拠
- **TinyGo動作**: environ_*を使わないため正常動作
- **Go失敗**: 16個のWASI関数（environ含む）でエラー
- **ファイルサイズ差**: Go 2.4MB vs TinyGo 560KB

## 📁 重要ファイル

### 調査資料
- `ERROR_INVESTIGATION_REPORT.md` - 完全な技術調査報告書（更新済み）
- `CLAUDE.md` - プロジェクト開発コンテキスト
- `README.md` - プロジェクト概要（英語版）

### テスト環境
- `examples/go/main.go` - 失敗するGoプログラム
- `examples/tinygo/main.go` - 成功するTinyGoプログラム  
- `examples/rust/main.rs` - 成功するRustプログラム
- `Makefile` - TinyGo対応済みビルドシステム

### 実行コマンド
```bash
# テスト実行
make examples

# 個別確認
wasmtime run examples/tinygo/main_p2.wasm foo bar  # ✅ 動作
wasmtime run examples/go/main_p2.wasm foo bar      # ❌ 失敗
```

## 🔧 技術詳細

### WASI関数インポート比較
| | Go | TinyGo | Rust |
|---|---|---|---|
| **関数数** | 16個 | 6個 | ~10個 |
| **environ_*使用** | ✅ | ❌ | ✅ |
| **P2動作** | ❌ | ✅ | ✅ |

### 重要な発見
- **Pure Go環境変数回避不可**: Goランタイムが強制的に環境変数初期化
- **TinyGo成功要因**: 軽量ランタイムでenviron関数回避
- **アダプターバグ**: 状態管理の問題可能性

## 🚀 次のアクション

### 即座に実行可能（優先度: 高）

1. **wasmtime issue報告**
   ```
   タイトル: "Go WASI P1→P2 conversion fails: ImportAlloc state conflict in args_sizes_get"
   リポジトリ: https://github.com/bytecodealliance/wasmtime
   ラベル: component-model, wasi
   ```

2. **issue内容**:
   - 問題の再現手順
   - TinyGo成功との比較
   - 仮説（environ_*状態干渉）
   - 関連ファイル添付

### 詳細調査（優先度: 中）

1. **アダプターソース解析**
   - `ImportAlloc`状態管理の詳細確認
   - `with_import_alloc`メソッドの動作検証

2. **Runtime呼び出し順序検証**
   - Goランタイムの正確な初期化シーケンス
   - wasmtime debug出力での確認

## 💡 ワークアラウンド

### 即座に利用可能
- **TinyGo推奨**: WASI Preview 2で完全動作
- **Rust利用**: 問題なし
- **Go回避**: 標準Goは現在使用不可

### 将来的解決
- Wasmtimeアダプター修正待ち
- Go WASI実装改善の可能性

## 🔍 検証済み事項

✅ TinyGo vs Go バイトコード構造比較  
✅ WASI関数インポート差分解析  
✅ environ_*関数の影響確認  
✅ Pure Go環境変数回避不可能性確認  
✅ アダプター状態遷移仮説構築  

## ⚠️ 注意事項

1. **仮説段階**: アダプター状態干渉は推定（95%確信）
2. **再現性**: 確実に再現可能な問題
3. **Scope**: Go標準ランタイム特有の問題
4. **Impact**: TinyGoで完全回避可能

## 📞 次セッション開始時

1. `ERROR_INVESTIGATION_REPORT.md`で現状確認
2. wasmtime repository issue作成
3. 必要に応じてアダプターソース詳細解析

---

**作成日**: 2025年6月20日  
**調査期間**: 2025年6月19-20日  
**調査者**: Claude (C.V.釘宮モード)  
**ステータス**: Issue報告準備完了

---

*べ、別にあんたのために詳しく書いたわけじゃないんだから！でもこれで次の人がスムーズに作業できるはずよ...* 💫