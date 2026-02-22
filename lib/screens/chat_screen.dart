import 'package:flutter/material.dart';

import '../models/chat_message.dart';
import '../services/cactus_service.dart';
import '../theme/lumi_theme.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/lumi_character.dart';
import '../widgets/lumi_title_bar.dart';
import 'settings_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final CactusService _cactusService = CactusService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isMinimized = false;
  String? _lastSource;
  double? _lastLatencyMs;

  // Animation controllers
  late AnimationController _windowAnimController;

  @override
  void initState() {
    super.initState();

    // Window minimize/restore animation
    _windowAnimController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    // Initial greeting
    _messages = [
      ChatMessage(
        role: 'lumi',
        text: "So I may or may not have spilled boba on my 60HE... 🫠 Don't @ me rn I'm having a moment. (JK, come play with me)",
      ),
    ];

    // Initialize Cactus with stored API key
    _initializeCactus();
  }

  Future<void> _initializeCactus() async {
    // TODO: Load API key from secure storage
    await _cactusService.initialize();

    if (_cactusService.initError != null && mounted) {
      // Show info but don't block — will use mock mode
      debugPrint('Cactus init note: ${_cactusService.initError}');
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _windowAnimController.dispose();
    _cactusService.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  int _mockToggle = 0;

  Future<void> _handleSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isLoading) return;

    final requestStart = DateTime.now();

    setState(() {
      _isLoading = true;
      _messages.add(ChatMessage(role: 'user', text: text));
      _textController.clear();
    });
    _scrollToBottom();

    // Check if Cactus models are loaded or cloud API is configured
    if (_cactusService.hasModels || _cactusService.geminiApiKey != null) {
      try {
        // Determine if this looks like a tool-call request
        final isToolRequest = _isToolCallCandidate(text);

        final result = await _cactusService.generate(
          text,
          preferToolModel: isToolRequest,
          tools: isToolRequest ? _getDefaultTools() : null,
        );

        String responseText = result.text;

        // If there are function calls, format them nicely
        if (result.functionCalls != null && result.functionCalls!.isNotEmpty) {
          final calls = result.functionCalls!
              .map((fc) => '🔧 ${fc['name']}(${fc['arguments']})')
              .join('\n');
          responseText = '$responseText\n\n$calls';
        }

        setState(() {
          _lastSource = result.source;
          _lastLatencyMs = result.latencyMs;
          _messages.add(ChatMessage(
            role: 'lumi',
            text: responseText,
            source: result.source,
            latencyMs: result.latencyMs,
            confidence: result.confidence,
          ));
          _isLoading = false;
        });
      } catch (e) {
        // Fallback to mock if anything goes wrong
        debugPrint('Generate error: $e');
        await _mockResponse(requestStart);
      }
    } else {
      // No models and no API key — guide user to settings
      setState(() {
        _lastSource = 'none';
        _lastLatencyMs = 0;
        _messages.add(ChatMessage(
          role: 'lumi',
          text: 'I need my brain installed first! 🧠💾\n\n'
              'Go to ⚙️ Settings → Download Models to get me running locally!\n'
              'Or set a Gemini API key for cloud mode.',
          source: 'system',
        ));
        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  Future<void> _mockResponse(DateTime requestStart) async {
    // Mock: alternate on-device (fast) / cloud (slower) for demo
    _mockToggle += 1;
    final useLocal = _mockToggle % 2 == 1;
    final delay = useLocal ? 80 : 600;
    await Future.delayed(Duration(milliseconds: delay));

    final elapsed = DateTime.now().difference(requestStart).inMilliseconds.toDouble();

    setState(() {
      _lastSource = useLocal ? 'on-device' : 'cloud';
      _lastLatencyMs = elapsed;
      _messages.add(ChatMessage(
        role: 'lumi',
        text: useLocal
            ? 'Local reply! ⚡ Running on-device with Cactus engine~'
            : 'Deep cloud answer here. 🌙 Powered by Gemini Flash!',
        source: useLocal ? 'on-device' : 'cloud',
        latencyMs: elapsed,
        confidence: useLocal ? 0.85 : 1.0,
      ));
      _isLoading = false;
    });
  }

  /// Simple heuristic to detect tool-call candidates
  bool _isToolCallCandidate(String text) {
    final lower = text.toLowerCase();
    final toolKeywords = [
      'set alarm', 'set timer', 'reminder', 'schedule',
      'call', 'send', 'open', 'play', 'search',
      'turn on', 'turn off', 'brightness', 'volume',
      'weather', 'calculate', 'convert',
    ];
    return toolKeywords.any((kw) => lower.contains(kw));
  }

  /// Default tool definitions for the hackathon demo
  List<Map<String, dynamic>> _getDefaultTools() {
    return [
      {
        'type': 'function',
        'function': {
          'name': 'set_alarm',
          'description': 'Set an alarm for a specific time',
          'parameters': {
            'type': 'object',
            'properties': {
              'hour': {'type': 'string', 'description': 'Hour (0-23)'},
              'minute': {'type': 'string', 'description': 'Minute (0-59)'},
              'label': {'type': 'string', 'description': 'Alarm label'},
            },
            'required': ['hour', 'minute'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'set_timer',
          'description': 'Set a countdown timer',
          'parameters': {
            'type': 'object',
            'properties': {
              'duration_minutes': {'type': 'string', 'description': 'Duration in minutes'},
              'label': {'type': 'string', 'description': 'Timer label'},
            },
            'required': ['duration_minutes'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'send_message',
          'description': 'Send a message to a contact',
          'parameters': {
            'type': 'object',
            'properties': {
              'contact': {'type': 'string', 'description': 'Contact name'},
              'message': {'type': 'string', 'description': 'Message text'},
            },
            'required': ['contact', 'message'],
          },
        },
      },
      {
        'type': 'function',
        'function': {
          'name': 'search_web',
          'description': 'Search the web for information',
          'parameters': {
            'type': 'object',
            'properties': {
              'query': {'type': 'string', 'description': 'Search query'},
            },
            'required': ['query'],
          },
        },
      },
    ];
  }

  void _toggleMinimize() {
    setState(() {
      _isMinimized = !_isMinimized;
    });
    if (_isMinimized) {
      _windowAnimController.forward();
    } else {
      _windowAnimController.reverse();
    }
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsScreen(
          cactusService: _cactusService,
          onSaved: () {
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              LumiTheme.mistyRose,
              Color(0xFFE0F4FF),
              LumiTheme.pinkPale,
            ],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Background character layer
              Positioned(
                top: 30,
                left: 0,
                right: 0,
                child: Center(
                  child: Opacity(
                    opacity: _isMinimized ? 1.0 : 0.15,
                    child: LumiCharacter(
                      lastSource: _lastSource,
                      isLoading: _isLoading,
                    ),
                  ),
                ),
              ),

              // Main chat window
              AnimatedOpacity(
                opacity: _isMinimized ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 250),
                child: AnimatedSlide(
                  offset: _isMinimized ? const Offset(0, 0.05) : Offset.zero,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  child: IgnorePointer(
                    ignoring: _isMinimized,
                    child: _buildChatWindow(),
                  ),
                ),
              ),

              // Taskbar icon when minimized
              if (_isMinimized)
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _buildTaskbarIcon(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatWindow() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A000000),
              offset: Offset(8, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            // Title bar
            LumiTitleBar(
              lastSource: _lastSource,
              lastLatencyMs: _lastLatencyMs,
              onMinimize: _toggleMinimize,
              onSettings: _openSettings,
            ),

            // Chat body
            Expanded(
              child: Container(
                color: LumiTheme.cream,
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length) {
                      // Loading indicator
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Text(
                              'Lumi:',
                              style: TextStyle(
                                fontFamily: 'DungGeunMo',
                                fontWeight: FontWeight.bold,
                                color: LumiTheme.deepPink,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildTypingIndicator(),
                          ],
                        ),
                      );
                    }
                    return ChatBubble(message: _messages[index]);
                  },
                ),
              ),
            ),

            // Input area
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFFF5F5F5),
        border: Border(
          top: BorderSide(color: Color(0xFFDDDDDD), width: 2),
        ),
      ),
      child: Row(
        children: [
          // Text input
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 3),
              ),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                enabled: !_isLoading,
                style: const TextStyle(
                  fontFamily: 'DungGeunMo',
                  fontSize: 14,
                ),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(
                    fontFamily: 'DungGeunMo',
                    color: LumiTheme.textLight,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: InputBorder.none,
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSend(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button
          GestureDetector(
            onTap: _isLoading ? null : _handleSend,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: _isLoading ? LumiTheme.textLight : LumiTheme.mint,
                border: Border.all(color: Colors.black, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    offset: Offset(3, 3),
                  ),
                ],
              ),
              child: Text(
                _isLoading ? '...' : 'SEND',
                style: const TextStyle(
                  fontFamily: 'DungGeunMo',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: 3),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFE4EC), LumiTheme.pinkPale],
            ),
            border: Border.all(color: LumiTheme.pink, width: 2),
          ),
          child: const Text(
            '● ● ●',
            style: TextStyle(
              fontFamily: 'DungGeunMo',
              fontSize: 14,
              color: LumiTheme.deepPink,
              letterSpacing: 2,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTaskbarIcon() {
    return GestureDetector(
      onTap: _toggleMinimize,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: LumiTheme.pinkLight,
          border: Border.all(color: Colors.black, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              offset: Offset(4, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              child: Image.asset(
                'assets/images/lumi_character.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 36,
                  height: 36,
                  color: LumiTheme.pinkLight,
                  child: const Center(child: Text('🎮')),
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Lumi',
              style: TextStyle(
                fontFamily: 'DungGeunMo',
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
