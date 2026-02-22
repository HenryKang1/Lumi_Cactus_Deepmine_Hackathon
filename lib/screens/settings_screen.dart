import 'package:flutter/material.dart';
import '../services/cactus_service.dart';
import '../theme/lumi_theme.dart';

class SettingsScreen extends StatefulWidget {
  final CactusService cactusService;
  final VoidCallback? onSaved;

  const SettingsScreen({
    super.key,
    required this.cactusService,
    this.onSaved,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _apiKeyController;
  late double _confidenceThreshold;
  
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = '';

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(
      text: widget.cactusService.geminiApiKey ?? '',
    );
    _confidenceThreshold = widget.cactusService.confidenceThreshold;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _startDownload() async {

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadStatus = 'Starting...';
    });

    try {
      await widget.cactusService.downloadModelsFromUrl(
        '', // URL is now handled internally by the service
        onProgress: (progress) {
          setState(() {
            _downloadProgress = progress;
          });
        },
        onStatus: (status) {
          setState(() {
            _downloadStatus = status;
          });
        },
      );
      
      if (mounted) {
         setState(() {
           _isDownloading = false;
         });
         // Notify parent (ChatScreen) that models are now available
         widget.onSaved?.call();
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Models successfully installed!')),
         );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download Error: $e')),
        );
      }
    }
  }

  void _save() {
    widget.cactusService.geminiApiKey = _apiKeyController.text.trim().isEmpty
        ? null
        : _apiKeyController.text.trim();
    widget.cactusService.confidenceThreshold = _confidenceThreshold;
    widget.onSaved?.call();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: const BoxDecoration(
                      color: LumiTheme.pink,
                      border: Border(
                        bottom: BorderSide(color: Colors.black, width: 3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Settings.exe',
                            style: TextStyle(
                              fontFamily: 'DungGeunMo',
                              fontSize: 14,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 24,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: LumiTheme.pinkLight,
                              border: Border.all(
                                color: Colors.black,
                                width: 2,
                              ),
                            ),
                            child: const Text(
                              '×',
                              style: TextStyle(
                                fontFamily: 'DungGeunMo',
                                fontSize: 14,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Settings content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Model Status section
                          _buildSectionTitle('🤖 Model Status'),
                          const SizedBox(height: 8),
                          _buildStatusRow(
                            'LiquidAI/LFM2-350M',
                            'completion, tools, embed',
                            widget.cactusService.hasLfm2,
                          ),
                          const SizedBox(height: 4),
                          _buildStatusRow(
                            'google/functiongemma-270m-it',
                            'completion, tools',
                            widget.cactusService.hasGemma,
                          ),
                          if (widget.cactusService.initError != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3CD),
                                border: Border.all(
                                  color: const Color(0xFFFFD93D),
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                widget.cactusService.initError!,
                                style: const TextStyle(
                                  fontFamily: 'DungGeunMo',
                                  fontSize: 11,
                                  color: Color(0xFF856404),
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Download Models
                          _buildSectionTitle('📥 Download Local Models'),
                          const SizedBox(height: 8),
                          const Text(
                            'Source: Cactus-Compute (Hugging Face)',
                            style: TextStyle(
                              fontFamily: 'DungGeunMo',
                              fontSize: 11,
                              color: LumiTheme.textLight,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (widget.cactusService.hasModels && !_isDownloading) ...[
                             Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: LumiTheme.mint.withValues(alpha: 0.2),
                                border: Border.all(color: LumiTheme.mint, width: 2),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Models downloaded and ready! 🎉',
                                      style: TextStyle(
                                        fontFamily: 'DungGeunMo',
                                        fontSize: 11,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (_isDownloading) ...[
                            Text(
                              _downloadStatus,
                              style: const TextStyle(
                                fontFamily: 'DungGeunMo',
                                fontSize: 11,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: _downloadProgress,
                              color: LumiTheme.mint,
                              backgroundColor: LumiTheme.cream,
                            ),
                          ] else ...[
                            GestureDetector(
                                onTap: _startDownload,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: LumiTheme.electricYellow,
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 2,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x26000000),
                                        offset: Offset(2, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    'Download Models from Hugging Face',
                                    style: TextStyle(
                                      fontFamily: 'DungGeunMo',
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                          ],

                          const SizedBox(height: 24),

                          // Cloud Fallback
                          _buildSectionTitle('☁️ Gemini Cloud Fallback'),
                          const SizedBox(height: 8),
                          const Text(
                            'API Key (for cloud handoff):',
                            style: TextStyle(
                              fontFamily: 'DungGeunMo',
                              fontSize: 12,
                              color: LumiTheme.textDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: Colors.black,
                                width: 3,
                              ),
                            ),
                            child: TextField(
                              controller: _apiKeyController,
                              obscureText: true,
                              style: const TextStyle(
                                fontFamily: 'DungGeunMo',
                                fontSize: 13,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Enter Gemini API Key...',
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
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Confidence Threshold
                          _buildSectionTitle('⚡ Hybrid Routing'),
                          const SizedBox(height: 8),
                          // Prefer Local toggle
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: widget.cactusService.preferLocal
                                  ? LumiTheme.mint.withValues(alpha: 0.2)
                                  : LumiTheme.skyBlue,
                              border: Border.all(
                                color: widget.cactusService.preferLocal
                                    ? LumiTheme.mint
                                    : LumiTheme.babyBlue,
                                width: 2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Always Use Local Model',
                                        style: TextStyle(
                                          fontFamily: 'DungGeunMo',
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                      Text(
                                        'Never auto-handoff to cloud',
                                        style: TextStyle(
                                          fontFamily: 'DungGeunMo',
                                          fontSize: 9,
                                          color: LumiTheme.textLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: widget.cactusService.preferLocal,
                                  activeColor: LumiTheme.mint,
                                  onChanged: (value) {
                                    setState(() {
                                      widget.cactusService.preferLocal = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Confidence threshold (only applies when preferLocal is off)
                          if (!widget.cactusService.preferLocal) ...[
                            Text(
                              'Confidence Threshold: ${_confidenceThreshold.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontFamily: 'DungGeunMo',
                                fontSize: 12,
                                color: LumiTheme.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Below this → cloud handoff',
                              style: TextStyle(
                                fontFamily: 'DungGeunMo',
                                fontSize: 10,
                                color: LumiTheme.textLight,
                              ),
                            ),
                            Slider(
                              value: _confidenceThreshold,
                              min: 0.0,
                              max: 1.0,
                              divisions: 20,
                              activeColor: LumiTheme.electricYellow,
                              inactiveColor: LumiTheme.pinkLight,
                              onChanged: (value) {
                                setState(() {
                                  _confidenceThreshold = value;
                                });
                              },
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Text(
                                  'More Cloud',
                                  style: TextStyle(
                                    fontFamily: 'DungGeunMo',
                                    fontSize: 10,
                                    color: LumiTheme.cloudBlue,
                                  ),
                                ),
                                Text(
                                  'More On-Device',
                                  style: TextStyle(
                                    fontFamily: 'DungGeunMo',
                                    fontSize: 10,
                                    color: Color(0xFFFFC832),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Info
                          _buildSectionTitle('ℹ️ About'),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: LumiTheme.skyBlue,
                              border: Border.all(
                                color: LumiTheme.babyBlue,
                                width: 2,
                              ),
                            ),
                            child: const Text(
                              'Lumi uses Cactus Engine for on-device AI:\n\n'
                              '• LFM2-350M: General chat + embeddings\n'
                              '• FunctionGemma-270m: Tool calling\n'
                              '• Gemini Flash: Cloud fallback\n\n'
                              'Models run locally on your phone\'s ARM processor — '
                              'no data leaves your device unless cloud handoff is triggered!',
                              style: TextStyle(
                                fontFamily: 'DungGeunMo',
                                fontSize: 11,
                                color: LumiTheme.textDark,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Save button
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF5F5F5),
                      border: Border(
                        top: BorderSide(color: Color(0xFFDDDDDD), width: 2),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: _save,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: LumiTheme.mint,
                            border: Border.all(
                              color: Colors.black,
                              width: 3,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x26000000),
                                offset: Offset(3, 3),
                              ),
                            ],
                          ),
                          child: const Text(
                            'SAVE',
                            style: TextStyle(
                              fontFamily: 'DungGeunMo',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'DungGeunMo',
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    );
  }

  Widget _buildStatusRow(String modelName, String features, bool available) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: available
            ? LumiTheme.mint.withValues(alpha: 0.2)
            : const Color(0xFFF8D7DA),
        border: Border.all(
          color: available ? LumiTheme.mint : const Color(0xFFF5C6CB),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            available ? Icons.check_circle : Icons.error_outline,
            size: 14,
            color: available ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  modelName,
                  style: const TextStyle(
                    fontFamily: 'DungGeunMo',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  features,
                  style: const TextStyle(
                    fontFamily: 'DungGeunMo',
                    fontSize: 9,
                    color: LumiTheme.textLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
