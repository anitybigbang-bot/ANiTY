
# Anity パッチノート（2025-09-08）

追加・変更点の概要:
- 作品一覧に「クイック評価」用の星（★1〜★5）を配置。作品詳細を開かずに評価可能。
- 評価は Supabase RPC `upsert_rating` を呼び出して保存。平均/件数は `rating_aggregates` から取得して即時反映。
- フィルタUIをテキスト中心に簡素化（ジャンル、配信サービス、星しきい値、検索）。
- 星フィルタ（平均★N以上）を追加。
- フィルタ履歴の保存・適用・名前変更・削除機能（`SharedPreferences`）。
- 視聴数ベースのレベル（beginner/intermediate/pro）別ランキングページを実装。Supabase RPC `get_rankings` を使用。
- 各作品の配信サービスはチップ化。タップで外部ブラウザに遷移（`url_launcher`）。
- モデル `Anime.listFromJson()` を実装し、過去の `undefined_method listFromJson` エラーに対応。

設定/注意:
- `SupabaseService` の URL/anon key は `--dart-define` で注入してください。
  ```bash
  flutter run -d chrome \\
    --dart-define=SUPABASE_URL=YOUR_URL \\
    --dart-define=SUPABASE_ANON_KEY=YOUR_ANON
  ```
- `assets/data/anime.json` を `pubspec.yaml` の `assets:` に登録しておき、作品データを供給してください。
- SQLは依頼文のとおり。`rating_aggregates`, `segment_rating_aggregates`, `get_rankings` などが前提です。

既存コードへの統合ヒント:
- 既存の `anime_list_page.dart` をこのパッチに置き換えると、検索が消えた問題にも対応します（検索ボックス復活）。
- 既存の `Anime` モデルに `listFromJson` を追加済み。
- 既存のルーティングに `RankingsPage` への導線を追加するか、本パッチの `main.dart` を参考にしてください。
