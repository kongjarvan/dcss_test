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
