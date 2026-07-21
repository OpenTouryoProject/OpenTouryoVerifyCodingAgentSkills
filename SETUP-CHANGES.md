# セットアップで生じたマシン/ユーザ全体の変更

監査・巻き戻し用（AGENTS.md ポリシー）。`種別 ／ 対象 ／ 値 ／ 実施日 ／ 巻き戻し方法`。

| 種別 | 対象 | 値 | 実施日 | 巻き戻し方法 |
| --- | --- | --- | --- | --- |
| リポ外ディレクトリ | 作業ルート | `C:\otr\`（OpenTouryo 基盤ソース展開・ビルド用） | 2026-07-20 | `Remove-Item -Recurse -Force C:\otr`（DLL はリポ内 OpenTouryoAssemblies にベンダ済み） |
| 環境変数（User） | `OT_RESOURCE_ROOT` | `D:\git\local\OpenTouryoProject\OTRVCAS\resource` | 2026-07-20 | `[Environment]::SetEnvironmentVariable('OT_RESOURCE_ROOT',$null,'User')` で削除 |
| リポ外ディレクトリ | LocalServicesOnDocker クローン | `D:\git\local\DNDIWGOSSC\LocalServicesOnDocker`（ローカル DB スタック定義） | 2026-07-21 | `Remove-Item -Recurse -Force D:\git\local\DNDIWGOSSC\LocalServicesOnDocker` |
| Docker ネットワーク | `common_link` | bridge（LocalServicesOnDocker が使用。既存だったため再利用） | 2026-07-21 | `docker network rm common_link`（他コンテナが未使用のとき） |
| Docker コンテナ群 | LocalServicesOnDocker（sqlserver 1433 / mysql 3306 / postgres 5432 / redis 6379 / mongo 27017、既定資格 seigi@123） | 起動（`Start-Services.ps1`） | 2026-07-21 | `D:\git\local\DNDIWGOSSC\LocalServicesOnDocker\Stop-Services.ps1`（＝`docker compose down`）。sqlserver は永続ボリューム未使用のため停止でデータ消去 |
