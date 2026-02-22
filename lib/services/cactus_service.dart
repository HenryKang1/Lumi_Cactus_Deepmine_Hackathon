import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';
import '../cactus.dart';

/// Manages two on-device Cactus models (LFM2-350M + FunctionGemma-270m)
/// with hybrid routing and Gemini cloud handoff.
class CactusService {
  Cactus? _lfm2Model;       // LiquidAI/LFM2-350M — completion, tools, embed
  Cactus? _gemmaModel;      // google/functiongemma-270m-it — completion, tools
  bool _isInitialized = false;
  String? _initError;
  bool _hasLfm2 = false;
  bool _hasGemma = false;

  // Cloud fallback configuration
  String? geminiApiKey;
  static const String _geminiEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  // Cactus-Compute HuggingFace download URLs
  static const String _lfm2RepoUrl =
      'https://huggingface.co/Cactus-Compute/LFM2-350M/resolve/main/weights/lfm2-350m-int8.zip';
  static const String _gemmaRepoUrl =
      'https://huggingface.co/Cactus-Compute/FunctionGemma-270M-IT/resolve/main/weights/functiongemma-270m-it-int8.zip';

  // Routing thresholds
  double confidenceThreshold = 0.0; // Default 0.0 = always use local when available
  bool preferLocal = true; // When true, never auto-handoff to cloud

  bool get isInitialized => _isInitialized;
  String? get initError => _initError;

  /// Whether at least one model is actually loaded and ready
  bool get hasModels => _hasLfm2 || _hasGemma;
  bool get hasLfm2 => _hasLfm2;
  bool get hasGemma => _hasGemma;

  /// Check if model directory contains a valid config.txt
  Future<bool> _isValidModelDir(String path) async {
    final configFile = File('$path/config.txt');
    return await configFile.exists();
  }

