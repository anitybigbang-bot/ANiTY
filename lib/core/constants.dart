// 固定候補（UIに出すリスト）
const List<String> kFixedGenres = <String>[
  'アクション', 'ファンタジー', 'SF', '青春・恋愛', 'コメディ',
  '日常', 'ミステリー', 'ホラー', 'ロボット', 'スポーツ',
];

const List<String> kFixedServices = <String>[
  'Netflix', 'Prime Video', 'hulu', 'U-NEXT', 'dアニメストア', 'Disney+',
];

// ==== ランク判定しきい値（Gold/Silver）====
// Gold（要望に合わせて AND 条件）
const int kGoldMinCount = 150;
const int kGoldHiAvgCount = 80; // 参考値（現在は未使用）
const double kGoldHiAvg = 4.2;

// Silver（いずれかを満たす）
const int kSilverCnt1 = 60;     // 60件以上 かつ 平均3.9以上
const double kSilverAvg1 = 3.9;
const int kSilverCnt2 = 30;     // 30件以上 かつ 平均4.1以上
const double kSilverAvg2 = 4.1;