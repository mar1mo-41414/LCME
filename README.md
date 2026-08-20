# LC Mem Editor

[English README →](README-EN.md)

LiveContainer(LC)上で動作するiOSアプリに対して、Cheat Engine / GameGuardian的な
メモリ検索・編集・値固定(freeze)を行うための tweak(dylib)です。

LCのTweakLoader経由で対象アプリと同一プロセス内に注入される **in-process型** のツールで、
`task_for_pid` のような特別な権限は使わず、`mach_vm_*` 系APIで自プロセス
(`mach_task_self()`)のメモリを直接読み書きします。

## 特徴

- dylibをLCのTweaksフォルダに置いて対象アプリのTweak Folderに指定するだけで動作(追加設定不要)
- 値検索 → 候補アドレス一覧 → 個別に値編集 / 固定(freeze)
- 前回候補を保持したまま再検索する絞り込み(narrowing)検索
- 固定(freeze)は**書き込みループ方式**(100ms間隔で再書き込み)。スレッド一時停止は行わない
- 対応型: Int8/16/32/64・UInt8/16/32/64・Float・Double・String(UTF-8, 部分一致)
- float/doubleは許容誤差ありの緩い一致判定(GameGuardian的挙動)
- デフォルトは書き込み可能な匿名(malloc系)領域のみを高速スキャン。オプションで全領域スキャンも可能
- 対象アプリの最前面にオーバーレイパネルを表示。パネル外のタップは背後のアプリへそのまま通過する

## 非対象(意図的に実装していない機能)

- ゲーム全体の一時停止/再開(in-process注入ではUI/操作も巻き込んで止まってしまうため、値freezeで代替)
- コード書き換え、ポインタ探索チェーン、メモリダンプなどの高度な機能

## ビルド

Theos が構築済みであることが前提です。

```bash
export THEOS=~/.theos
make
```

成果物は `.theos/obj/debug/LCMemEditor.dylib` に生成されます(fat/thinどちらも同名で並びます)。
リリースビルドしたい場合は `make FINALPACKAGE=1` を使ってください。

## インストール

1. 上記でビルドした `LCMemEditor.dylib` をLiveContainerのTweaksフォルダに配置する
2. 対象アプリの Tweak Folder としてこのdylibを含むフォルダを指定する
3. アプリを起動すると、右側に半透明の丸いトグルボタン("M")がオーバーレイ表示される

## 使い方

1. トグルボタンをタップしてパネルを開く
2. 「型」ボタンでスキャンする型を選択(Int32/Float/Stringなど)
3. 値を入力して「検索(新規)」→ 候補アドレス一覧が表示される
4. ゲーム内で値を変化させてから、変化後の値を入力して「絞込」→ 候補がさらに絞られる
5. 一覧の各行で値を編集してEnter/return → その場で書き込み
6. 「固定」ボタンでそのアドレスをfreeze対象に追加/解除
7. パネル下部の「フリーズ実行中/停止中」ボタンで、freeze対象全体の書き込みループをON/OFF

パネルのヘッダー(タイトルバー)とトグルボタンはドラッグで位置を移動できます。

## アーキテクチャ

- `Sources/MEMachVM.h` — iOS SDKヘッダでは`#error`によりブロックされている
  `mach_vm_region_recurse` / `mach_vm_read` / `mach_vm_write` を手動プロトタイプ宣言
  (実行時のlibSystemにはシンボルが存在するため動作する)
- `Sources/MemScanner.*` — メモリ領域の列挙・スキャン・絞り込み・読み書きのコア
- `Sources/FreezeManager.*` — `dispatch_source_timer` による書き込みループ方式のfreeze実装
- `Sources/MEOverlayWindow.*` / `MEOverlayViewController.*` / `MEResultCell.*` — UIオーバーレイ
- `Sources/MEConstructor.m` — `__attribute__((constructor))` によるdylibロード時の自動起動

## 注意事項

自分が所持・アクセス権を持つアプリ、あるいはシングルプレイの検証目的など、
利用が許可された範囲でのみ使用してください。オンライン対戦やマルチプレイの
チート行為には使用しないでください。
