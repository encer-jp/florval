import 'package:florval/src/model/api_type.dart';
import 'package:recase/recase.dart';

import '../config/template_config.dart';
import '../model/api_endpoint.dart';

/// Generates Riverpod 3.x providers grouped by tag.
///
/// - GET endpoints → @riverpod Notifier with build() params
/// - POST/PUT/DELETE/PATCH → Mutation<ResponseType>() constant + optional helper
class ProviderGenerator {
  final TemplateConfig? templateConfig;
  final bool autoInvalidate;

  ProviderGenerator({this.templateConfig, this.autoInvalidate = false});

  /// Generates a provider file for a group of endpoints sharing a tag.
  String generate(String tag, List<FlorvalEndpoint> endpoints) {
    final buffer = StringBuffer();

    // Custom header
    if (templateConfig?.header != null) {
      buffer.writeln(templateConfig!.header);
      buffer.writeln();
    }

    // Imports
    _writeImports(buffer, tag, endpoints);
    buffer.writeln();

    // Part directive (for riverpod_generator on GET notifiers)
    final hasGetEndpoints = endpoints.any((e) => e.method == 'GET');
    if (hasGetEndpoints) {
      buffer.writeln("part '${ReCase(tag).snakeCase}_providers.g.dart';");
      buffer.writeln();
    }

    // Client provider
    _writeClientProvider(buffer, tag);
    buffer.writeln();

    // Separate GET endpoints for cache invalidation references
    final getEndpoints =
        autoInvalidate ? endpoints.where((e) => e.method == 'GET').toList() : <FlorvalEndpoint>[];

    // Endpoint providers / mutations
    for (final endpoint in endpoints) {
      if (endpoint.method == 'GET') {
        _writeGetProvider(buffer, tag, endpoint);
      } else {
        _writeMutationDefinition(buffer, endpoint);
        if (autoInvalidate && getEndpoints.isNotEmpty) {
          _writeMutationHelper(buffer, tag, endpoint,
              getEndpoints: getEndpoints);
        }
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  void _writeImports(
      StringBuffer buffer, String tag, List<FlorvalEndpoint> endpoints) {
    final hasGetEndpoints = endpoints.any((e) => e.method == 'GET');
    final hasMutationEndpoints = endpoints.any((e) => e.method != 'GET');

    if (hasGetEndpoints) {
      buffer.writeln("import 'dart:async';");
      buffer.writeln();
    }

    // Import dio if any endpoint uses multipart (for MultipartFile type)
    final hasMultipart = endpoints.any(
        (e) => e.requestBody != null && e.requestBody!.isMultipart);
    if (hasMultipart) {
      buffer.writeln("import 'package:dio/dio.dart';");
    }
    if (hasMutationEndpoints) {
      buffer.writeln(
          "import 'package:riverpod/experimental/mutation.dart';");
    }
    if (hasGetEndpoints) {
      buffer.writeln(
          "import 'package:riverpod_annotation/riverpod_annotation.dart';");
    }

    // Custom provider imports
    if (templateConfig != null) {
      for (final import_ in templateConfig!.providerImports) {
        buffer.writeln(import_);
      }
    }
    buffer.writeln();

    // Import client
    buffer.writeln(
        "import '../clients/${ReCase(tag).snakeCase}_api_client.dart';");

    // Import response types
    final responseImports = <String>{};
    final modelImports = <String>{};

    for (final endpoint in endpoints) {
      responseImports.add(ReCase(endpoint.operationId).snakeCase);
      _collectModelImports(endpoint, modelImports);
    }

    for (final import_ in modelImports) {
      buffer.writeln("import '../models/$import_.dart';");
    }
    for (final import_ in responseImports) {
      buffer.writeln("import '../responses/${import_}_response.dart';");
    }
  }

  void _writeClientProvider(StringBuffer buffer, String tag) {
    final className = '${ReCase(tag).pascalCase}ApiClient';
    final providerName = '${ReCase(tag).camelCase}ApiClient';

    buffer.writeln('@riverpod');
    buffer.writeln('$className $providerName(Ref ref) {');
    buffer.writeln(
        "  throw UnimplementedError('Provide a Dio instance via override');");
    buffer.writeln('}');
  }

  void _writeGetProvider(
      StringBuffer buffer, String tag, FlorvalEndpoint endpoint) {
    final className = ReCase(endpoint.operationId).pascalCase;
    final responseType = '${className}Response';
    final clientProvider = '${ReCase(tag).camelCase}ApiClientProvider';
    final methodName = ReCase(endpoint.operationId).camelCase;

    buffer.writeln('@riverpod');
    buffer.writeln('class $className extends _\$$className {');
    buffer.writeln('  @override');

    // build() signature
    final buildParams = _buildBuildParams(endpoint);
    if (buildParams.isNotEmpty) {
      buffer.writeln('  FutureOr<$responseType> build({');
      for (final param in buildParams) {
        buffer.writeln('    $param');
      }
      buffer.writeln('  }) async {');
    } else {
      buffer.writeln('  FutureOr<$responseType> build() async {');
    }

    // build() body
    buffer.writeln('    final client = ref.watch($clientProvider);');
    buffer.write('    return client.$methodName(');
    final callArgs = _buildCallArgs(endpoint);
    if (callArgs.isNotEmpty) {
      buffer.write(callArgs);
    }
    buffer.writeln(');');
    buffer.writeln('  }');
    buffer.writeln('}');
  }

  void _writeMutationDefinition(
      StringBuffer buffer, FlorvalEndpoint endpoint) {
    final className = ReCase(endpoint.operationId).pascalCase;
    final responseType = '${className}Response';

    buffer.writeln('/// Mutation for ${endpoint.operationId} (${endpoint.method} ${endpoint.path})');
    buffer.writeln('final ${ReCase(endpoint.operationId).camelCase} = Mutation<$responseType>();');
  }

  void _writeMutationHelper(
      StringBuffer buffer, String tag, FlorvalEndpoint endpoint,
      {List<FlorvalEndpoint> getEndpoints = const []}) {
    final className = ReCase(endpoint.operationId).pascalCase;
    final responseType = '${className}Response';
    final clientProvider = '${ReCase(tag).camelCase}ApiClientProvider';
    final methodName = ReCase(endpoint.operationId).camelCase;
    final mutationName = ReCase(endpoint.operationId).camelCase;
    final helperName = 'run${className}';

    // Build helper function signature
    final helperParams = _buildMutationParams(endpoint);

    buffer.writeln();
    buffer.writeln('/// Runs $mutationName mutation and invalidates related GET providers.');
    if (helperParams.isNotEmpty) {
      buffer.writeln('Future<$responseType> $helperName(');
      buffer.writeln('  MutationTarget ref, {');
      for (final param in helperParams) {
        buffer.writeln('  $param');
      }
      buffer.writeln('}) async {');
    } else {
      buffer.writeln('Future<$responseType> $helperName(');
      buffer.writeln('  MutationTarget ref,');
      buffer.writeln(') async {');
    }

    buffer.writeln('  return $mutationName.run(ref, (tsx) async {');
    buffer.writeln('    final client = tsx.get($clientProvider);');

    // Client method call
    final callArgs = _buildMutationCallArgs(endpoint);
    if (callArgs.isNotEmpty) {
      buffer.writeln('    final result = await client.$methodName($callArgs);');
    } else {
      buffer.writeln('    final result = await client.$methodName();');
    }

    // Invalidate GET providers
    for (final getEndpoint in getEndpoints) {
      final providerName =
          '${ReCase(getEndpoint.operationId).camelCase}Provider';
      buffer.writeln('    ref.invalidate($providerName);');
    }

    buffer.writeln('    return result;');
    buffer.writeln('  });');
    buffer.writeln('}');
  }

  /// Build params for GET provider's build() method.
  /// Path params → required, query params → optional or required based on spec.
  List<String> _buildBuildParams(FlorvalEndpoint endpoint) {
    final params = <String>[];

    for (final p in endpoint.pathParameters) {
      params.add('required ${p.type.dartType} ${p.dartName},');
    }
    for (final p in endpoint.queryParameters) {
      if (p.isRequired) {
        params.add('required ${p.type.dartType} ${p.dartName},');
      } else {
        params.add('${p.type.dartType}? ${p.dartName},');
      }
    }

    return params;
  }

  /// Build call arguments for the client method invocation in GET providers.
  String _buildCallArgs(FlorvalEndpoint endpoint) {
    final args = <String>[];

    for (final p in endpoint.pathParameters) {
      args.add('${p.dartName}: ${p.dartName}');
    }
    for (final p in endpoint.queryParameters) {
      args.add('${p.dartName}: ${p.dartName}');
    }

    return args.isEmpty ? '' : args.join(', ');
  }

  /// Build params for mutation helper function.
  /// Path params + request body.
  List<String> _buildMutationParams(FlorvalEndpoint endpoint) {
    final params = <String>[];

    for (final p in endpoint.pathParameters) {
      params.add('required ${p.type.dartType} ${p.dartName},');
    }
    if (endpoint.requestBody != null) {
      final body = endpoint.requestBody!;
      if (body.isMultipart && body.formFields != null) {
        // Expand multipart form fields as individual parameters
        for (final field in body.formFields!) {
          if (field.isRequired) {
            params.add('required ${field.type.dartType} ${field.name},');
          } else {
            params.add('${field.type.dartType}? ${field.name},');
          }
        }
      } else {
        if (body.isRequired) {
          params.add('required ${body.type.dartType} body,');
        } else {
          params.add('${body.type.dartType}? body,');
        }
      }
    }

    return params;
  }

  /// Build call arguments for the client method invocation in mutation helpers.
  String _buildMutationCallArgs(FlorvalEndpoint endpoint) {
    final args = <String>[];

    for (final p in endpoint.pathParameters) {
      args.add('${p.dartName}: ${p.dartName}');
    }
    if (endpoint.requestBody != null) {
      final body = endpoint.requestBody!;
      if (body.isMultipart && body.formFields != null) {
        for (final field in body.formFields!) {
          args.add('${field.name}: ${field.name}');
        }
      } else {
        args.add('body: body');
      }
    }

    return args.isEmpty ? '' : args.join(', ');
  }

  void _collectModelImports(FlorvalEndpoint endpoint, Set<String> imports) {
    if (endpoint.requestBody != null && !endpoint.requestBody!.isMultipart) {
      _addTypeImport(imports, endpoint.requestBody!.type);
    }
  }

  void _addTypeImport(Set<String> imports, FlorvalType type) {
    if (type.ref != null) {
      final refName = type.ref!.split('/').last;
      imports.add(ReCase(refName).snakeCase);
    }
    if (type.isList && type.itemType != null) {
      _addTypeImport(imports, type.itemType!);
    }
  }
}
