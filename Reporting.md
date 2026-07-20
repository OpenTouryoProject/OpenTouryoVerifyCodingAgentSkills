# セットアップ実行レポート（Plan.md）

OpenTouryo `03-20` タグ / 完全新規リポジトリからのセットアップ。各サンプルの実行で
遭遇した問題点を記録する。

- 環境: Windows 11 / dotnet 10.0.302 / MSBuild = VS18 Community / 作業ルート `C:\otr`
- リポジトリ: `D:\git\local\OpenTouryoProject\OTRVCAS`

---

## 前提: 基盤 DLL のビルド（③）

対象タグ `03-20` の ZIP を取得し、`C:\otr` で net48 / net10.0 の基盤（＋RichClient）をビルドして
`OpenTouryoAssemblies\` へベンダする。全サンプル共通の前提。

### 問題点（セットアップ スクリプト生成時の落とし穴）

1. **`WebClient.DownloadFile()` が GitHub codeload に対して 404**。
   `WebClient` の既定 TLS が古く、`archive/03-20.zip` の取得に失敗する（HEAD では 200 が返るため紛らわしい）。
   → 対処：`[Net.ServicePointManager]::SecurityProtocol = Tls12` を設定し `Invoke-WebRequest` を使う。
   スキルの `examples.md` の雛形は `WebClient` を使っているので、そのままだと踏む。

2. **PowerShell スクリプトの日本語コメントが `powershell.exe`（Windows PowerShell 5.1）で構文を破壊**。
   BOM 無し `.ps1` を WinPS 5.1 は Windows-1252 として読むため、コメント中の UTF-8 日本語バイト列が
   直後の文（`$ref = '03-20'`）を巻き込んで無効化し、`$ref` が空になった（`extract=C:\otr\OpenTouryo-` と
   タグ欠落 → ZIP 再取得 → 404）。**症状が「ダウンロード 404」に化けるため原因特定が難しい。**
   → 対処：スクリプトのコメントを ASCII のみにする（`scripts\*.ps1`）。スキルの雛形は日本語コメント入りなので、
   `powershell.exe` で `-File` 実行する場合は BOM 付き保存か ASCII 化が要る（`pwsh`／PS7 なら既定 UTF-8 で回避可）。
   ※ `.bat` の全角コメント破損はスキルに記載があるが、`.ps1` 版の同種問題は明記されていない。

### ビルド結果

- **net48**: 成功。`OpenTouryoAssemblies\Build_net48\` に OpenTouryo DLL 16 本をベンダ。
  `OpenTouryo.Business.dll` / `Business.RichClient.dll` / `CustomControl.RichClient.dll` /
  `Framework.dll` / `Public.dll` / `Public.Security.dll` を確認。RichClient は `BusinessRichClient_net48.sln`
  の追加ビルドで生成（メモの「CustomControl.RichClient 漏れ」は、sln 追加ビルド後の全出力コピーで解消済み）。
- **net10.0**: 成功。`OpenTouryoAssemblies\Build_netcore100\` に `net10.0\` と `net10.0-windows7.0\`
  の両 TFM をベンダ。メモ通り `net10.0-windows7.0\` は `3_Build_BusinessRichClient_netcore100.bat` で
  初めて `OpenTouryo.Business.dll` / `Business.RichClient.dll` / `Dam*` が生成されるため、フォルダ丸ごとベンダで解消。
  問題なし（既知の `log4net 3.x` `NU1902` 警告はビルドを止めない）。

---

## サンプル別

共通の取り出し・参照張替は `scripts\setup-sample.ps1`（copy → OpenTouryo/MySql/Oracle HintPath を
ベンダ先へ相対で張替 → config の `C:\root\files\resource\` を `%OT_RESOURCE_ROOT%\` 化）で自動化した。

### 1-2. MVC_Sample（net48 / net10.0）

- **net10.0（Core, `MVC_Sample_Core\`）**: `dotnet build` 成功（警告2＝`NU1902` log4net のみ）。WS 依存なし・自己完結。問題なし。
- **net48（`MVC_Sample\`）**: **WS/3層依存**。csproj が `WSIFType_sample` / `WSServer_sample` を
  `..\..\..\WS_sample\Build\*.dll`（ZIP 非同梱の生成物）で参照 → 取り出し直後は `CS0246`。
  スキル通り (A) を採り、`WS_sample\`（`WSIFType_sample`/`WSServer_sample`）を取り出して ProjectReference 化が必要。
  ※詳細と結果は下記「WS 依存 net48 群」に集約。

### 4-7. 2CS（2CSClientWin / 2CSClientWPF、net48 / net10.0）

4種すべて **ビルド成功（0 error）**。RichClient 依存は ③ の追加ビルドで解決済み。
core は TFM `net10.0-windows7.0` なのでベンダ先も `Build_netcore100\net10.0-windows7.0\` を指す（helper に指定）。問題なし。

| 項番 | サンプル | 結果 |
| --- | --- | --- |
| 4 | 2CSClientWin_sample (net48) | OK |
| 5 | 2CSClientWin_sample (net10.0, `_Core`) | OK |
| 6 | 2CSClientWPF_sample (net48) | OK |
| 7 | 2CSClientWPF_sample (net10.0, `_Core`) | OK |

### 14-21. バッチ（SimpleBatch / RerunnableBatch / 〜2 / 〜3、net48 / net10.0）

8種すべて **ビルド成功（0 error）**。WS 依存なし・自己完結。
net48 バッチのフォルダ名は本体では `RerunnableBatch_sample2` / `_sample3`（Plan の「RerunnableBatch2/3」に対応）。問題なし。

### 22-24. CLI（Simple_CLI / DAG_Login_CLI / LIR_Login_CLI、net10.0）

3種すべて **ビルド成功（0 error）**。`Simple_CLI` は純テンプレ（OpenTouryo 依存なし）、
`DAG_Login_CLI` / `LIR_Login_CLI` は OpenTouryo 依存あり（Framework/Public/Public.Security）で HintPath 張替済み。
CLI は net10.0 のみ（net48 版は csproj 無し）。ビルドは通る（`login` サブコマンドの実動は IdP:44300 が要る＝別途）。問題なし。

### 1・3・8-13. WS 依存 net48 群（MVC net48 / WebForms / WSClient 4 variant）

3層（WS）依存サンプルは取り出し直後、別サンプル `WSIFType_sample`（型）/ `WSServer_sample`（B・D層）を
`...\WS_sample\Build\*.dll`（ZIP 非同梱の生成物）で参照するため `CS0246`。スキルの (A) に従い解消した：

- `WS_sample\` を階層維持で取り出し（`WSIFType_sample` / `WSServer_sample` / `WSClient_sample\<variant>` /
  WS ホスト `ServiceInterface\ASPNETWebService`。源は `Frameworks\Infrastructure\ServiceInterface`）。
- クライアント/ホスト → `WSServer_sample`/`WSIFType_sample` を **ProjectReference 化**（`scripts\setup-ws.ps1`）。
  `OpenTouryo.*`・`Newtonsoft.Json` は DLL 参照のままベンダ先へ張替。
- MVC net48 / WebForms も同様に WS 参照を `..\..\WS_sample\...` の ProjectReference へ変換。

**ビルド結果（すべて 0 error）**：

| 項番 | サンプル | 結果 | 特記 |
| --- | --- | --- | --- |
| 1 | MVC_Sample (net48) | OK | WS ProjectReference 化で解消 |
| 3 | WebForms_Sample (net48) | OK | 同上 |
| 8-10 | WSClientWin_sample (net48, 3回=同一) | OK | client→WSServer+WSIFType |
| 11 | WSClientWin2_sample (net48) | OK | WS 非依存の単独 P層。RichClient のみ |
| 12 | WSClientWinCone_sample (net48) | OK | client→WSIFType のみ。**ClickOnce 署名を回避**（下記） |
| 13 | WSClientWPF_sample (net48) | OK | client→WSServer+WSIFType |
| （付随） | ASPNETWebService（WS ホスト） | OK | `packages.config` を project 直下へ別途 restore |

**問題点（WS 群で実際に踏んだもの）**：

1. **`WSClientWinCone_sample` は ClickOnce 版で `MSB3482`（証明書無し）になる**。csproj の
   `<SignManifests>true>` を `false` にして回避（スキル記載通り。到達点は「ビルド可能」でありデプロイは目的外）。
2. **`ASPNETWebService`（WS ホスト）の `packages.config` は csproj 相対 `packages\` を前提**とするため、
   `nuget restore <asp>\packages.config -PackagesDirectory <asp>\packages` で project 直下へ別途復元が要る（スキル記載通り）。
3. **`WSClientWin` / `WinCone` は `Newtonsoft.Json.dll` も `Frameworks\Infrastructure\Build\` から参照**していて、
   `OpenTouryo.*` だけを張り替える初版の helper では取りこぼした → 張替対象に `Newtonsoft.Json` を追加して解消。
   （汎用教訓：WS クライアントは OpenTouryo 以外にフレームワーク Build フォルダの 3rd-party も参照しうる。）
4. **MSYS 経由で `msbuild /p:...` を叩くと引数がパス変換され壊れる**（`/nologo`→`C:/Program Files/Git/nologo`、
   `/p:` が別プロジェクト指定になり `MSB1008`）。**PowerShell から msbuild を呼ぶと正常**（スキル記載の落とし穴を実測）。

**未実施（ビルド検証まで。実行時検証は範囲外）**：
- net48 Web（MVC/WebForms）の **セッションは StateServer** 構成のまま。実行するには **ASP.NET State Service の起動**が要る
  （今回はビルド検証までなので未起動。起動するとマシン全体の変更＝`SETUP-CHANGES.md` に記録が必要）。
- WS モード（`protocol="2"`）の実動（ASPNETWebService を IIS Express で起動しクライアントから WS 越し呼び出し）は未実施。

---

## まとめ

**Plan.md の全 24 項目（重複の WSClientWin ×3 を含む）を、`03-20` タグ・完全新規リポジトリからセットアップし、
全サンプル `0 error` でビルド成功。** net48 は msbuild（VS18 Community）、net10.0 は `dotnet build`。

**遭遇した問題点（再掲・重要度順）**：
1. スキルの `examples.md` 雛形の `WebClient.DownloadFile()` が GitHub codeload に 404（TLS 既定）→ `Invoke-WebRequest`+TLS1.2 へ。
2. PowerShell スクリプトの日本語コメントが `powershell.exe`（WinPS 5.1）で構文破壊 → 症状が「DL 404」に化ける。ASCII 化で解消。
3. WS クライアントの 3rd-party（`Newtonsoft.Json`）も Build フォルダ参照 → 張替対象に追加。
4. WinCone の ClickOnce 署名 `MSB3482` → `SignManifests=false`。
5. ASPNETWebService の `packages.config` は project 直下復元が必要。
6. MSYS 経由の msbuild 引数破壊 → PowerShell から実行。

いずれも本体（OpenTouryo）の不具合ではなく、非対話セットアップ／エージェント実行に固有の落とし穴。
成果物はワーキング ツリーに残置（Git 操作はプロジェクト方針に従い未実施）。`scripts\` に再現用スクリプトを配置。