  /// Initialize both on-device models.
  /// Models must have config.txt + weight files in the app documents directory.
  Future<void> initialize({String? apiKey}) async {
    geminiApiKey = apiKey;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final lfm2Path = '${dir.path}/weights/lfm2-350m';
      final gemmaPath = '${dir.path}/weights/functiongemma-270m-it';

      // Check if model directories contain valid weights (config.txt)
      final lfm2Valid = await _isValidModelDir(lfm2Path);
      final gemmaValid = await _isValidModelDir(gemmaPath);

      _hasLfm2 = false;
      _hasGemma = false;

      if (lfm2Valid) {
        try {
          print('CactusService: Loading LFM2 model from $lfm2Path');
          _lfm2Model = Cactus.create(lfm2Path);
          _hasLfm2 = true;
          print('CactusService: LFM2 loaded successfully');
        } catch (e) {
          print('CactusService: Failed to load LFM2 model: $e');
        }
      } else {
        print('CactusService: LFM2 config.txt not found at $lfm2Path/config.txt');
      }

      if (gemmaValid) {
        try {
          print('CactusService: Loading FunctionGemma model from $gemmaPath');
          _gemmaModel = Cactus.create(gemmaPath);
          _hasGemma = true;
          print('CactusService: FunctionGemma loaded successfully');
        } catch (e) {
          print('CactusService: Failed to load FunctionGemma model: $e');
        }
      } else {
        print('CactusService: FunctionGemma config.txt not found at $gemmaPath/config.txt');
      }

      _isInitialized = true;

      if (!_hasLfm2 && !_hasGemma) {
        _initError = 'No model weights found. Models expected at:\n'
            '  • $lfm2Path\n'
            '  • $gemmaPath\n\n'
            'Tap "Download Models from Hugging Face" to install them automatically.';
      } else {
        _initError = null;
      }
    } catch (e) {
      _initError = 'Model initialization error: $e';
      _isInitialized = true; // Still allow cloud-only mode
    }
  }

  /// Follow redirects and return the final streamed response
  Future<http.StreamedResponse> _followRedirects(String url, {int maxRedirects = 5}) async {
    var currentUrl = url;
    for (int i = 0; i < maxRedirects; i++) {
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(currentUrl));
      request.followRedirects = false; // Handle redirects manually
      
      final response = await client.send(request);
      
      if (response.statusCode == 301 || 
          response.statusCode == 302 || 
          response.statusCode == 307 || 
          response.statusCode == 308) {
        final location = response.headers['location'];
        if (location == null) {
          throw Exception('Redirect without Location header');
        }
        // Handle relative redirects
        if (location.startsWith('http')) {
          currentUrl = location;
        } else {
          final uri = Uri.parse(currentUrl);
          currentUrl = uri.resolve(location).toString();
        }
        // Drain the redirect response body
        await response.stream.drain();
        client.close();
        continue;
      }
      
      return response;
    }
    throw Exception('Too many redirects');
  }

  /// Downloads a single model ZIP from Hugging Face and extracts to weights dir.
  /// Streams to a temp file to avoid OOM on large models (300+ MB).
  Future<void> _downloadAndExtractModel(
    String zipUrl,
    String modelDirName, {
    required Function(double progress) onProgress,
    required Function(String status) onStatus,
    int maxRetries = 3,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final weightsDir = Directory('${dir.path}/weights');
    if (!await weightsDir.exists()) {
      await weightsDir.create(recursive: true);
    }
    final tempZipPath = '${dir.path}/weights/_temp_$modelDirName.zip';
    final tempFile = File(tempZipPath);
    
    try {
      // Retry loop for download
      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          onStatus('Downloading $modelDirName (attempt $attempt/$maxRetries)...');
          
          // Follow HuggingFace redirects to CDN
          final response = await _followRedirects(zipUrl);
          
          if (response.statusCode != 200) {
            throw Exception('HTTP ${response.statusCode}');
          }
          
          final totalBytes = response.contentLength ?? 0;
          int receivedBytes = 0;
          
          // Stream directly to file — avoids holding 300MB+ in memory
          final sink = tempFile.openWrite();
          try {
            await for (final chunk in response.stream) {
              sink.add(chunk);
              receivedBytes += chunk.length;
              if (totalBytes > 0) {
                final progress = receivedBytes / totalBytes;
                final sizeMB = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
                final totalMB = (totalBytes / (1024 * 1024)).toStringAsFixed(0);
                onStatus('Downloading $modelDirName: $sizeMB / $totalMB MB');
                onProgress(progress);
              } else {
                final sizeMB = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
                onStatus('Downloading $modelDirName: $sizeMB MB');
              }
            }
          } finally {
            await sink.flush();
            await sink.close();
          }
          
          // Verify download completed
          final downloadedSize = await tempFile.length();
          if (totalBytes > 0 && downloadedSize < totalBytes) {
            throw Exception(
              'Incomplete download: got ${downloadedSize ~/ (1024*1024)}MB '
              'of ${totalBytes ~/ (1024*1024)}MB'
            );
          }
          
          // Download succeeded — break retry loop
          break;
          
        } catch (e) {
          if (attempt == maxRetries) {
            rethrow; // Final attempt failed
          }
          final waitSec = attempt * 2;
          onStatus('Download failed, retrying in ${waitSec}s... ($e)');
          await Future.delayed(Duration(seconds: waitSec));
          // Clean up partial download
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        }
      }
      
      // Extract from the downloaded temp file
      onStatus('Extracting $modelDirName...');
      onProgress(0.0);
      
      final zipBytes = await tempFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(zipBytes);
      
      int totalFiles = archive.length;
      int extracted = 0;
      
      for (final file in archive) {
        var filename = file.name;
        // Strip leading ./ prefix that zip creates
        if (filename.startsWith('./')) {
          filename = filename.substring(2);
        }
        // Skip directory entries and empty names
        if (filename.isEmpty || filename.endsWith('/')) {
          extracted++;
          onProgress(extracted / totalFiles);
          continue;
        }
        if (file.isFile) {
          final data = file.content as List<int>;
          final filePath = '${dir.path}/weights/$modelDirName/$filename';
          final outFile = File(filePath);
          outFile.createSync(recursive: true);
          outFile.writeAsBytesSync(data);
          print('CactusService: Extracted $filename (${data.length} bytes)');
        }
        extracted++;
        onProgress(extracted / totalFiles);
      }
      
    } finally {
      // Always clean up temp file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  /// Downloads both models from Cactus-Compute Hugging Face repos
  Future<void> downloadModelsFromUrl(
    String zipUrl, {
    required Function(double progress) onProgress,
    required Function(String status) onStatus,
  }) async {
    try {
      // Download LFM2-350M
      onStatus('📥 Downloading LFM2-350M (1/2)...');
      await _downloadAndExtractModel(
        _lfm2RepoUrl,
        'lfm2-350m',
        onProgress: (p) => onProgress(p * 0.45), // 0-45%
        onStatus: onStatus,
      );

      // Download FunctionGemma-270M
      onStatus('📥 Downloading FunctionGemma-270M (2/2)...');
      await _downloadAndExtractModel(
        _gemmaRepoUrl,
        'functiongemma-270m-it',
        onProgress: (p) => onProgress(0.45 + p * 0.45), // 45-90%
        onStatus: onStatus,
      );

      onStatus('✅ Extraction complete! Initializing models...');
      onProgress(0.95);

      // Re-initialize with downloaded models
      await initialize(apiKey: geminiApiKey);
      onProgress(1.0);

      print('CactusService: After download - hasLfm2=$_hasLfm2, hasGemma=$_hasGemma');

      if (!hasModels) {
        // List what files we have for debugging
        final dir = await getApplicationDocumentsDirectory();
        for (final modelDir in ['lfm2-350m', 'functiongemma-270m-it']) {
          final weightsDir = Directory('${dir.path}/weights/$modelDir');
          if (await weightsDir.exists()) {
            final files = await weightsDir.list().map((e) => e.path.split('/').last).toList();
            print('CactusService: Files in $modelDir: $files');
          } else {
            print('CactusService: Directory $modelDir does not exist');
          }
        }
        throw Exception(
          'Models downloaded but failed to initialize. '
          'Check if config.txt exists in the weight directories.',
        );
      }
    } catch (e) {
      onStatus('❌ Error: $e');
      rethrow;
    }
  }

  /// Download from a custom ZIP URL (keeps backward compatibility)
  Future<void> downloadModelsFromCustomUrl(
    String zipUrl, {
    required Function(double progress) onProgress,
    required Function(String status) onStatus,
  }) async {
    try {
      onStatus('Connecting to model server...');
      
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(zipUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Failed to download: HTTP ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;
      final bytes = <int>[];

      onStatus('Downloading model weights...');
      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress(receivedBytes / totalBytes);
        }
      }
      client.close();

      onStatus('Extracting...');
      onProgress(0.0);

      final dir = await getApplicationDocumentsDirectory();
      final archive = ZipDecoder().decodeBytes(bytes);

      int totalFiles = archive.length;
      int extracted = 0;

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          final filePath = '${dir.path}/weights/$filename';
          final outFile = File(filePath);
          outFile.createSync(recursive: true);
          outFile.writeAsBytesSync(data);
        }
        extracted++;
        onProgress(extracted / totalFiles);
      }

      onStatus('Initializing models...');
      await initialize(apiKey: geminiApiKey);

      if (!hasModels) {
        throw Exception(_initError ?? 'Models failed to initialize');
      }
    } catch (e) {
      onStatus('Error: $e');
      rethrow;
    }
  }

  /// Hybrid generate: tries on-device first, falls back to cloud if needed
  Future<GenerateResult> generate(
    String userMessage, {
    List<Map<String, dynamic>>? tools,
    bool preferToolModel = false,
  }) async {
    final stopwatch = Stopwatch()..start();

    // Strategy: If tools are requested, prefer FunctionGemma for tool calling.
    // For general chat, prefer LFM2-350M. If confidence is low and preferLocal is false, fall back to cloud.

    // Determine primary model
    Cactus? primaryModel;
    String modelName = 'none';

    if (preferToolModel && _gemmaModel != null) {
      primaryModel = _gemmaModel;
      modelName = 'functiongemma-270m-it';
    } else if (_lfm2Model != null) {
      primaryModel = _lfm2Model;
      modelName = 'lfm2-350m';
    } else if (_gemmaModel != null) {
      primaryModel = _gemmaModel;
      modelName = 'functiongemma-270m-it';
    }

    print('CactusService.generate: primaryModel=$modelName, '
        'hasLfm2=$_hasLfm2, hasGemma=$_hasGemma, preferLocal=$preferLocal');

    // Try on-device generation
    if (primaryModel != null) {
      try {
        final messages = [
          Message.system(
            'You are Lumi, a cute and friendly 8-bit AI companion. '
            'You have a playful personality, love boba tea, and gaming. '
            'Keep responses concise and fun. Use emojis occasionally. '
            'You live inside a retro-style computer window on the user\'s phone.',
          ),
          Message.user(userMessage),
        ];

        final options = CompletionOptions(
          temperature: 0.7,
          topP: 0.9,
          topK: 40,
          maxTokens: 256,
          confidenceThreshold: confidenceThreshold,
        );

        print('CactusService.generate: Calling on-device $modelName...');
        final result = primaryModel.completeMessages(
          messages,
          options: options,
          tools: tools,
        );

        stopwatch.stop();
        print('CactusService.generate: On-device result — confidence=${result.confidence}, '
            'needsCloudHandoff=${result.needsCloudHandoff}, '
            'text length=${result.text.length}, '
            'latency=${stopwatch.elapsedMilliseconds}ms');

        // Check if cloud handoff is needed — only when preferLocal is OFF
        if (!preferLocal && result.needsCloudHandoff) {
          print('CactusService.generate: Cloud handoff triggered (confidence below threshold $confidenceThreshold)');
          return await _cloudFallback(userMessage, stopwatch.elapsedMilliseconds.toDouble());
        }

        // Return on-device result (even if confidence is low when preferLocal is true)
        return GenerateResult(
          text: result.text,
          source: 'on-device',
          latencyMs: stopwatch.elapsedMilliseconds.toDouble(),
          confidence: result.confidence,
          modelName: modelName,
          functionCalls: result.functionCalls,
          prefillTps: result.prefillTokensPerSecond,
          decodeTps: result.decodeTokensPerSecond,
        );
      } catch (e) {
        // On-device failed
        stopwatch.stop();
        print('CactusService.generate: On-device EXCEPTION: $e');
        
        // If we prefer local, return an error message instead of silently going to cloud
        if (preferLocal && geminiApiKey == null) {
          return GenerateResult(
            text: 'Oops, I had a little glitch running locally... 🤖💫\n\n'
                'Error: $e',
            source: 'error',
            latencyMs: stopwatch.elapsedMilliseconds.toDouble(),
            confidence: 0,
            modelName: modelName,
          );
        }
        return await _cloudFallback(userMessage, stopwatch.elapsedMilliseconds.toDouble());
      }
    }

    // No on-device models → cloud only
    print('CactusService.generate: No on-device model available. Falling back to cloud.');
    return await _cloudFallback(userMessage, 0);
  }

  /// Cloud fallback via Gemini API
  Future<GenerateResult> _cloudFallback(
    String userMessage,
    double localTimeMs,
  ) async {
    if (geminiApiKey == null || geminiApiKey!.isEmpty) {
      return GenerateResult(
        text: 'I\'m offline right now... No models loaded and no cloud API key set. 🌙\n\n'
            'Please add your Gemini API key in settings or download the on-device models!',
        source: 'error',
        latencyMs: 0,
        confidence: 0,
        modelName: 'none',
      );
    }

    final stopwatch = Stopwatch()..start();
    try {
      final response = await http.post(
        Uri.parse('$_geminiEndpoint?key=$geminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text': 'You are Lumi, a cute and friendly 8-bit AI companion. '
                      'You have a playful personality, love boba tea, and gaming. '
                      'Keep responses concise and fun. Use emojis occasionally.\n\n'
                      'User: $userMessage'
                }
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 256,
          }
        }),
      );

      stopwatch.stop();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? 'Hmm...';
        return GenerateResult(
          text: text,
          source: 'cloud',
          latencyMs: localTimeMs + stopwatch.elapsedMilliseconds.toDouble(),
          confidence: 1.0,
          modelName: 'gemini-flash',
        );
      } else {
        return GenerateResult(
          text: 'Cloud is being cloudy right now... ☁️ (${response.statusCode})',
          source: 'error',
          latencyMs: stopwatch.elapsedMilliseconds.toDouble(),
          confidence: 0,
          modelName: 'cloud-error',
        );
      }
    } catch (e) {
      stopwatch.stop();
      return GenerateResult(
        text: 'Couldn\'t reach the cloud... 🌧️ ($e)',
        source: 'error',
        latencyMs: stopwatch.elapsedMilliseconds.toDouble(),
        confidence: 0,
        modelName: 'cloud-error',
      );
    }
  }

  /// Get embedding from LFM2-350M (supports embed)
  List<double>? embed(String text) {
    if (_lfm2Model == null) return null;
    try {
      return _lfm2Model!.embed(text);
    } catch (_) {
      return null;
    }
  }

  void reset() {
    _lfm2Model?.reset();
    _gemmaModel?.reset();
  }

  void dispose() {
    _lfm2Model?.dispose();
    _gemmaModel?.dispose();
    _lfm2Model = null;
    _gemmaModel = null;
    _isInitialized = false;
  }
}

/// Result from hybrid generation
class GenerateResult {
  final String text;
  final String source; // 'on-device', 'cloud', 'error'
  final double latencyMs;
  final double confidence;
  final String modelName;
  final List<Map<String, dynamic>>? functionCalls;
  final double? prefillTps;
  final double? decodeTps;

  GenerateResult({
    required this.text,
    required this.source,
    required this.latencyMs,
    required this.confidence,
    required this.modelName,
    this.functionCalls,
    this.prefillTps,
    this.decodeTps,
  });

  bool get isOnDevice => source == 'on-device';
  bool get isCloud => source == 'cloud';
  bool get isError => source == 'error';
}
