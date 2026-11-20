# asepal

指定した色をパレットに入れた新規 `.ase` ファイルを作るシェルスクリプトです。
LibreSprite のパレットに色を1つずつコピペする手間をなくすために作りました。

## 動作

- `~/dot-e-kyoshitsu` 内の `Sprite-NNNN.ase` を調べ、最大番号の次の番号で新しいファイルを作ります
  - 例: `Sprite-0001.ase` が最新なら `Sprite-0002.ase` を作成
  - ファイルがひとつもなければ `Sprite-0001.ase`
- 指定した色を 0 番から順にパレットへ書き込みます

作成されるスプライトの設定:

| 項目 | 値 |
| --- | --- |
| サイズ | 32 × 32 px |
| カラーモード | RGBA |
| 背景 | 透明 |
| レイヤー | 1枚（`Layer 1`、空） |
| フレーム | 1 |

## インストール

```sh
chmod +x ~/h/asepal
```

.zshrc に `export PATH="$HOME/h/asepal:$PATH"` を追加する。

## 使い方

```sh
asepal hex1 hex2 ...
```

- hex は 6 桁（`RRGGBB`）。`#` は付けません（付けるとエラー）
- 色は最大 256 色まで

例:

```sh
asepal 985E30 A58035 D2AB62 DACB70 F3E2A2
# => /Users/you/dot-e-kyoshitsu/Sprite-0002.ase (5 colors)
```

## 必要環境

- bash（macOS 標準の bash 3.2 で動作）
- `head` / `wc` / `mktemp` などの標準コマンドのみ。追加の依存はありません

## 制限

- 新規作成専用です。既存の `.ase` ファイルのパレットを書き換えることはできません
- 出力先ディレクトリ・サイズ・カラーモードはスクリプト内に固定で書いています。変更する場合はスクリプト冒頭の `DIR` / `W` / `H` を編集してください

## ファイル形式

[Aseprite File Format (.ase/.aseprite) Specifications](https://github.com/aseprite/aseprite/blob/main/docs/ase-file-specs.md) に沿って、次のチャンクを書き出します。

- Old palette chunk (`0x0004`) — 互換用
- Palette chunk (`0x2019`)
- Layer chunk (`0x2004`)