import 'package:flutter/material.dart';
import '../theme/lumi_theme.dart';

/// Retro-styled title bar mimicking the original Windows 98-style Lumi.exe bar
class LumiTitleBar extends StatelessWidget {
  final String? lastSource;
  final double? lastLatencyMs;
  final VoidCallback? onMinimize;
  final VoidCallback? onSettings;

  const LumiTitleBar({
    super.key,
    this.lastSource,
    this.lastLatencyMs,
    this.onMinimize,
    this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: LumiTheme.pink,
        border: Border(
          bottom: BorderSide(color: Colors.black, width: 3),
        ),
      ),
      child: Row(
        children: [
          // Left: title + latency
          Expanded(
            child: Row(
              children: [
                const Text(
                  'Lumi.exe - Online',
                  style: TextStyle(
                    fontFamily: 'DungGeunMo',
                    fontSize: 14,
                    color: Colors.black,
                  ),
                ),
                if (lastLatencyMs != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    lastSource == 'on-device'
                        ? 'Local: ${(lastLatencyMs! / 1000).toStringAsFixed(1)}s'
                        : 'Cloud: ${(lastLatencyMs! / 1000).toStringAsFixed(1)}s',
                    style: const TextStyle(
                      fontFamily: 'DungGeunMo',
                      fontSize: 11,
                      color: LumiTheme.textDark,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Right: control buttons
          Row(
            children: [
              if (onSettings != null)
                _ControlButton(
                  label: '⚙',
                  onTap: onSettings,
                ),
              const SizedBox(width: 6),
              _ControlButton(
                label: '_',
                onTap: onMinimize,
              ),
              const SizedBox(width: 6),
              const _ControlButton(label: '□'),
              const SizedBox(width: 6),
              const _ControlButton(label: '×'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _ControlButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: LumiTheme.pinkLight,
          border: Border.all(color: Colors.black, width: 2),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'DungGeunMo',
            fontSize: 14,
            height: 1,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}
