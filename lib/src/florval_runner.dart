import 'package:recase/recase.dart';

import 'analyzer/endpoint_analyzer.dart';
import 'analyzer/response_analyzer.dart';
import 'analyzer/schema_analyzer.dart';
import 'config/florval_config.dart';
import 'generator/client_generator.dart';
import 'generator/file_writer.dart';
import 'generator/model_generator.dart';
import 'generator/provider_generator.dart';
import 'generator/response_generator.dart';
import 'parser/ref_resolver.dart';
import 'parser/spec_reader.dart';
import 'utils/logger.dart';

/// Orchestrates the full code generation pipeline.
class FlorvalRunner {
  final FlorvalLogger logger;

  FlorvalRunner({FlorvalLogger? logger})
      : logger = logger ?? FlorvalLogger();

  /// Runs the code generation pipeline.
  void run(FlorvalConfig config) {
    logger.info('Reading OpenAPI spec from ${config.schemaPath}');

    // 1. Parse
    final specReader = SpecReader();
    final spec = specReader.readFile(config.schemaPath);
    logger.debug('Spec parsed successfully: ${spec.info.title} v${spec.info.version}');

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

    logger.info(
        'Found ${schemas.length} schemas and ${endpoints.length} endpoints');

    // 4. Generate
    final tc = config.templates;
    final modelGenerator = ModelGenerator(templateConfig: tc);
    final responseGenerator = ResponseGenerator(templateConfig: tc);
    final clientGenerator = ClientGenerator(templateConfig: tc);

    // 5. Write
    final writer = FileWriter(config.outputDirectory);
    writer.ensureDirectories();

    // Models
    final modelNames = <String>[];
    for (final schema in schemas) {
      final code = modelGenerator.generate(schema);
      writer.writeModel(schema.name, code);
      modelNames.add(schema.name);
      logger.debug('Generated model: ${schema.name}');
    }

    // Responses
    final responseNames = <String>[];
    for (final endpoint in endpoints) {
      final code = responseGenerator.generate(endpoint);
      writer.writeResponse(endpoint.operationId, code);
      responseNames.add(endpoint.operationId);
      logger.debug('Generated response: ${endpoint.operationId}');
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
      logger.debug('Generated client: ${entry.key}');
    }

    // Providers (optional)
    final providerNames = <String>[];
    if (config.riverpod.enabled) {
      final providerGenerator = ProviderGenerator(templateConfig: tc);
      for (final entry in endpointsByTag.entries) {
        final code =
            providerGenerator.generate(entry.key, entry.value.cast());
        writer.writeProvider(entry.key, code);
        providerNames.add(entry.key);
        logger.debug('Generated provider: ${entry.key}');
      }
    }

    // Barrel file
    writer.writeBarrel(
      modelNames,
      responseNames.map((n) => ReCase(n).snakeCase).toList(),
      clientNames,
      providerNames,
    );

    logger.success(
        'Generated ${modelNames.length} models, ${responseNames.length} responses, ${clientNames.length} clients${providerNames.isNotEmpty ? ', ${providerNames.length} providers' : ''}');
    logger.info('Output written to ${config.outputDirectory}');
  }
}
