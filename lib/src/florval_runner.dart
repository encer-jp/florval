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
import 'generator/json_optional_generator.dart';
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

    final rawAnalysis = _analyze(config);
    final analysis = _markAbsentableFields(rawAnalysis);

    if (analysis.inlineUnionSchemas.isNotEmpty) {
      logger.debug(
          'Found ${analysis.inlineUnionSchemas.length} inline union schemas');
    }
    if (analysis.inlineObjectSchemas.isNotEmpty) {
      logger.debug(
          'Found ${analysis.inlineObjectSchemas.length} inline object schemas');
    }
    if (analysis.inlineEnumSchemas.isNotEmpty) {
      logger.debug(
          'Found ${analysis.inlineEnumSchemas.length} inline enum schemas');
    }
    logger.info(
        'Found ${analysis.schemas.length} schemas and ${analysis.endpoints.length} endpoints');

    _generate(config, analysis);
  }

  /// Marks non-required fields in PATCH/PUT request body schemas as absentable.
  AnalysisResult _markAbsentableFields(AnalysisResult analysis) {
    // Collect schema names used by PATCH/PUT JSON request bodies
    final absentableSchemaNames = <String>{};
    for (final endpoint in analysis.endpoints) {
      if ((endpoint.method == 'PATCH' || endpoint.method == 'PUT') &&
          endpoint.requestBody != null &&
          !endpoint.requestBody!.isMultipart) {
        absentableSchemaNames.add(endpoint.requestBody!.type.name);
      }
    }
    if (absentableSchemaNames.isEmpty) return analysis;

    logger.debug(
        'Marking absentable fields in ${absentableSchemaNames.length} PATCH/PUT schemas: $absentableSchemaNames');

    return AnalysisResult(
      schemas: _applyAbsentable(analysis.schemas, absentableSchemaNames),
      endpoints: analysis.endpoints,
      inlineUnionSchemas: _applyAbsentable(
          analysis.inlineUnionSchemas, absentableSchemaNames),
      inlineObjectSchemas: _applyAbsentable(
          analysis.inlineObjectSchemas, absentableSchemaNames),
      inlineEnumSchemas: analysis.inlineEnumSchemas,
    );
  }

  /// Clones schemas whose names are in [names], setting `absentable=true`
  /// on non-required fields.
  List<FlorvalSchema> _applyAbsentable(
    List<FlorvalSchema> schemas,
    Set<String> names,
  ) {
    return schemas.map((schema) {
      if (!names.contains(schema.name)) return schema;
      return FlorvalSchema(
        name: schema.name,
        fields: schema.fields
            .map((f) => FlorvalField(
                  name: f.name,
                  jsonKey: f.jsonKey,
                  type: f.type,
                  isRequired: f.isRequired,
                  absentable: !f.isRequired,
                  defaultValue: f.defaultValue,
                  deprecated: f.deprecated,
                  description: f.description,
                  example: f.example,
                  readOnly: f.readOnly,
                  writeOnly: f.writeOnly,
                ))
            .toList(),
        discriminator: schema.discriminator,
        oneOf: schema.oneOf,
        anyOf: schema.anyOf,
        allOf: schema.allOf,
        description: schema.description,
        title: schema.title,
        enumValues: schema.enumValues,
        deprecated: schema.deprecated,
      );
    }).toList();
  }

  /// Returns true if any schema in the analysis has absentable fields.
  bool _hasAbsentableFields(AnalysisResult analysis) {
    for (final schemas in [
      analysis.schemas,
      analysis.inlineUnionSchemas,
      analysis.inlineObjectSchemas,
    ]) {
      for (final schema in schemas) {
        if (schema.fields.any((f) => f.absentable)) return true;
      }
    }
    return false;
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

    final allInlineEnums = <String, FlorvalSchema>{};
    for (final s in schemaResult.inlineEnumSchemas) {
      allInlineEnums[s.name] = s;
    }
    for (final s in endpointResult.inlineEnumSchemas) {
      allInlineEnums[s.name] = s;
    }

    return AnalysisResult(
      schemas: schemaResult.schemas,
      endpoints: endpointResult.endpoints,
      inlineUnionSchemas: allInlineUnions.values.toList(),
      inlineObjectSchemas: allInlineObjects.values.toList(),
      inlineEnumSchemas: allInlineEnums.values.toList(),
    );
  }

  /// Generate code and write files from analysis results.
  void _generate(FlorvalConfig config, AnalysisResult analysis) {
    final tc = config.templates;
    final modelGenerator = ModelGenerator(templateConfig: tc);
    final responseGenerator = ResponseGenerator(templateConfig: tc);
    final clientGenerator = ClientGenerator(templateConfig: tc);

    final writer = FileWriter(config.outputDirectory);
    writer.cleanAndEnsureDirectories();

    // Core runtime files (e.g. JsonOptional for PATCH/PUT)
    final coreFileNames = <String>[];
    final hasAbsentable = _hasAbsentableFields(analysis);
    if (hasAbsentable) {
      final jsonOptionalGen = JsonOptionalGenerator(templateConfig: tc);
      writer.writeCoreFile('json_optional.dart', jsonOptionalGen.generate());
      coreFileNames.add('json_optional.dart');
      logger.debug('Generated core: json_optional');
    }

    // Identify variant schemas and generated subclass names that are inlined
    // into union types (these should not be generated as standalone model files
    // to avoid ambiguous exports in the barrel file)
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
      if (variantNames.contains(schema.name)) continue;
      final code = modelGenerator.generate(schema);
      writer.writeModel(schema.name, code);
      modelNames.add(schema.name);
      logger.debug('Generated inline union model: ${schema.name}');
    }

    // Inline object schemas (properties-bearing objects nested inside other schemas)
    for (final schema in analysis.inlineObjectSchemas) {
      if (variantNames.contains(schema.name)) continue;
      final code = modelGenerator.generate(schema);
      writer.writeModel(schema.name, code);
      modelNames.add(schema.name);
      logger.debug('Generated inline object model: ${schema.name}');
    }

    // Inline enum schemas (enum values defined inline in properties)
    for (final schema in analysis.inlineEnumSchemas) {
      if (variantNames.contains(schema.name)) continue;
      final code = modelGenerator.generate(schema);
      writer.writeModel(schema.name, code);
      modelNames.add(schema.name);
      logger.debug('Generated inline enum model: ${schema.name}');
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
        excludeAutoInvalidate: config.riverpod.excludeAutoInvalidate,
        retry: config.riverpod.retry,
      );

      // Generate centralized Dio provider
      final apiDioCode = providerGenerator.generateApiDioProvider();
      writer.writeProviderUtility('api_dio_provider.dart', apiDioCode);
      providerUtilityNames.add('api_dio_provider.dart');
      logger.debug('Generated utility: api_dio_provider');

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

    // Remove any model whose name collides with a subclass defined inside
    // a union type file. This prevents Dart's ambiguous_export error when
    // the barrel file exports both the union file and the standalone model.
    // Scans ALL union schemas (component + inline) to catch every subclass.
    final allUnionSchemas = <FlorvalSchema>[
      ...analysis.schemas.where((s) =>
          (s.oneOf != null && s.oneOf!.isNotEmpty) ||
          (s.anyOf != null && s.anyOf!.isNotEmpty)),
      ...analysis.inlineUnionSchemas,
    ];
    final subclassNames = ModelGenerator.unionSubclassNames(allUnionSchemas);
    if (subclassNames.isNotEmpty) {
      final removed = modelNames.where((n) => subclassNames.contains(n)).toList();
      if (removed.isNotEmpty) {
        modelNames.removeWhere((n) => subclassNames.contains(n));
        logger.debug(
            'Excluded ${removed.length} models from barrel to avoid ambiguous exports: $removed');
      }
    }

    // Barrel file
    writer.writeBarrel(
      modelNames: modelNames,
      responseNames: responseNames.map((n) => ReCase(n).snakeCase).toList(),
      clientNames: clientNames,
      providerNames: providerNames,
      providerUtilityNames: providerUtilityNames,
      coreFileNames: coreFileNames,
    );

    // Post-process: apply lint fixes and formatting
    logger.info('Formatting generated code...');
    writer.formatOutput(log: (msg) => logger.warn(msg));

    logger.success(
        'Generated ${modelNames.length} models, ${responseNames.length} responses, ${clientNames.length} clients${providerNames.isNotEmpty ? ', ${providerNames.length} providers' : ''}');
    logger.info('Output written to ${config.outputDirectory}');
  }
}
