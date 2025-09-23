// lib/ratings.ts
import { supabase } from './supabase';

/** rating: 1..5、nullで削除 */
export async function upsertRating(animeId: string, rating: number | null) {
  const { error } = await supabase.rpc('upsert_rating', {
    p_anime_id: animeId,
    p_rating: rating
  });
  if (error) throw error;
}
