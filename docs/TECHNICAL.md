# LCME 技術詳細

[English version →](TECHNICAL-EN.md)

このドキュメントは実装の仕組みを説明する開発者向け資料です。導入・使い方は
[README.md](../README.md) を参照してください。

## ソース構成

| ファイル | 役割 |
|---|---|
| `Sources/MEMachVM.h` | iOS SDKでは`#error`によりブロックされている`mach_vm_*`系関数のプロトタイプを手動宣言 |
| `Sources/MemScanner.*` | メモリ領域の列挙・スキャン・絞り込み・読み書きのコア |
| `Sources/FreezeManager.*` | 書き込みループ方式によるfreeze実装 |
| `Sources/MEOverlayWindow.*` | 最前面オーバーレイ用`UIWindow`。パネル外タップの背後アプリへの通過処理 |
| `Sources/MEOverlayViewController.*` | トグルボタン・パネルUI本体 |
| `Sources/MEResultCell.*` | 検索結果一覧の1行(アドレス・値編集・freezeトグル) |
| `Sources/MEConstructor.m` | `__attribute__((constructor))`によるdylibロード時の自動起動 |
| `Sources/MEDefs.*` | 対応する値の型と定数(許容誤差など)の定義 |

## なぜ非脱獄(no-jailbreak)で動くのか

このtweakは`task_for_pid`や`ptrace`のような**他プロセスを操作する特権API**を一切使いません。
LiveContainerのTweakLoaderによってdylibが**対象アプリと同一プロセス内**にロードされるため、
`mach_task_self()`(=自分自身のタスクポート)に対して`mach_vm_read` / `mach_vm_write` /
`mach_vm_region_recurse`を呼ぶだけでメモリの読み書き・列挙ができます。自プロセスの操作は
サンドボックスの範囲内で誰でも行える通常の操作であり、脱獄や特別なentitlementを必要としません。

iOS SDKのヘッダ(`<mach/mach_vm.h>`)はこれらの関数を`#error`でブロックしていますが、
実行時のlibSystemには実体のシンボルが存在するため、`Sources/MEMachVM.h`でプロトタイプだけを
手動で宣言することでコンパイル・リンクの両方を通しています。

## スキャンの仕組み

1. `mach_vm_region_recurse`で対象タスクの全メモリ領域を列挙する(submapは深さを増やしながら再帰的に辿る)
2. 書き込み可能(`VM_PROT_WRITE`)な領域のみを対象にする
3. デフォルトでは`share_mode == SM_PRIVATE`かつ外部ページャを持たない**匿名(malloc系)領域**のみに絞る(ヒープ中心・高速)。全領域スキャンをONにするとこの絞り込みを外す
4. 各領域を4MB単位で`mach_vm_read`しながら、型のバイトサイズ単位(整数・浮動小数点)またはバイト単位(文字列)でスキャンする。チャンクの境界をまたぐ値を取りこぼさないよう、末尾に`型サイズ-1`バイトの重なりを持たせて読み込む

比較方法は型によって異なります。

- 整数・文字列: 完全一致(`memcmp`)
- float/double: 許容誤差付きの近似一致(`MEFloatTolerance` = 0.01, `MEDoubleTolerance` = 0.0001)。GameGuardianの緩め判定に近い挙動
- 範囲検索(min〜max): 対象バイト列を`double`に変換して範囲判定。Int64/UInt64は2^53超で丸め誤差が出うるが、ゲーム内の一般的な数値では実用上問題にならない

絞り込み(narrowing)は新規スキャンをせず、既存候補のアドレスだけを再読み込みして判定し直す
ため、候補が多くても高速です。

## Freezeの仕組み

`FreezeManager`が`dispatch_source`のリピートタイマー(100ms間隔)を持ち、登録済みアドレスへ
`mach_vm_write`で値を再書き込みし続けます。スレッド一時停止ではなく**書き込みループ方式**を
採用しているのは、in-process注入ではアプリのUIスレッドを止めるとオーバーレイ自体も操作不能に
なってしまうためです。エントリの配列はメインスレッド(UI操作)とタイマースレッドの両方から
アクセスされるため`@synchronized`で保護しています。

## UI実装で工夫した点

- **背後アプリへのタップ透過**: `MEOverlayWindow`は`hitTest:withEvent:`をオーバーライドし、
  パネル・トグルボタン以外の領域へのタップではrootViewControllerのビュー自身がヒットした
  場合に`nil`を返す。これによりUIKitがそのタッチを一つ後ろのウィンドウ(対象アプリ本体)へ
  回すため、パネル外は素通しになる
- **候補一覧の自動更新**: パネルを開いている間、0.5秒間隔で値の変動を追跡する。素朴に
  `UITableView reloadData`を呼ぶと、テーブルのセル再利用(dequeue)が発生し、値を編集中の
  セルであっても`firstResponder`状態が壊れてキーボードが閉じてしまう不具合があったため、
  表示中のセル(`visibleCells`)を直接書き換える方式に変更している
- **タップ検知**: トグルボタンのドラッグは`UIPanGestureRecognizer`で処理しているが、
  `UIPanGestureRecognizer`は一定距離動かないと`Began`/`Ended`へ遷移せずコールバックが
  一切呼ばれない。そのため純粋なタップの検知は`UIButton`標準の`touchUpInside`に任せている

## 意図的に実装していない機能

- ゲーム全体の一時停止/再開(in-process注入ではUI/操作も巻き込んで止まってしまうため、
  freezeによる個別値の固定で代替する設計)
- コード書き換え、ポインタ探索チェーン、メモリダンプ、Luaスクリプト等の高度な機能
  (「簡単・iOS 26・LiveContainer対応」をスコープとして優先しているため)

## ソースからのビルド

```bash
export THEOS=~/.theos
make
```

成果物は `.theos/obj/debug/LCMemEditor.dylib`。リリースビルドは `make FINALPACKAGE=1`。
