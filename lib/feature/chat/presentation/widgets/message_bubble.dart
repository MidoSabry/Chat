import 'package:flutter/material.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final bool pending;
  final bool read;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isMe,
    this.pending = false,
    this.read = false,
  });

  @override
  Widget build(BuildContext context) {
    IconData? icon;
    if (isMe) {
      if (pending) icon = Icons.access_time;         // ⏳
      else if (read) icon = Icons.done_all;          // ✅✅
      else icon = Icons.done;                        // ✅
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isMe ? Colors.blue.shade100 : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(text)),
            if (icon != null) ...[
              const SizedBox(width: 6),
              Icon(icon, size: 14),
            ],
          ],
        ),
      ),
    );
  }
}
