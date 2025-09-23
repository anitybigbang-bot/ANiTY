// 日本語/英数の簡易ノーマライズ：
// - 前後空白除去
// - 全角→半角（英数・スペース）
// - 大文字→小文字
// - カタカナ→ひらがな
String normalizeJP(String? input) {
  if (input == null) return '';
  String s = input.trim();

  // 全角→半角（英数・スペースのみ簡易対応）
  final buf = StringBuffer();
  for (final r in s.runes) {
    int c = r;
    // 全角英数(！〜～ などは除外)の一部と全角スペース
    if (c == 0x3000) {
      c = 0x20; // 全角スペース→半角
    } else if (c >= 0xFF01 && c <= 0xFF5E) {
      c = c - 0xFEE0; // 全角英数記号→半角
    }
    // カタカナ→ひらがな
    if (c >= 0x30A1 && c <= 0x30F6) {
      c = c - 0x60;
    }
    buf.writeCharCode(c);
  }
  s = buf.toString().toLowerCase();
  return s;
}