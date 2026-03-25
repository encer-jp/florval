import 'dart:io';

import 'package:recase/recase.dart';

import 'analyzer/endpoint_analyzer.dart';
import 'analyzer/response_analyzer.dart';
import 'analyzer/schema_analyzer.dart';
import 'config/florval_config.dart';
import 'generator/client_generator.dart';
import 'generator/file_writer.dart';
import 'generator/model_generator.dart';
import 'generator/response_generator.dart';
import 'parser/ref_resolver.dart';
import 'parser/spec_reader.dart';

/// Orchestrates the full code generation pipeline.
class FlorvalRunner {
  /// Runs the code generation pipeline.
  void run(FlorvalConfig config) {
    stdout.writeln('florval: Reading OpenAPI spec from ${config.schemaPath}');

    // 1. Parse
    final specReader = SpecReader();
    final spec = specReader.readFile(config.schemaPath);

    // 2. Resolve
    final resolver = RefResolver(spec);

    // 3. Analyze
    final schemaAnalyzer = SchemaAnalyzer(resolver);
    final responseAnalyzer = ResponseAnalyzer(resolver, schemaAnalyzer);
    final endpointAnalyzer =
        EndpointAnalyzer(resolver, schemaAnalyzer, responseAnalyzer);

    final schemas = spec.components?.schemas != null
        ? schemaAnalyzer.analyzeAll(spec.components!.schemas!)
        : [];
    final endpoints = endpointAnalyzer.analyzeAll(spec.paths);

    stdout.writeln(
        'florval: Found ${schemas.length} schemas and ${endpoints.length} endpoints');

    // 4. Generate
    final modelGenerator = ModelGenerator();
    final responseGenerator = ResponseGenerator();
    final clientGenerator = ClientGenerator();

    // 5. Write
    final writer = FileWriter(config.outputDirectory);
    writer.ensureDirectories();

    // Models
    final modelNames = <String>[];
    for (final schema in schemas) {
      final code = modelGenerator.generate(schema);
      writer.writeModel(schema.name, code);
      modelNames.add(schema.name);
    }

    // Responses
    final responseNames = <String>[];
    for (final endpoint in endpoints) {
      final code = responseGenerator.generate(endpoint);
      writer.writeResponse(endpoint.operationId, code);
      responseNames.add(endpoint.operationId);
    }

    // Clients (grouped by tag)
    final endpointsByTag = <String, List<dynamic>>{};
    for (final endpoint in endpoints) {
      final tag = endpoint.primaryTag;
      endpointsByTag.putIfAbsent(tag, () => []).add(endpoint);
    }

    final clientNames = <String>[];
    for (final entry in endpointsByTag.entries) {
      final code = clientGenerator.generate(entry.key, entry.value.cast());
      writer.writeClient(entry.key, code);
      clientNames.add(entry.key);
    }

    // Barrel file
    writer.writeBarrel(
      modelNames,
      responseNames.map((n) => ReCase(n).snakeCase).toList(),
      clientNames,
    );

    stdout.writeln(
        'florval: Generated ${modelNames.length} models, ${responseNames.length} responses, ${clientNames.length} clients');
    stdout.writeln('florval: Output written to ${config.outputDirectory}');
  }
}
