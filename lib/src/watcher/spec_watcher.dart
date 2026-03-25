import 'dart:async';
import 'dart:io';

import '../config/florval_config.dart';
import '../florval_runner.dart';
import '../utils/logger.dart';

/// Watches the OpenAPI spec file for changes and re-triggers code generation.
class SpecWatcher {
  final FlorvalConfig config;
  final FlorvalLogger logger;

  StreamSubscription<FileSystemEvent>? _subscription;
  Timer? _debounceTimer;

  /// Debounce duration to avoid multiple generations from rapid file saves.
  static const _debounceDuration = Duration(milliseconds: 300);

  SpecWatcher({required this.config, required this.logger});

  /// Starts watching the spec file. Runs an initial generation first.
  Future<void> start() async {
    // Initial generation
    _runGeneration();

    final file = File(config.schemaPath);
    if (!file.existsSync()) {
      logger.error(
          'Cannot watch: spec file not found: ${config.schemaPath}');
      return;
    }

    // Watch the spec file's parent directory for changes to the file
    _subscription = file
        .watch(events: FileSystemEvent.modify | FileSystemEvent.create)
        .listen((event) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(_debounceDuration, () {
        logger.info('Spec file changed, regenerating...');
        _runGeneration();
      });
    });

    logger.info(
        'Watching ${config.schemaPath} for changes. Press Ctrl+C to stop.');

    // Keep the process alive
    await ProcessSignal.sigint.watch().first;
    await stop();
  }

  void _runGeneration() {
    try {
      FlorvalRunner(logger: logger).run(config);
    } catch (e) {
      logger.error('Generation failed: $e');
      logger.info('Waiting for next file change...');
    }
  }

  /// Stops watching and cleans up resources.
  Future<void> stop() async {
    _debounceTimer?.cancel();
    await _subscription?.cancel();
    logger.info('Stopped watching.');
  }
}
