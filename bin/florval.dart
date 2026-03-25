import 'dart:io';

import 'package:args/args.dart';
import 'package:florval/src/config/florval_config.dart';
import 'package:florval/src/florval_runner.dart';
import 'package:florval/src/init/init_command.dart';
import 'package:florval/src/parser/ref_resolver.dart';
import 'package:florval/src/parser/spec_reader.dart';
import 'package:florval/src/utils/logger.dart';
import 'package:florval/src/watcher/spec_watcher.dart';

void main(List<String> arguments) async {
  final parser = ArgParser();

  final generateParser = ArgParser()
    ..addOption('config',
        abbr: 'c',
        help: 'Path to florval.yaml config file.',
        defaultsTo: 'florval.yaml')
    ..addOption('schema',
        abbr: 's', help: 'Path to OpenAPI spec file (overrides config).')
    ..addOption('output',
        abbr: 'o',
        help: 'Output directory for generated code (overrides config).')
    ..addFlag('verbose',
        abbr: 'v', help: 'Enable verbose debug output.', defaultsTo: false)
    ..addFlag('watch',
        abbr: 'w',
        help: 'Watch spec file for changes and auto-regenerate.',
        defaultsTo: false);

  final initParser = ArgParser()
    ..addOption('config',
        abbr: 'c',
        help: 'Output file path.',
        defaultsTo: 'florval.yaml')
    ..addFlag('force',
        abbr: 'f',
        help: 'Overwrite existing file.',
        defaultsTo: false);

  parser.addCommand('generate', generateParser);
  parser.addCommand('init', initParser);

  final results = parser.parse(arguments);

  if (results.command == null) {
    _printUsage(parser, generateParser);
    exit(1);
  }

  switch (results.command!.name) {
    case 'generate':
      await _runGenerate(results.command!);
    case 'init':
      _runInit(results.command!);
    default:
      _printUsage(parser, generateParser);
      exit(1);
  }
}

void _runInit(ArgResults command) {
  final configPath = command['config'] as String;
  final force = command['force'] as bool;
  final result = InitCommand.run(configPath: configPath, force: force);

  switch (result) {
    case InitResult.created:
      stdout.writeln('Created $configPath');
    case InitResult.alreadyExists:
      stderr.writeln(
          'Error: $configPath already exists. Use --force to overwrite.');
      exit(1);
  }
}

Future<void> _runGenerate(ArgResults command) async {
  final verbose = command['verbose'] as bool;
  final watch = command['watch'] as bool;
  final logger = FlorvalLogger(verbose: verbose);

  try {
    final config = _resolveConfig(command);

    if (watch) {
      final watcher = SpecWatcher(config: config, logger: logger);
      await watcher.start();
    } else {
      FlorvalRunner(logger: logger).run(config);
    }
  } on FlorvalConfigException catch (e) {
    logger.error(e.message);
    exit(1);
  } on SpecReaderException catch (e) {
    logger.error(e.message);
    exit(1);
  } on RefResolveException catch (e) {
    logger.error(e.message);
    exit(1);
  } catch (e) {
    logger.error('$e');
    exit(1);
  }
}

FlorvalConfig _resolveConfig(ArgResults command) {
  final schema = command['schema'] as String?;
  final output = command['output'] as String?;

  // If both schema and output are provided via CLI, use them directly
  if (schema != null && output != null) {
    return FlorvalConfig.fromArgs(
      schemaPath: schema,
      outputDirectory: output,
    );
  }

  // Otherwise, load from config file
  final configPath = command['config'] as String;
  final config = FlorvalConfig.fromFile(configPath);

  // Allow CLI overrides
  if (schema != null || output != null) {
    return FlorvalConfig(
      schemaPath: schema ?? config.schemaPath,
      outputDirectory: output ?? config.outputDirectory,
      client: config.client,
    );
  }

  return config;
}

void _printUsage(ArgParser parser, ArgParser generateParser) {
  stdout.writeln('florval - OpenAPI to Flutter/Dart code generator');
  stdout.writeln();
  stdout.writeln('Usage: dart run florval <command> [options]');
  stdout.writeln();
  stdout.writeln('Commands:');
  stdout.writeln('  generate    Generate Dart code from OpenAPI spec');
  stdout.writeln('  init        Generate a florval.yaml config template');
  stdout.writeln();
  stdout.writeln('Generate options:');
  stdout.writeln(generateParser.usage);
}
