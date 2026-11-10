# modforkoj

リポジトリA(tar1090_972)の一部ファイルに独自の改造を加え、Aの更新に追従するためのリポジトリです。
このREADMEは、追従用スクリプト `sync-upstream.sh` の運用手順書を兼ねています。

## 前提

- 作業ディレクトリ: `/c/Users/toshi-shimoji/Documents/GitHub`
- リポジトリA: `tar1090_972`(追従元。Aでは編集しない)
- リポジトリB: `modforkoj`(改造先。`sync-upstream.sh` と `.upstream-sha` がルートにある)
- 追従対象: `default`、`html/config.js`、`html/script.js`
- 作業はすべてGit Bashで行う
- `.upstream-sha` は「前回Bに取り込んだAのコミット」の記録。差分の基準はこれで、スクリプト実行時にしか変わらない

## 毎回の手順

### 1. 準備: Bを最新にしてBのフォルダへ移動

```bash
cd /c/Users/toshi-shimoji/Documents/GitHub/modforkoj
git status          # mainブランチで、未コミットの変更がないこと
git pull            # 他のPCからBをpushしている場合のみ。このPCだけなら不要
```

Aの最新化は、手順3のスクリプトが `git pull --ff-only` で自動的に行うので、手動で取得する必要はありません。

### 2. (任意)事前確認: Aの何が変わったかをWinMergeで見る

```bash
base=$(cat .upstream-sha)
git -C ../tar1090_972 fetch
git -C ../tar1090_972 difftool -d $base @{u} -- default html/config.js html/script.js
```

`fetch` だけなのでAの作業ツリーは変わりません。対象ファイルに差分がなければ、取り込みは不要です。

### 3. 同期スクリプトを実行

```bash
bash sync-upstream.sh
```

結果は次の3通りです。

| 表示 | 状態 | 次にやること |
|---|---|---|
| 変更なし | Aに更新なし | 終了 |
| ローカルにコミット済み | 競合なしで取り込み完了(pushはまだ) | 手順4へ |
| 競合: ファイル名 | 競合マーカーが入って停止(未コミット) | 下の「競合したとき」へ |

### 4. 事後確認: Bに何が入ったかをWinMergeで見る

```bash
git show --stat                 # 変わったファイルの一覧
git difftool -d HEAD~1 HEAD     # left=同期前、right=同期後

# Aの変更点(前回取り込み位置 → Aの今)
base=$(git show HEAD~1:.upstream-sha)
git -C ../tar1090_972 difftool -d $base HEAD -- default html/config.js html/script.js
```

見るポイントは、自分の改造箇所とAの変更が近くないか、取り込み後も改造が生きているか、の2点です。

### 5. 問題なければ反映

```bash
git push
```

## 競合したとき

1. 競合したファイルの `<<<<<<<`、`=======`、`>>>>>>>` を直す(WinMergeや好きなエディタで)
2. コミットして確認し、pushする

```bash
git add -A
git commit -m "Sync from upstream"
git difftool -d HEAD~1 HEAD     # 任意: 結果の確認
git push
```

## 取り消したいとき

| 状態 | コマンド |
|---|---|
| 競合で止まっていて、まだコミットしていない | `git restore .` |
| コミット済みで、まだpushしていない | `git reset --hard HEAD~1` |
| すでにpushした | `git revert HEAD`(打ち消しコミットを作る) |

`HEAD~1` はチルダです(ハイフンではありません)。迷ったら `git status` で今の状態を確認してください。

## 初回セットアップ(1回だけ)

1. GitHubで空のリポジトリ `modforkoj` を作る(README等は追加しない)
2. Bを作成してAから3ファイルを取り出す

```bash
cd /c/Users/toshi-shimoji/Documents/GitHub
A=/c/Users/toshi-shimoji/Documents/GitHub/tar1090_972
git -C "$A" pull --ff-only

mkdir modforkoj
cd modforkoj
git init -b main
git config core.autocrlf false

mkdir -p html
git -C "$A" show HEAD:default        > default
git -C "$A" show HEAD:html/config.js > html/config.js
git -C "$A" show HEAD:html/script.js > html/script.js
git -C "$A" rev-parse HEAD | tr -d '\n' > .upstream-sha

git add -A
git commit -m "Initial import from upstream"
git remote add origin https://github.com/tar1090_972/modforkoj.git
git push -u origin main
```

3. 下の `sync-upstream.sh` をBのルートに置き、コミットしてpushする
4. WinMerge連携の設定(1回だけ。WinMergeのパスは実際のWinの環境に合わせて)

```bash
git config --global diff.tool winmerge
git config --global difftool.winmerge.cmd \
  '"C:/Program Files/WinMerge/WinMergeU.exe" -e -u -dl "Before" -dr "After" "$LOCAL" "$REMOTE"'
git config --global difftool.prompt false
```

5. その後、対象3ファイルを改造してコミット・push


## 補足

- Aが対象ファイルを触っていない更新では、`.upstream-sha` だけが更新されてコミットされます(正常)
- Aで先に `git pull` しても、差分の基準は `.upstream-sha` なので取りこぼしません
- `difftool -d` の左右は一時コピーなので、WinMerge上で編集してもBには反映されません
- `HEAD~1` で同期コミットを指せるのは、同期コミットが最新のときだけです。重ねてコミットした後は `git log --oneline` で該当コミットを探してください
