import 'dart:io';

import 'package:args/args.dart';
import 'package:florval/src/config/florval_config.dart';
import 'package:florval/src/florval_runner.dart';

void main(List<String> arguments) {
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
        help: 'Output directory for generated code (overrides config).');

  parser.addCommand('generate', generateParser);

  final results = parser.parse(arguments);

  if (results.command == null || results.command!.name != 'generate') {
    _printUsage(parser, generateParser);
    exit(results.command == null ? 1 : 0);
  }

  final command = results.command!;

  try {
    final config = _resolveConfig(command);
    FlorvalRunner().run(config);
  } on FlorvalConfigException catch (e) {
    stderr.writeln('Error: $e');
    exit(1);
  } catch (e) {
    stderr.writeln('Error: $e');
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
  stdout.writeln();
  stdout.writeln('Generate options:');
  stdout.writeln(generateParser.usage);
}
