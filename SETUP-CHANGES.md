# セットアップで生じたマシン/ユーザ全体の変更

監査・巻き戻し用（AGENTS.md ポリシー）。`種別 ／ 対象 ／ 値 ／ 実施日 ／ 巻き戻し方法`。

| 種別 | 対象 | 値 | 実施日 | 巻き戻し方法 |
| --- | --- | --- | --- | --- |
| リポ外ディレクトリ | 作業ルート | `C:\otr\`（OpenTouryo 基盤ソース展開・ビルド用） | 2026-07-20 | `Remove-Item -Recurse -Force C:\otr`（DLL はリポ内 OpenTouryoAssemblies にベンダ済み） |
| 環境変数（User） | `OT_RESOURCE_ROOT` | `D:\git\local\OpenTouryoProject\OTRVCAS\resource` | 2026-07-20 | `[Environment]::SetEnvironmentVariable('OT_RESOURCE_ROOT',$null,'User')` で削除 |
