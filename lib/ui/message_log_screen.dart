import 'package:flutter/material.dart';

import '../core/message_log.dart';
import '../core/time/energy.dart';

/// 메시지 로그 전체 화면. 최신 메시지가 맨 아래, 위로 스크롤하면 지난 메시지.
class MessageLogScreen extends StatelessWidget {
  const MessageLogScreen({super.key, required this.log});

  final MessageLog log;

  /// 보여줄 최대 메시지 수 (로그가 보관하는 만큼).
  static const _history = 200;

  static Future<void> open(BuildContext context, MessageLog log) =>
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => MessageLogScreen(log: log)));

  @override
  Widget build(BuildContext context) {
    // reverse 목록: 0번이 맨 아래(최신)라서 열면 바로 최신 메시지가 보인다.
    final messages = log.recent(_history).reversed.toList();
    final latest = messages.isEmpty ? null : messages.first.time;
    return Scaffold(
      backgroundColor: const Color(0xFF0E0C0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E0C0A),
        title: const Text('메시지 로그'),
      ),
      body: messages.isEmpty
          ? const Center(
              child: Text(
                '메시지가 없다.',
                style: TextStyle(color: Color(0xFF8A8478)),
              ),
            )
          : ListView.builder(
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: messages.length,
              itemBuilder: (context, i) {
                final m = messages[i];
                // 가장 최근 턴의 메시지는 밝게.
                final recent = m.time == latest;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 56,
                        child: Text(
                          (m.time / autPerTurn).toStringAsFixed(1),
                          style: const TextStyle(
                            color: Color(0xFF6E685E),
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          m.text,
                          style: TextStyle(
                            color: recent
                                ? const Color(0xFFF2EDE4)
                                : const Color(0xFFBDB6A8),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
