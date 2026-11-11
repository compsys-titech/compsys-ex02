# 2026年度「計算機システム（演習）」第2回

東京科学大学，数理・計算科学系の学部2年生向け教材である．Cの関数呼出しと，RISC-Vの命令・レジスタ・スタックの対応を観察する．

**目次**

- [1．学ぶこと](#1学ぶこと)
- [2．使用するツール](#2使用するツール)
- [3．動作確認状況](#3動作確認状況)
- [4．教材の取得・更新](#4教材の取得更新)
- [5．リポジトリ構成](#5リポジトリ構成)
- [6．ツールの配置](#6ツールの配置)
- [7．環境の確認](#7環境の確認)
- [8．例題の生成](#8例題の生成)
- [9．未リンクとリンク後の違い](#9未リンクとリンク後の違い)
- [10．命令トレース](#10命令トレース)
- [11．課題の生成](#11課題の生成)
- [12．提出時の注意](#12提出時の注意)
- [13．トラブルシューティング](#13トラブルシューティング)

## 1．学ぶこと

リーフ関数 `add2` と非リーフ関数 `add_then_sub` を比べ，次を説明できるようになる．

- `call`・`ret` と，戻り先を保持する `ra` の役割
- `sp` によるスタックフレームの確保・解放と，`sw`・`lw` による保存・復元
- 関数呼出しを越えて必要な値を保持する方法
- PC，レジスタ，保存領域の内容が命令実行によって変化する様子

授業中に読む例題は [src/example.c](src/example.c)，レポートで分析する課題は [src/task.c](src/task.c) である．ソースとMakefileは全員共通のものを使い，演習中は変更しない．

## 2．使用するツール

| 項目 | 指定 |
| --- | --- |
| ISA／ABI | RV32I／ILP32 |
| 最適化／C言語 | `-O1`／C11，LTOなし |
| コンパイル・リンク・逆アセンブル | xPack GNU RISC-V Embedded GCC **15.2.0-1** |
| RISC-Vコードの実行 | xPack QEMU RISC-V **9.2.4-1** |
| CPU状態の観察 | 上記GCC配布物に含まれるGDB |
| 基本操作 | Git，GNU Make，テキストエディタ |

第1回で配置した `compsys-tools` をそのまま利用できる．GCCで生成したRISC-VのELFをQEMUで実行し，GDBからCPUの実レジスタとメモリを読む．自分のPCのCPUでRISC-VのELFを直接実行するわけではない．追加のPythonやNode.js，管理者権限，Docker，別OSの仮想マシン，恒久的なPATH設定は不要である．

## 3．動作確認状況

| 実際に確認した環境 | 確認内容 |
| --- | --- |
| macOS 27.2.1／Apple Silicon（arm64），GNU Make 3.81 | 生成，QEMU・GDBでの命令トレース，空白パス，並列ビルド |

第2回の教材は，GNU/Linux，Windows x64，macOS Intel，西8計算機実習室GNU/Linuxでは未検証である．第1回の確認結果を，第2回の確認済みとは扱わない．

## 4．教材の取得・更新

初めて取得する場合は，Gitが使える端末で書込み可能なフォルダーを開き，次を実行する．

```sh
git clone https://github.com/compsys-titech/compsys-ex02.git
cd compsys-ex02
```

取得済みの場合は，課題開始時と提出前に教材のフォルダーで更新する．

```sh
git pull --ff-only
```

エラーが出た場合は作業ファイルを保持し，教員・TAへ相談する．以降のコマンドは，`Makefile` がある `compsys-ex02` のルートで実行する．元の公開リポジトリへのpushやPull Requestは不要である．

## 5．リポジトリ構成

```text
compsys-ex02/
├── README.md
├── AGENTS.md
├── Makefile
├── .gitignore
├── src/
│   ├── example.c
│   └── task.c
├── tools/
│   ├── link.ld
│   ├── example_start.S
│   ├── task_start.S
│   └── trace-example.gdb
└── build/
    └── .gitkeep
```

| 場所 | 役割 | 受講者の操作 |
| --- | --- | --- |
| [README.md](README.md) | 導入・操作・観察の手順 | 読む |
| [src/example.c](src/example.c) | 授業中に扱う例題 | 読む．編集しない |
| [src/task.c](src/task.c) | レポートの分析対象 | 読む．編集しない |
| [Makefile](Makefile) | 生成・環境確認・実行を自動化 | 編集しない |
| [tools/link.ld](tools/link.ld) | ELFの配置とスタックの初期位置 | 編集しない |
| [tools/example_start.S](tools/example_start.S)，[tools/task_start.S](tools/task_start.S) | スタックと入力を用意し，C関数を呼ぶ | 編集しない |
| [tools/trace-example.gdb](tools/trace-example.gdb) | 例題の命令を実行し，CPU状態を表示 | 編集しない |
| `build/` | 生成物の置き場 | 生成されたファイルを読む |
| [AGENTS.md](AGENTS.md) | 教材保守時の作業指針 | 受講者は読む必要なし |
| [.gitignore](.gitignore)，`build/.gitkeep` | Gitの管理設定と空ディレクトリの維持 | 編集しない |

`tools/` は小さな教材用補助ファイルの置き場である．GCCやQEMUの本体を入れない．`build/` の内容は自動生成され，`make clean` で `.gitkeep` 以外を削除する．自分のレポート等はリポジトリ外に置く．

## 6．ツールの配置

第1回と同じ指定版がある場合は，再ダウンロードせず [環境の確認](#7環境の確認) へ進む．初めて配置する場合は，ホームフォルダー直下に `compsys-tools` を作り，次の構成へ展開する．教材リポジトリとは別の場所である．

```text
compsys-tools/
├── xpack-riscv-none-elf-gcc-15.2.0-1/
│   └── bin/
└── xpack-qemu-riscv-9.2.4-1/
    └── bin/
```

公式リリースの「Assets」からOS・CPUに合うアーカイブを取得する．[GCC 15.2.0-1](https://github.com/xpack-dev-tools/riscv-none-elf-gcc-xpack/releases/tag/v15.2.0-1) ／ [QEMU 9.2.4-1](https://github.com/xpack-dev-tools/qemu-riscv-xpack/releases/tag/v9.2.4-1)

| OS・CPU | GCCのアーカイブ | QEMUのアーカイブ |
| --- | --- | --- |
| Windows x64 | `xpack-riscv-none-elf-gcc-15.2.0-1-win32-x64.zip` | `xpack-qemu-riscv-9.2.4-1-win32-x64.zip` |
| macOS Intel | `xpack-riscv-none-elf-gcc-15.2.0-1-darwin-x64.tar.gz` | `xpack-qemu-riscv-9.2.4-1-darwin-x64.tar.gz` |
| macOS Apple Silicon | `xpack-riscv-none-elf-gcc-15.2.0-1-darwin-arm64.tar.gz` | `xpack-qemu-riscv-9.2.4-1-darwin-arm64.tar.gz` |
| GNU/Linux x64 | `xpack-riscv-none-elf-gcc-15.2.0-1-linux-x64.tar.gz` | `xpack-qemu-riscv-9.2.4-1-linux-x64.tar.gz` |
| GNU/Linux arm64 | `xpack-riscv-none-elf-gcc-15.2.0-1-linux-arm64.tar.gz` | `xpack-qemu-riscv-9.2.4-1-linux-arm64.tar.gz` |

Windowsは「設定」→「システム」→「バージョン情報」，macOSは「このMacについて」でCPUを確認する．GNU/Linuxは `uname -m` の `x86_64` がx64，`aarch64` がarm64に対応する．

### Windows x64

1. エクスプローラーのアドレス欄に `%USERPROFILE%` を入力し，ホームに `compsys-tools` を作る．
2. 各ZIPを「すべて展開」し，`bin` を含む2つのxPackフォルダーを `compsys-tools` へ移す．同名フォルダーが二重になっていないことを確認する．
3. GCC側の `bin` に `riscv-none-elf-gcc.exe`，`riscv-none-elf-objdump.exe`，`riscv-none-elf-readelf.exe`，`riscv-none-elf-gdb.exe`，QEMU側の `bin` に `qemu-system-riscv32.exe` があることを確認する．

GNU Makeがない場合は [xPack Windows Build Tools 4.4.1-3](https://github.com/xpack-dev-tools/windows-build-tools-xpack/releases/tag/v4.4.1-3) の `xpack-windows-build-tools-4.4.1-3-win32-x64.zip` を展開し，そのフォルダーも `compsys-tools` に置く．教材ルートでPowerShellを開き，次の1行を実行すると，そのウィンドウ内で `make` を使える．恒久的なPATH設定は行わない．

```powershell
Set-Alias -Name make -Value "$env:USERPROFILE\compsys-tools\xpack-windows-build-tools-4.4.1-3\bin\make.exe"
```

### macOS Intel／Apple Silicon

Finderの「移動」→「ホーム」で `compsys-tools` を作る．ダウンロードした2つの `.tar.gz` をダブルクリックで展開し，`bin` を含む各xPackフォルダーをその中へ移す．GNU MakeとGitにはXcode Command Line Toolsのものを使う．利用できない場合は教員・TAへ相談する．

### GNU/Linux x64／arm64

ファイルマネージャーでホームに `compsys-tools` を作る．取得した2つの `.tar.gz` をアーカイブマネージャーで展開し，`bin` を含む各xPackフォルダーをその中へ移す．GNU MakeとGitにはPCに用意されているものを使う．

macOS／GNU/Linuxでは，GCC側の `bin` に `riscv-none-elf-gcc`，`riscv-none-elf-objdump`，`riscv-none-elf-readelf`，`riscv-none-elf-gdb`，QEMU側に `bin/qemu-system-riscv32` があることを確認する．

### アーカイブの確認

取得したファイルのSHA-256を，公式リリースの同名の `.sha` ファイルにある値と照合する．次の `取得したファイル名` は実際の名前へ置き換える．

```powershell
# Windows
Get-FileHash "$HOME\Downloads\取得したファイル名" -Algorithm SHA256
```

```sh
# macOS
shasum -a 256 ~/Downloads/取得したファイル名
# GNU/Linux
sha256sum ~/Downloads/取得したファイル名
```

GCCのバナーは15.2.0，QEMUは9.2.4と表示され，配布改訂番号 `-1` は表示されない．配布改訂番号は取得元・アーカイブ名・SHA-256で確認する．

### 別の場所に配置する場合

MakefileはGCCとQEMUをそれぞれ，次の優先順で探索する．採用後に版を確認する．

1. `COMPSYS_TOOLS` が指す親フォルダー内の指定xPackフォルダー
2. ホーム直下の `compsys-tools` 内の指定xPackフォルダー
3. 既存のPATH上で必要な実行ファイルがそろうフォルダー

標準配置なら設定不要である．別の場所を使うときだけ，2つのxPackフォルダーを収めた**親フォルダー**を指定する．次は現在の端末だけで有効な指定例である．

```sh
# macOS／GNU/Linux：実際の親フォルダーへ置き換える．
export COMPSYS_TOOLS="/path/to/compsys-tools"
```

```powershell
# Windows：実際の親フォルダーへ置き換える．
$env:COMPSYS_TOOLS = "D:\compsys-tools"
```

不要になったツールは `compsys-tools` 内の該当サブフォルダーだけをごみ箱へ移せる．教材を削除しても別の場所にあるツールは残る．

## 7．環境の確認

教材ルートで次を実行する．Windowsでは先ほど別名を設定したPowerShellを使う．

```sh
make check
```

GCC・objdump・readelf・GDB・QEMUの絶対パス，探索元，版が表示される．RV32I／ILP32の最小コンパイルと，停止状態のQEMUの起動・終了が成功すれば環境確認は完了する．失敗した場合は表示されたツール名，期待配置先，版を確認する．

| コマンド | 処理 |
| --- | --- |
| `make help` | コマンド一覧 |
| `make check` | ツールと動作の確認 |
| `make example` | 例題の5種類の生成物 |
| `make task` | 課題の5種類の生成物 |
| `make all` | 例題と課題を両方生成 |
| `make trace-example` | 例題の命令・CPU状態を自動観察 |
| `make clean` | `build/.gitkeep` 以外の生成物を削除 |

## 8．例題の生成

```sh
make example
```

`add2(x,y)` は和を返すリーフ関数である．`add_then_sub(x,y,z)` は `add2` を呼んだ後に `z` を引く非リーフ関数である．入力 `x=13, y=5, z=3` では，内側の結果は18，外側の結果は15になる．`noinline` はインライン展開を防ぐ指定であり，実際の呼出しは生成物で確認する．

共通条件は `-march=rv32i -mabi=ilp32 -O1 -std=c11` である．`-O1` は，この短い関数で不要な引数の退避を抑えつつ，呼出しと必要な保存・復元を観察できる条件として使う．フレームポインタの強制やLTOは行わない．

## 9．未リンクとリンク後の違い

| 例題の生成物 | 内容と読む目的 |
| --- | --- |
| `build/example.s` | GCCが出力したアセンブリ．Cと命令の対応を読む |
| `build/example.o` | 未リンクのELFオブジェクト．バイナリであり，実行時アドレスは未確定 |
| `build/example.dump` | `.o` の逆アセンブルと再配置情報．命令語とリンク前の呼出しを読む |
| `build/example.elf` | スタートアップとリンクした実行可能ELF．QEMUが実際に実行する |
| `build/example.elf.dump` | リンク後の命令列・シンボル・確定アドレス．呼出し先と戻り先の正本 |

生成の流れは `.c → .s → .o`，その `.o` とスタートアップから `.elf` へ，という順である．`build/example_start.o` はリンク用の中間ファイルである．課題も同様に `task` の名前で生成し，`build/task_start.o` を使う．

`.dump` の左端は未リンクの `.text` 内の位置であり，QEMU上のPCではない．`R_RISCV_CALL_PLT` 等の再配置はリンク時に解決される．`.s` の疑似命令 `call` が，リンク後は `jal` に短縮される場合もある．**呼出しの飛び先，戻り先，実命令列は `.elf.dump` で読む**．リンク前の `auipc`・`jalr` を，そのまま実行時命令列として転記しない．

リンク位置とスタックの初期位置は [tools/link.ld](tools/link.ld) で管理する．現行配置はコード先頭 `0x80000000`，入口時の `sp=0x80020000` であり，スタック用に上端から4KiBを分ける．`sp` は標準ABIの16バイト境界に整列する．

## 10．命令トレース

```sh
make trace-example
```

同じ `build/example.elf` をQEMU上で実行する．GDBとの接続は標準入出力を使い，固定TCPポートやGDBの対話入力は必要ない．PC・次の命令・`ra`・`sp`・`a0`・`a1`・`a2`・`s0` と，実際に書き込まれた保存領域が表示される．値はCPUとメモリから取得している．

各行は，**表示された命令を次に実行する直前の状態**である．行の間に出るGDBのアドレス表示は，1命令進めた後の停止位置を示す．起動直後には，入口まで進むためのアドレス表示も出る．

| 表示名 | 観察する状態 |
| --- | --- |
| `outer entry` | 非リーフ関数の入口．S=sp，R0=ra，V=s0を記録 |
| `after frame allocation` | spを減らした直後．まだ保存前 |
| `after save ra`，`after saved-register store` | 戻り先と元の保存レジスタをメモリへ書き込んだ直後 |
| `z ready / before call` | 呼出し後にも必要なzを保持し，内側のcallを実行する直前 |
| `add2 entry` | 呼出し先の入口．R1=raを記録 |
| `after add / before ret` | 内側の計算後，内側retの直前 |
| `inner return / before sub` | R1へ戻り，後続演算を実行する直前 |
| `after result operation` | 後続演算が終わった直後 |
| `after restore ra`，`after saved-register load` | 元のレジスタを読み戻した直後 |
| `sp restored / before ret` | spをSへ戻し，外側retを実行する直前 |
| `outer return (R0)` | 外側retでR0へ戻った直後 |

現行例題ではF=16バイト，保存レジスタはs0となった．入口のs0には識別用のV=`0x13579bdf` が入る．元のraをS−4へ，元のs0をS−8へ保存し，zはレジスタs0に保持する．`add2` 自体はspを操作しない．**リーフ関数が常にスタック不要になるという意味ではない**．

sp復元後も，表示する保存先は入口のSを基準に固定した絶対アドレスである．`released; bytes remain` は，領域を解放したがメモリ内容は残っているという意味であり，現在の `8(sp)`・`12(sp)` が以前の保存先を指すわけではない．この表示は教材の停止中に行う観察であり，一般のプログラムが解放後の領域を利用してよいという意味ではない．

最後に `PC=R0, ra=R0, sp=S, s0=V; return a0=15` と確認結果が表示される．QEMUはGDBから終了するため，標準エラーに `QEMU: Terminated via GDBstub` と出るのは通常の終了通知である．エラーや非0終了を無視してよいという意味ではない．

## 11．課題の生成

```sh
make task
```

`src/task.c` の `sub2` と `call_task` を，入力 `x=13, y=5, z=3` で分析する．生成物は `build/task.s`，`build/task.o`，`build/task.dump`，`build/task.elf`，`build/task.elf.dump` である．

授業資料の課題Aでは呼出し・戻り先，課題Bではスタックの保存・復元，課題Cでは値の変化を観察する．命令とフレームは自分の生成物を根拠に読み，呼出し先と戻り先には `task.elf.dump` のアドレスを使う．例題の結果を課題へ転記しない．課題の値は命令から追い，例題の実測ログと区別する．

課題用の自動トレースは提供しない．正式な設問・記入欄は授業資料とLMSの案内を参照する．

## 12．提出時の注意

レポート雛形，正式な提出仕様，ZIPの内容，締切は授業資料とScience Tokyo LMSで案内する．このリポジトリにはWord雛形や確定版のレポート記入ガイドを含めていない．

GCC・QEMU本体，取得したツールのアーカイブ，`.git/`，個人用の一時ファイルは提出ZIPへ入れない．ソースとMakefileを変更せず，自分の生成物と説明・図・値の対応を確認する．元リポジトリへのpushやPull Requestは不要である．

## 13．トラブルシューティング

- `make` が見つからない：GNU Makeの準備を確認する．Windowsでは，別名を設定した同じPowerShellを使う．
- ツールが見つからない：ホーム直下の `compsys-tools` と，その中の各xPackフォルダーの直下に `bin` があることを確認する．`COMPSYS_TOOLS` は `bin` ではなく親フォルダーを指定する．
- 版が異なる：`make check` の検出元・絶対パスを確認し，指定版を使う．
- 命令が資料と異なる：`make check`，`make clean`，再生成の順に確認する．改善しなければ生成物を教員・TAへ示す．
- トレースが途中で失敗する：OS・CPU，`make check` の出力，エラー，最後の命令とレジスタ値を保存して教員・TAへ相談する．

macOSで開発元を確認できない旨の警告が出た場合は，警告のツール名を確認し，公式アーカイブとSHA-256の一致を確かめる．その後，Appleメニュー →「システム設定」→「プライバシーとセキュリティ」の「セキュリティ」で，該当ツールの「このまま開く」を選び，確認画面で許可する．ターミナルに戻って `make check` を再実行する．画面の案内は [Appleの公式手順](https://support.apple.com/ja-jp/102445) を参照する．`Killed: 9` だけでは原因を特定できないため，警告が見当たらない場合は教員・TAへ相談する．

質問・連絡は授業のSlack `#dp-compsys-mcs-t233-2026` を使う．SlackとScience Tokyo LMSを定期的に確認する．

技術上の参考：[RISC-V psABI](https://riscv-non-isa.github.io/riscv-elf-psabi-doc/)，[GCCのnoinline属性](https://gcc.gnu.org/onlinedocs/gcc-15.2.0/gcc/Common-Function-Attributes.html)，[QEMUのGDB接続](https://www.qemu.org/docs/master/system/gdb.html)．
