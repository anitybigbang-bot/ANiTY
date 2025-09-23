// lib/getCatalog.ts
import { supabase } from './supabase';

export type AnimeRow = {
  id: string;
  title: string;
  kana: string | null;
  year: number | null;
  genres: string[];
  streams: any;          // {service, url}[] の JSONB
  avg_rating: number | null;
  rating_count: number;
  user_rating: number | null;
};

export async function fetchCatalog(params?: {
  keyword?: string;
  yearMin?: number;
  yearMax?: number;
  genres?: string[];
  genreMode?: 'or' | 'and';
  services?: string[];
  limit?: number;
  offset?: number;
}) {
  const {
    keyword = null,
    yearMin = null,
    yearMax = null,
    genres = null,
    genreMode = 'or',
    services = null,
    limit = 500,
    offset = 0,
  } = params ?? {};

  const { data, error } = await supabase.rpc('get_anime_with_ratings', {
    p_keyword:    keyword,
    p_year_min:   yearMin,
    p_year_max:   yearMax,
    p_genres:     genres,
    p_genre_mode: genreMode,
    p_services:   services,
    p_limit:      limit,
    p_offset:     offset,
  });

  if (error) throw error;
  return data as AnimeRow[];
}