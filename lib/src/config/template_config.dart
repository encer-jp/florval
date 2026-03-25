import 'package:yaml/yaml.dart';

/// Configuration for custom template overrides.
class TemplateConfig {
  /// Custom file header comment (prepended to all generated files).
  final String? header;

  /// Extra import statements for model files.
  final List<String> modelImports;

  /// Extra import statements for client files.
  final List<String> clientImports;

  /// Extra import statements for provider files.
  final List<String> providerImports;

  const TemplateConfig({
    this.header,
    this.modelImports = const [],
    this.clientImports = const [],
    this.providerImports = const [],
  });

  factory TemplateConfig.fromYaml(YamlMap yaml) {
    return TemplateConfig(
      header: yaml['header'] as String?,
      modelImports: _parseStringList(yaml['model_imports']),
      clientImports: _parseStringList(yaml['client_imports']),
      providerImports: _parseStringList(yaml['provider_imports']),
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return const [];
    if (value is YamlList) {
      return value.map((e) => e.toString()).toList();
    }
    return const [];
  }
}
