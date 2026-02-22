import 'package:flutter/material.dart';
import '../theme/lumi_theme.dart';

/// Animated Lumi character with breathing animation and state-based visual effects
class LumiCharacter extends StatefulWidget {
  final String? lastSource; // 'on-device', 'cloud', or null
  final bool isLoading;

  const LumiCharacter({
    super.key,
    this.lastSource,
    this.isLoading = false,
  });

  @override
  State<LumiCharacter> createState() => _LumiCharacterState();
}

class _LumiCharacterState extends State<LumiCharacter>
    with TickerProviderStateMixin {
  late AnimationController _breathingController;
  late AnimationController _glowController;
  late Animation<double> _breathingAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // Breathing animation (3s cycle, like CSS)
    _breathingController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);

    _breathingAnimation = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    // Glow animation for on-device state
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 12, end: 28).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_breathingAnimation, _glowAnimation]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _breathingAnimation.value),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Character image with glow effects
              Container(
                decoration: BoxDecoration(
                  boxShadow: _buildShadows(),
                ),
                child: Image.asset(
                  widget.isLoading 
                      ? 'assets/images/lumi_character2.png'
                      : 'assets/images/lumi_character.png',
                  width: 220,
                  height: 280,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 220,
                      height: 280,
                      decoration: BoxDecoration(
                        color: LumiTheme.pinkLight.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.black,
                          width: 3,
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '🎮',
                            style: TextStyle(fontSize: 48),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Lumi',
                            style: TextStyle(
                              fontFamily: 'DungGeunMo',
                              fontSize: 24,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Cloud thinking bubble
              if (widget.lastSource == 'cloud' || widget.isLoading)
                Positioned(
                  top: 20,
                  right: -30,
                  child: _buildThinkingBubble(),
                ),

              // On-device electricity border effect
              if (widget.lastSource == 'on-device')
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      margin: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: LumiTheme.electricYellow
                              .withValues(alpha: 0.5 + (_glowAnimation.value / 56)),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: LumiTheme.electricYellow
                                .withValues(alpha: 0.3),
                            blurRadius: _glowAnimation.value / 2,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<BoxShadow> _buildShadows() {
    final baseShadows = [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.15),
        blurRadius: 24,
        offset: const Offset(0, 12),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.08),
        blurRadius: 8,
        offset: const Offset(0, 4),
      ),
    ];

    if (widget.lastSource == 'on-device') {
      baseShadows.addAll([
        BoxShadow(
          color: LumiTheme.electricYellow.withValues(alpha: 0.9),
          blurRadius: _glowAnimation.value,
          spreadRadius: 2,
        ),
        BoxShadow(
          color: LumiTheme.electricGold.withValues(alpha: 0.5),
          blurRadius: _glowAnimation.value * 1.5,
          spreadRadius: 1,
        ),
      ]);
    }

    return baseShadows;
  }

  Widget _buildThinkingBubble() {
    return AnimatedOpacity(
      opacity: (widget.lastSource == 'cloud' || widget.isLoading) ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.black, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  offset: Offset(4, 4),
                ),
              ],
            ),
            child: Text(
              widget.isLoading ? 'Thinking...' : 'Deep Thinking...',
              style: const TextStyle(
                fontFamily: 'DungGeunMo',
                fontSize: 12,
                color: Color(0xFF333333),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Magnifying glass icon
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  offset: Offset(2, 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
