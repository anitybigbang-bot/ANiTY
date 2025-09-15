// scripts/push_catalog.ts
// JSON (デフォルト: assets/anime_list.json) を Supabase public.anime_catalog に UPSERT
// 実行: npx tsx scripts/push_catalog.ts [--dry]

import * as dotenv from 'dotenv';
dotenv.config({ path: '.env.local' }); // ← .env.local を必ず読む
if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SERVICE_ROLE) {
  dotenv.config(); // フォールバックで .env も読む
}


import { createClient } from '@supabase/supabase-js';
import fs from 'node:fs';
import path from 'node:path';

type StreamLink = { service: string; url: string };
type SourceItem = {
  id: string;
  title: string;
  kana?: string | null;
  year?: number | null;
  genres?: string[];
  streams?: StreamLink[];
  updatedAt?: string;
};
type DbRow = {
  id: string;
  title: string;
  kana: string | null;
  year: number | null;
  genres: string[];
  streams: StreamLink[];
  updated_at: string;
};

const REQUIRED_ENV = ['SUPABASE_URL', 'SUPABASE_SERVICE_ROLE'] as const;

function ensureEnv() {
  for (const k of REQUIRED_ENV) {
    if (!process.env[k]) {
      throw new Error(
        `Missing env: ${k}. .env.local に SUPABASE_URL / SUPABASE_SERVICE_ROLE を設定してください（コミット禁止）`
      );
    }
  }
}

function normalize(a: any): DbRow {
  const id = String(a.id ?? '').trim();
  const title = String(a.title ?? '').trim();
  const kana = a.kana ? String(a.kana).trim() : null;
  const year = typeof a.year === 'number' && Number.isFinite(a.year) ? a.year : null;
  const genres = Array.isArray(a.genres) ? a.genres.map(String) : [];
  const streams = Array.isArray(a.streams)
    ? a.streams.map((s: any) => ({ service: String(s.service), url: String(s.url) }))
    : [];
  const updated_at =
    typeof a.updatedAt === 'string' ? a.updatedAt : new Date().toISOString();
  if (!id || !title)
    throw new Error(`Invalid item: id/title required -> ${JSON.stringify(a)}`);
  return { id, title, kana, year, genres, streams, updated_at };
}

async function main() {
  ensureEnv();

  // 入力ファイル: デフォルトは assets/anime_list.json
  const inputPath =
    process.argv.find((a) => a.endsWith('.json')) ??
    path.join(process.cwd(), 'assets', 'anime_list.json');
  if (!fs.existsSync(inputPath))
    throw new Error(`入力ファイルが見つかりません: ${inputPath}`);

  const raw = JSON.parse(fs.readFileSync(inputPath, 'utf8')) as SourceItem[];
  if (!Array.isArray(raw)) throw new Error('JSON ルートは配列である必要があります');

  // 正規化 + 重複ID警告
  const rows: DbRow[] = [];
  const seen = new Set<string>();
  for (const a of raw) {
    const r = normalize(a);
    if (seen.has(r.id)) console.warn(`[WARN] duplicate id: ${r.id}（最後の1件を使用）`);
    seen.add(r.id);
    rows.push(r);
  }

  const isDry = process.argv.includes('--dry');
  console.log(
    `Ready to ${isDry ? 'DRY-RUN' : 'UPSERT'} ${rows.length} rows from: ${inputPath}`
  );
  if (isDry) {
    console.log(rows.slice(0, 3));
    return;
  }

  const supabase = createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE!, {
    auth: { persistSession: false },
  });

  // バッチ UPSERT
  const CHUNK = 500;
  let total = 0;
  for (let i = 0; i < rows.length; i += CHUNK) {
    const chunk = rows.slice(i, i + CHUNK);
    const { error } = await supabase
      .from('anime_catalog')
      .upsert(chunk, { onConflict: 'id', ignoreDuplicates: false });
    if (error) {
      console.error('Upsert error at chunk', i / CHUNK, error);
      process.exit(1);
    }
    total += chunk.length;
    console.log(`Upserted ${total}/${rows.length}`);
  }
  console.log('Done ✅');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});