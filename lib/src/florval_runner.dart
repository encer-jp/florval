import 'package:recase/recase.dart';

import 'analyzer/endpoint_analyzer.dart';
import 'analyzer/response_analyzer.dart';
import 'analyzer/schema_analyzer.dart';
import 'config/florval_config.dart';
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

    // 1. Parse
    final specReader = SpecReader();
    final spec = specReader.readFile(config.schemaPath);
    logger.debug('Spec parsed successfully: ${spec.info.title} v${spec.info.version}');

    // 2. Resolve
    final resolver = RefResolver(spec);

    // 3. Analyze
    final schemaAnalyzer = SchemaAnalyzer(resolver);
    final responseAnalyzer = ResponseAnalyzer(resolver, schemaAnalyzer);
    final endpointAnalyzer = EndpointAnalyzer(
      resolver,
      schemaAnalyzer,
      responseAnalyzer,
      paginationConfigs: config.riverpod.pagination,
    );

    final schemas = spec.components?.schemas != null
        ? schemaAnalyzer.analyzeAll(spec.components!.schemas!)
        : <FlorvalSchema>[];
    final endpoints = endpointAnalyzer.analyzeAll(spec.paths);

    // Collect inline union schemas discovered during analysis
    // Merge from both response analyzer and schema analyzer, deduplicating by name
    final allInlineUnions = <String, FlorvalSchema>{};
    for (final s in responseAnalyzer.inlineUnionSchemas) {
      allInlineUnions[s.name] = s;
    }
    for (final s in schemaAnalyzer.inlineUnionSchemas) {
      allInlineUnions[s.name] = s;
    }
    final inlineUnionSchemas = allInlineUnions.values.toList();
    if (inlineUnionSchemas.isNotEmpty) {
      logger.debug(
          'Found ${inlineUnionSchemas.length} inline union schemas');
    }

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

    // Identify variant schemas that are inlined into discriminator unions
    // (these should not be generated as standalone model files)
    final variantNames = ModelGenerator.variantSchemaNames(schemas);
    if (variantNames.isNotEmpty) {
      logger.debug(
          'Skipping ${variantNames.length} variant schemas inlined into unions: $variantNames');
    }

    // Models
    final modelNames = <String>[];
    for (final schema in schemas) {
      if (variantNames.contains(schema.name)) continue;
      final code = modelGenerator.generate(schema);
      writer.writeModel(schema.name, code);
      modelNames.add(schema.name);
      logger.debug('Generated model: ${schema.name}');
    }

    // Inline union schemas (oneOf/anyOf with discriminator in response bodies)
    for (final schema in inlineUnionSchemas) {
      final code = modelGenerator.generate(schema);
      writer.writeModel(schema.name, code);
      modelNames.add(schema.name);
      logger.debug('Generated inline union model: ${schema.name}');
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
      for (final endpoint in endpoints) {
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
      providerUtilityNames,
    );

    logger.success(
        'Generated ${modelNames.length} models, ${responseNames.length} responses, ${clientNames.length} clients${providerNames.isNotEmpty ? ', ${providerNames.length} providers' : ''}');
    logger.info('Output written to ${config.outputDirectory}');
  }
}
