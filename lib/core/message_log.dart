class LogMessage {
  const LogMessage(this.text, this.time);

  final String text;

  /// 메시지가 발생한 게임 시간 (aut).
  final int time;
}

class MessageLog {
  static const _maxMessages = 200;

  final List<LogMessage> _messages = [];

  void add(String text, int time) {
    _messages.add(LogMessage(text, time));
    if (_messages.length > _maxMessages) _messages.removeAt(0);
  }

  List<LogMessage> recent(int count) => _messages.length <= count
      ? List.unmodifiable(_messages)
      : List.unmodifiable(_messages.sublist(_messages.length - count));
}
