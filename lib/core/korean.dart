/// 한국어 조사 처리 도우미.
bool _hasBatchim(String word) {
  if (word.isEmpty) return false;
  final code = word.codeUnitAt(word.length - 1);
  if (code < 0xAC00 || code > 0xD7A3) return false;
  return (code - 0xAC00) % 28 != 0;
}

/// 을/를
String eulReul(String word) => '$word${_hasBatchim(word) ? '을' : '를'}';

/// 이/가
String iGa(String word) => '$word${_hasBatchim(word) ? '이' : '가'}';

/// 은/는
String eunNeun(String word) => '$word${_hasBatchim(word) ? '은' : '는'}';

/// 숫자 + 이/가. 읽는 소리 기준: 2 → "2가", 3 → "3이".
String numberIGa(int n) {
  // 끝자리가 0이면 영/십/백/천/만 → 모두 받침 있음.
  const batchimDigits = {0, 1, 3, 6, 7, 8};
  return '$n${batchimDigits.contains(n.abs() % 10) ? '이' : '가'}';
}

/// 으로/로. 받침이 없거나 ㄹ 받침이면 "로".
String euroRo(String word) {
  if (word.isEmpty) return word;
  final code = word.codeUnitAt(word.length - 1);
  if (code < 0xAC00 || code > 0xD7A3) return '$word로';
  final jong = (code - 0xAC00) % 28;
  return '$word${jong == 0 || jong == 8 ? '로' : '으로'}';
}
