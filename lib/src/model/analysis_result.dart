import 'api_endpoint.dart';
import 'api_schema.dart';
import 'api_type.dart';

/// schemaToType の戻り値。型情報と副次的に発見されたインラインスキーマを含む。
class TypeResult {
  final FlorvalType type;
  final List<FlorvalSchema> inlineUnionSchemas;
  final List<FlorvalSchema> inlineObjectSchemas;
  final List<FlorvalSchema> inlineEnumSchemas;

  const TypeResult({
    required this.type,
    this.inlineUnionSchemas = const [],
    this.inlineObjectSchemas = const [],
    this.inlineEnumSchemas = const [],
  });
}

/// analyze (単一スキーマ) の戻り値。
class SchemaResult {
  final FlorvalSchema schema;
  final List<FlorvalSchema> inlineUnionSchemas;
  final List<FlorvalSchema> inlineObjectSchemas;
  final List<FlorvalSchema> inlineEnumSchemas;

  const SchemaResult({
    required this.schema,
    this.inlineUnionSchemas = const [],
    this.inlineObjectSchemas = const [],
    this.inlineEnumSchemas = const [],
  });
}

/// analyzeAll の戻り値。全コンポーネントスキーマの分析結果を集約。
class SchemaAnalysisResult {
  final List<FlorvalSchema> schemas;
  final List<FlorvalSchema> inlineUnionSchemas;
  final List<FlorvalSchema> inlineObjectSchemas;
  final List<FlorvalSchema> inlineEnumSchemas;

  const SchemaAnalysisResult({
    required this.schemas,
    this.inlineUnionSchemas = const [],
    this.inlineObjectSchemas = const [],
    this.inlineEnumSchemas = const [],
  });
}

/// Analyzeフェーズ全体の結果。FlorvalRunner が使用する。
class AnalysisResult {
  final List<FlorvalSchema> schemas;
  final List<FlorvalEndpoint> endpoints;
  final List<FlorvalSchema> inlineUnionSchemas;
  final List<FlorvalSchema> inlineObjectSchemas;
  final List<FlorvalSchema> inlineEnumSchemas;

  const AnalysisResult({
    required this.schemas,
    required this.endpoints,
    required this.inlineUnionSchemas,
    required this.inlineObjectSchemas,
    this.inlineEnumSchemas = const [],
  });
}
