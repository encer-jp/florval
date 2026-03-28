import 'package:recase/recase.dart';

import 'analyzer/endpoint_analyzer.dart';
import 'analyzer/response_analyzer.dart';
import 'analyzer/schema_analyzer.dart';
import 'config/florval_config.dart';
import 'model/analysis_result.dart';
import 'model/api_endpoint.dart';
import 'model/api_schema.dart';
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

    final analysis = _analyze(config);

    if (analysis.inlineUnionSchemas.isNotEmpty) {
      logger.debug(
          'Found ${analysis.inlineUnionSchemas.length} inline union schemas');
    }
    if (analysis.inlineObjectSchemas.isNotEmpty) {
      logger.debug(
          'Found ${analysis.inlineObjectSchemas.length} inline object schemas');
    }
    logger.info(
        'Found ${analysis.schemas.length} schemas and ${analysis.endpoints.length} endpoints');

    _generate(config, analysis);
  }

  /// Parse, resolve, and analyze the OpenAPI spec.
  AnalysisResult _analyze(FlorvalConfig config) {
    // 1. Parse
    final specReader = SpecReader();
    final spec = specReader.readFile(config.schemaPath);
    logger.debug('Spec parsed successfully: ${spec.info.title} v${spec.info.version}');

    // 2. Resolve
    final resolver = RefResolver(spec);

    // 3. Analyze
    final schemaAnalyzer = SchemaAnalyzer(resolver, logger: logger);
    final responseAnalyzer = ResponseAnalyzer(resolver, schemaAnalyzer, logger: logger);
    final endpointAnalyzer = EndpointAnalyzer(
      resolver,
      schemaAnalyzer,
      responseAnalyzer,
      logger: logger,
      paginationConfigs: config.riverpod.pagination,
    );

    // Schema analysis
    final schemaResult = spec.components?.schemas != null
        ? schemaAnalyzer.analyzeAll(spec.components!.schemas!)
        : const SchemaAnalysisResult(schemas: []);

    // Endpoint analysis (also discovers inline schemas via response analysis)
    final endpointResult = endpointAnalyzer.analyzeAll(spec.paths);

    // Merge inline schemas from both sources, deduplicating by name
    final allInlineUnions = <String, FlorvalSchema>{};
    for (final s in schemaResult.inlineUnionSchemas) {
      allInlineUnions[s.name] = s;
    }
    for (final s in endpointResult.inlineUnionSchemas) {
      allInlineUnions[s.name] = s;
    }

    final allInlineObjects = <String, FlorvalSchema>{};
    for (final s in schemaResult.inlineObjectSchemas) {
      allInlineObjects[s.name] = s;
    }
    for (final s in endpointResult.inlineObjectSchemas) {
      allInlineObjects[s.name] = s;
    }

    return AnalysisResult(
      schemas: schemaResult.schemas,
      endpoints: endpointResult.endpoints,
      inlineUnionSchemas: allInlineUnions.values.toList(),
      inlineObjectSchemas: allInlineObjects.values.toList(),
    );
  }

  /// Generate code and write files from analysis results.
  void _generate(FlorvalConfig config, AnalysisResult analysis) {
    final tc = config.templates;
    final modelGenerator = ModelGenerator(templateConfig: tc);
    final responseGenerator = ResponseGenerator(templateConfig: tc);
    final clientGenerator = ClientGenerator(templateConfig: tc);

    final writer = FileWriter(config.outputDirectory);
    writer.ensureDirectories();

    // Identify variant schemas that are inlined into discriminator unions
    // (these should not be generated as standalone model files)
    final variantNames = ModelGenerator.variantSchemaNames(analysis.schemas);
    if (variantNames.isNotEmpty) {
      logger.debug(
          'Skipping ${variantNames.length} variant schemas inlined into unions: $variantNames');
    }

    // Models
    final modelNames = <String>[];
    for (final schema in analysis.schemas) {
      if (variantNames.contains(schema.name)) continue;
      final code = modelGenerator.generate(schema);
      writer.writeModel(schema.name, code);
      modelNames.add(schema.name);
      logger.debug('Generated model: ${schema.name}');
    }

    // Inline union schemas (oneOf/anyOf with discriminator in response bodies)
    for (final schema in analysis.inlineUnionSchemas) {
      final code = modelGenerator.generate(schema);
      writer.writeModel(schema.name, code);
      modelNames.add(schema.name);
      logger.debug('Generated inline union model: ${schema.name}');
    }

    // Inline object schemas (properties-bearing objects nested inside other schemas)
    for (final schema in analysis.inlineObjectSchemas) {
      final code = modelGenerator.generate(schema);
      writer.writeModel(schema.name, code);
      modelNames.add(schema.name);
      logger.debug('Generated inline object model: ${schema.name}');
    }

    // Pagination utility models (generated only when pagination is configured)
    if (config.riverpod.pagination.isNotEmpty) {
      final paginatedDataCode = modelGenerator.generatePaginatedData();
      writer.writeUtilityModel('paginated_data.dart', paginatedDataCode);
      modelNames.add('paginated_data');
      logger.debug('Generated utility: paginated_data');

      final apiExceptionCode = modelGenerator.generateApiException();
      writer.writeUtilityModel('api_exception.dart', apiExceptionCode);
      modelNames.add('api_exception');
      logger.debug('Generated utility: api_exception');

      // Generate wrapper models for inline paginated response schemas
      for (final endpoint in analysis.endpoints) {
        if (endpoint.pagination?.wrapperSchema != null) {
          final wrapper = endpoint.pagination!.wrapperSchema!;
          final code = modelGenerator.generate(wrapper);
          writer.writeModel(wrapper.name, code);
          modelNames.add(wrapper.name);
          logger.debug('Generated pagination wrapper: ${wrapper.name}');
        }
      }
    }

    // Responses
    final responseNames = <String>[];
    for (final endpoint in analysis.endpoints) {
      final code = responseGenerator.generate(endpoint);
      writer.writeResponse(endpoint.operationId, code);
      responseNames.add(endpoint.operationId);
      logger.debug('Generated response: ${endpoint.operationId}');
    }

    // Clients (grouped by tag)
    final endpointsByTag = <String, List<FlorvalEndpoint>>{};
    for (final endpoint in analysis.endpoints) {
      final tag = endpoint.primaryTag;
      endpointsByTag.putIfAbsent(tag, () => []).add(endpoint);
    }

    final clientNames = <String>[];
    for (final entry in endpointsByTag.entries) {
      final code = clientGenerator.generate(entry.key, entry.value);
      writer.writeClient(entry.key, code);
      clientNames.add(entry.key);
      logger.debug('Generated client: ${entry.key}');
    }

    // Providers (optional)
    final providerNames = <String>[];
    final providerUtilityNames = <String>[];
    if (config.riverpod.enabled) {
      final providerGenerator = ProviderGenerator(
        templateConfig: tc,
        autoInvalidate: config.riverpod.autoInvalidate,
        retry: config.riverpod.retry,
      );

      // Generate retry utility if configured
      if (config.riverpod.retry != null) {
        final retryCode =
            providerGenerator.generateRetryUtility(config.riverpod.retry!);
        writer.writeProviderUtility('retry.dart', retryCode);
        providerUtilityNames.add('retry.dart');
        logger.debug('Generated utility: retry');
      }

      for (final entry in endpointsByTag.entries) {
        final code =
            providerGenerator.generate(entry.key, entry.value);
        writer.writeProvider(entry.key, code);
        providerNames.add(entry.key);
        logger.debug('Generated provider: ${entry.key}');
      }
    }

    // Barrel file
    writer.writeBarrel(
      modelNames: modelNames,
      responseNames: responseNames.map((n) => ReCase(n).snakeCase).toList(),
      clientNames: clientNames,
      providerNames: providerNames,
      providerUtilityNames: providerUtilityNames,
    );

    logger.success(
        'Generated ${modelNames.length} models, ${responseNames.length} responses, ${clientNames.length} clients${providerNames.isNotEmpty ? ', ${providerNames.length} providers' : ''}');
    logger.info('Output written to ${config.outputDirectory}');
  }
}
