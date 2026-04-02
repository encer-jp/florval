import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:recase/recase.dart';

import '../utils/generated_header.dart';

/// Writes generated code files to the output directory.
class FileWriter {
  final String outputDirectory;

  FileWriter(this.outputDirectory);

  /// Cleans generated .dart files from subdirectories and ensures the
  /// directory structure exists.
  ///
  /// This prevents stale files from previous runs from causing ambiguous
  /// exports or other conflicts.
  void cleanAndEnsureDirectories() {
    for (final subDir in ['core', 'models', 'responses', 'clients', 'providers']) {
      final dir = Directory(p.join(outputDirectory, subDir));
      if (dir.existsSync()) {
        for (final file in dir.listSync().whereType<File>()) {
          if (file.path.endsWith('.dart')) {
            file.deleteSync();
          }
        }
      }
      dir.createSync(recursive: true);
    }
  }

  /// Writes a model file.
  void writeModel(String schemaName, String code) {
    final fileName = '${ReCase(schemaName).snakeCase}.dart';
    _writeFile(p.join(outputDirectory, 'models', fileName), code);
  }

  /// Writes a utility model file (e.g. paginated_data.dart).
  void writeUtilityModel(String fileName, String code) {
    _writeFile(p.join(outputDirectory, 'models', fileName), code);
  }

  /// Writes a core runtime file (e.g. json_optional.dart).
  void writeCoreFile(String fileName, String code) {
    _writeFile(p.join(outputDirectory, 'core', fileName), code);
  }

  /// Writes a response file.
  void writeResponse(String operationId, String code) {
    final fileName = '${ReCase(operationId).snakeCase}_response.dart';
    _writeFile(p.join(outputDirectory, 'responses', fileName), code);
  }

  /// Writes a client file.
  void writeClient(String tag, String code) {
    final fileName = '${ReCase(tag).snakeCase}_api_client.dart';
    _writeFile(p.join(outputDirectory, 'clients', fileName), code);
  }

  /// Writes a provider utility file (e.g. retry.dart).
  void writeProviderUtility(String fileName, String code) {
    _writeFile(p.join(outputDirectory, 'providers', fileName), code);
  }

  /// Writes a provider file.
  void writeProvider(String tag, String code) {
    final fileName = '${ReCase(tag).snakeCase}_providers.dart';
    _writeFile(p.join(outputDirectory, 'providers', fileName), code);
  }

  /// Writes the barrel files (api.dart + split barrels).
  void writeBarrel({
    required List<String> modelNames,
    required List<String> responseNames,
    required List<String> clientNames,
    List<String> providerNames = const [],
    List<String> providerUtilityNames = const [],
    List<String> coreFileNames = const [],
  }) {
    // api_models.dart
    final modelsBuffer = StringBuffer();
    modelsBuffer.writeln(generatedFileHeader);
    modelsBuffer.writeln();
    for (final name in coreFileNames) {
      modelsBuffer.writeln("export 'core/$name';");
    }
    for (final name in modelNames) {
      modelsBuffer
          .writeln("export 'models/${ReCase(name).snakeCase}.dart';");
    }
    _writeFile(
        p.join(outputDirectory, 'api_models.dart'), modelsBuffer.toString());

    // api_responses.dart
    final responsesBuffer = StringBuffer();
    responsesBuffer.writeln(generatedFileHeader);
    responsesBuffer.writeln();
    for (final name in responseNames) {
      responsesBuffer.writeln(
          "export 'responses/${ReCase(name).snakeCase}_response.dart';");
    }
    _writeFile(p.join(outputDirectory, 'api_responses.dart'),
        responsesBuffer.toString());

    // api_clients.dart
    final clientsBuffer = StringBuffer();
    clientsBuffer.writeln(generatedFileHeader);
    clientsBuffer.writeln();
    for (final name in clientNames) {
      clientsBuffer.writeln(
          "export 'clients/${ReCase(name).snakeCase}_api_client.dart';");
    }
    _writeFile(p.join(outputDirectory, 'api_clients.dart'),
        clientsBuffer.toString());

    // api_providers.dart (when Riverpod is enabled)
    if (providerNames.isNotEmpty || providerUtilityNames.isNotEmpty) {
      final providersBuffer = StringBuffer();
      providersBuffer.writeln(generatedFileHeader);
      providersBuffer.writeln();
      for (final name in providerNames) {
        providersBuffer.writeln(
            "export 'providers/${ReCase(name).snakeCase}_providers.dart';");
      }
      for (final name in providerUtilityNames) {
        providersBuffer.writeln("export 'providers/$name';");
      }
      _writeFile(p.join(outputDirectory, 'api_providers.dart'),
          providersBuffer.toString());
    }

    // api.dart (main barrel — excludes responses to avoid ambiguous exports)
    final buffer = StringBuffer();
    buffer.writeln(generatedFileHeader);
    buffer.writeln('//');
    buffer.writeln(
        '// Response Union types are not re-exported here to avoid');
    buffer.writeln(
        '// ambiguous exports with model classes of the same name.');
    buffer.writeln(
        '// Import api_responses.dart directly if needed.');
    buffer.writeln();
    buffer.writeln("export 'api_models.dart';");
    buffer.writeln("export 'api_clients.dart';");
    if (providerNames.isNotEmpty || providerUtilityNames.isNotEmpty) {
      buffer.writeln("export 'api_providers.dart';");
    }

    _writeFile(p.join(outputDirectory, 'api.dart'), buffer.toString());
  }

  void _writeFile(String path, String content) {
    File(path).writeAsStringSync(content);
  }
}
