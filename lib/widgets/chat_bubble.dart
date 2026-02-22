import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../theme/lumi_theme.dart';

/// Chat message bubble widget, styled like the original 8-bit Lumi UI
class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name label
          Row(
            children: [
              Text(
                message.isLumi ? 'Lumi:' : 'You:',
                style: TextStyle(
                  fontFamily: 'DungGeunMo',
                  fontWeight: FontWeight.bold,
                  color: message.isLumi ? LumiTheme.deepPink : LumiTheme.babyBlue,
                  fontSize: 14,
                ),
              ),
              // Source indicator
              if (message.source != null) ...[
                const SizedBox(width: 8),
                _buildSourceBadge(),
              ],
            ],
          ),
          const SizedBox(height: 4),
          // Message body
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: message.isLumi
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFE4EC), LumiTheme.pinkPale],
                    )
                  : null,
              color: message.isLumi ? null : LumiTheme.skyBlue,
              border: Border.all(
                color: message.isLumi ? LumiTheme.pink : LumiTheme.babyBlue,
                width: 2,
              ),
            ),
            child: Text(
              message.text,
              style: const TextStyle(
                fontFamily: 'DungGeunMo',
                fontSize: 14,
                color: LumiTheme.textDark,
                height: 1.5,
              ),
            ),
          ),
          // Latency info
          if (message.latencyMs != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${(message.latencyMs! / 1000).toStringAsFixed(1)}s',
                style: TextStyle(
                  fontFamily: 'DungGeunMo',
                  fontSize: 10,
                  color: LumiTheme.textLight,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSourceBadge() {
    Color bgColor;
    String label;
    IconData icon;

    if (message.isOnDevice) {
      bgColor = LumiTheme.electricYellow;
      label = 'ON-DEVICE';
      icon = Icons.bolt;
    } else if (message.isCloud) {
      bgColor = LumiTheme.cloudBlue;
      label = 'CLOUD';
      icon = Icons.cloud;
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.3),
        border: Border.all(color: bgColor, width: 1.5),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.black87),
          const SizedBox(width: 2),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'DungGeunMo',
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
