import 'package:openapi_spec_plus/v31.dart' as v31;

/// Resolves $ref references in OpenAPI specs.
class RefResolver {
  final v31.OpenAPI spec;

  RefResolver(this.spec);

  /// Resolves a schema's $ref, returning the referenced schema.
  /// Returns the schema unchanged if it has no $ref.
  v31.Schema resolveSchema(v31.Schema schema, {Set<String>? visited}) {
    if (schema.ref == null) return schema;

    visited ??= {};
    if (visited.contains(schema.ref)) {
      // Circular reference — return as-is
      return schema;
    }
    visited.add(schema.ref!);

    final name = _extractName(schema.ref!);
    final resolved = spec.components?.schemas?[name];
    if (resolved == null) {
      final available = spec.components?.schemas?.keys.toList() ?? [];
      final suggestion = _suggest(name, available);
      throw RefResolveException(
        'Cannot resolve schema ref: ${schema.ref}\n'
        '  Available schemas: ${available.isEmpty ? "(none)" : available.join(", ")}'
        '${suggestion != null ? "\n  Did you mean: $suggestion?" : ""}',
      );
    }

    // Recursively resolve if the resolved schema also has a $ref
    return resolveSchema(resolved, visited: visited);
  }

  /// Returns the schema name from a $ref string.
  /// Returns null if the schema has no $ref.
  String? schemaName(v31.Schema schema) {
    if (schema.ref == null) return null;
    return _extractName(schema.ref!);
  }

  /// Resolves a response's $ref, returning the referenced response.
  v31.Response resolveResponse(v31.Response response, {Set<String>? visited}) {
    if (response.ref == null) return response;

    visited ??= {};
    if (visited.contains(response.ref)) {
      return response;
    }
    visited.add(response.ref!);

    final name = _extractName(response.ref!);
    final resolved = spec.components?.responses?[name];
    if (resolved == null) {
      final available = spec.components?.responses?.keys.toList() ?? [];
      throw RefResolveException(
        'Cannot resolve response ref: ${response.ref}\n'
        '  Available responses: ${available.isEmpty ? "(none)" : available.join(", ")}',
      );
    }

    return resolveResponse(resolved, visited: visited);
  }

  /// Resolves a parameter's $ref.
  v31.Parameter resolveParameter(v31.Parameter parameter) {
    if (parameter.ref == null) return parameter;

    final name = _extractName(parameter.ref!);
    final resolved = spec.components?.parameters?[name];
    if (resolved == null) {
      final available = spec.components?.parameters?.keys.toList() ?? [];
      throw RefResolveException(
        'Cannot resolve parameter ref: ${parameter.ref}\n'
        '  Available parameters: ${available.isEmpty ? "(none)" : available.join(", ")}',
      );
    }

    return resolved;
  }

  /// Extracts the name from a $ref path.
  /// e.g. '#/components/schemas/User' → 'User'
  String _extractName(String ref) {
    return ref.split('/').last;
  }

  /// Suggests a similar name from the available list using simple matching.
  String? _suggest(String name, List<String> available) {
    if (available.isEmpty) return null;
    final lower = name.toLowerCase();
    // Find a name that starts with the same prefix or contains the input
    for (final candidate in available) {
      final candidateLower = candidate.toLowerCase();
      if (candidateLower == lower ||
          candidateLower.startsWith(lower) ||
          lower.startsWith(candidateLower) ||
          candidateLower.contains(lower) ||
          lower.contains(candidateLower)) {
        return candidate;
      }
    }
    return null;
  }
}

/// Exception thrown when $ref resolution fails.
class RefResolveException implements Exception {
  final String message;
  const RefResolveException(this.message);

  @override
  String toString() => 'RefResolveException: $message';
}
