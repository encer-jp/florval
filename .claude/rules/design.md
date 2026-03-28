# florval - DESIGN.md（詳細設計書）

## 1. 概要

florvalはOpenAPI仕様からFlutter/Dart向けAPIクライアントを自動生成するCLIツールである。

### 1.1 解決する課題

Flutter開発において、API層の構築は各プロジェクトで手作業になっている：
- dioの設定（インターセプター、タイムアウト、ベースURL切替）
- リトライロジック
- エラーレスポンスの型分岐
- Riverpodでのfetch状態管理
- ミューテーション後のキャッシュ無効化

React圏ではorval + TanStack Queryで標準化済み。Flutter圏にはこの層が存在しない。

### 1.2 ポジショニング

| ツール | 対象 | 特徴 |
|--------|------|------|
| orval | React/TS | OpenAPI → axios + TanStack Query |
| swagger_parser | Flutter | OpenAPI → Retrofit + json_serializable/freezed |
| **florval** | **Flutter** | **OpenAPI → dio + freezed + Riverpod + ステータスコード分岐** |

swagger_parserとの最大の違いは、ステータスコード別Union型生成とRiverpod統合。

---

## 2. 処理パイプライン

```
[OpenAPI YAML/JSON]
      ↓
[1. Parse] openapi_spec_plus で Dart POJO に変換
      ↓
[2. Resolve] $ref を再帰的に解決
      ↓
[3. Analyze] 中間表現（FlorvalSchema）に変換
      ↓
[4. Generate] Dart コードを文字列として生成
      ↓
[5. Write] ファイルに出力
```

---

## 3. Parse フェーズ

### 3.1 openapi_spec_plus の利用

```dart
import 'package:openapi_spec_plus/v31.dart' as v31;

final content = File('openapi.yaml').readAsStringSync();
final json = yamlToMap(content); // YAML → Map変換
final spec = v31.OpenAPI.fromJson(json);
```

### 3.2 取得できるデータ

- `spec.info` → API名、バージョン
- `spec.paths` → `Map<String, Path>` エンドポイント一覧
- `spec.components?.schemas` → `Map<String, Schema>` スキーマ定義
- `spec.paths['/users']?.get?.responses` → `Map<String, Response>` ステータスコード別レスポンス

### 3.3 バージョン対応

openapi_spec_plusはv20/v30/v31を個別モジュールとして提供。
florvalはまずv31（OpenAPI 3.1）のみ対応し、後からv30/v20を追加する。

---

## 4. Resolve フェーズ（$ref解決）

### 4.1 $ref の形式

```yaml
$ref: '#/components/schemas/User'
$ref: '#/components/responses/NotFound'
$ref: '#/components/parameters/UserId'
```

### 4.2 解決ロジック

```dart
class RefResolver {
  final v31.OpenAPI spec;
  
  v31.Schema resolveSchema(v31.Schema schema) {
    if (schema.ref == null) return schema;
    
    // '#/components/schemas/User' → 'User'
    final name = schema.ref!.split('/').last;
    final resolved = spec.components?.schemas?[name];
    if (resolved == null) throw RefResolveException(schema.ref!);
    
    // 再帰的に解決（resolved自体が$refを持つ場合）
    return resolveSchema(resolved);
  }
  
  v31.Response resolveResponse(v31.Response response) {
    if (response.ref == null) return response;
    final name = response.ref!.split('/').last;
    final resolved = spec.components?.responses?[name];
    if (resolved == null) throw RefResolveException(response.ref!);
    return resolveResponse(resolved);
  }
}
```

### 4.3 循環参照の検出

```dart
Schema resolveSchema(Schema schema, {Set<String>? visited}) {
  visited ??= {};
  if (schema.ref != null) {
    if (visited.contains(schema.ref)) {
      // 循環参照 → nullable型として扱う
      return schema;
    }
    visited.add(schema.ref!);
  }
  // ... 解決処理
}
```

---

## 5. Analyze フェーズ（中間表現）

### 5.1 中間表現モデル

```dart
/// エンドポイント情報
class FlorvalEndpoint {
  final String path;           // '/users/{id}'
  final String method;         // 'GET'
  final String operationId;    // 'getUser'
  final List<FlorvalParam> parameters;
  final FlorvalRequestBody? requestBody;
  final Map<int, FlorvalResponse> responses; // ステータスコード → レスポンス
  final List<String> tags;
}

/// レスポンス情報（ステータスコード別）
class FlorvalResponse {
  final int statusCode;
  final String? description;
  final FlorvalType? type;     // レスポンスボディの型（nullならbodyなし）
}

/// 型情報
class FlorvalType {
  final String name;           // 'User', 'List<User>', 'String'
  final String dartType;       // Dart型文字列
  final bool isNullable;
  final bool isList;
  final FlorvalType? itemType; // List の場合の要素型
  final String? ref;           // 元の$ref（スキーマ名特定用）
}

/// スキーマ情報（モデル生成用）
class FlorvalSchema {
  final String name;
  final List<FlorvalField> fields;
  final FlorvalDiscriminator? discriminator;
  final List<FlorvalSchema>? oneOf;
  final List<FlorvalSchema>? anyOf;
  final List<FlorvalSchema>? allOf;
}

/// フィールド情報
class FlorvalField {
  final String name;
  final String jsonKey;        // JSONのキー名
  final FlorvalType type;
  final bool isRequired;
  final String? defaultValue;
  final String? description;
}
```

### 5.2 ステータスコードの分析

```dart
class ResponseAnalyzer {
  Map<int, FlorvalResponse> analyzeResponses(
    Map<String, v31.Response> responses,
    RefResolver resolver,
  ) {
    final result = <int, FlorvalResponse>{};
    
    for (final entry in responses.entries) {
      final code = _parseStatusCode(entry.key); // '200' → 200, '2XX' → 200
      final response = resolver.resolveResponse(entry.value);
      
      FlorvalType? type;
      if (response.content != null) {
        final jsonContent = response.content!['application/json'];
        if (jsonContent?.schema != null) {
          type = _schemaToType(resolver.resolveSchema(jsonContent!.schema!));
        }
      }
      
      result[code] = FlorvalResponse(
        statusCode: code,
        description: response.description,
        type: type,
      );
    }
    
    return result;
  }
}
```

---

## 6. Generate フェーズ

### 6.1 生成ファイル一覧

1エンドポイントグループ（タグ）ごとに以下を生成：

```
lib/api/generated/
├── models/
│   ├── user.freezed.dart          # freezedモデル
│   ├── user.g.dart                # json_serializable
│   ├── validation_error.freezed.dart
│   └── ...
├── responses/
│   ├── get_user_response.dart           # ステータスコード別Union型（freezed不使用）
│   └── ...
├── clients/
│   ├── user_api_client.dart       # dioクライアント
│   └── ...
├── providers/
│   ├── user_providers.dart        # Riverpodプロバイダー
│   ├── user_providers.g.dart      # riverpod_generator
│   └── ...
├── dio_client.dart                # dio初期化・インターセプター
└── api.dart                       # バレルファイル
```

### 6.2 モデル生成（ModelGenerator）

openapi_spec_plusのSchemaから freezed クラスを生成。

**Freezed 3.x生成ルール：**
- 単純データクラス → `@freezed abstract class X with _$X`
- discriminator付きUnion型（oneOf/anyOf） → `@Freezed(unionKey: '...') sealed class X with _$X`（variant のフィールドをインライン展開、`@FreezedUnionValue`で判別値指定）
- ステータスコード別レスポンスUnion型 → plain Dart sealed class（freezed不使用、status code分岐のためJSON discriminator不要）
- 非discriminator Union型 → plain Dart sealed class（freezed不使用）
- `when/map`は生成しない（Dart 3 switch式を使用）
- Mixed Modeは使用しない（factory constructorで統一し、生成の一貫性を保つ）

型マッピング：

| OpenAPI type/format | Dart型 |
|---------------------|--------|
| string | String |
| string + date-time | DateTime |
| string + date | DateTime |
| string + uuid | String |
| string + binary | List<int> |
| integer | int |
| integer + int64 | int |
| number | double |
| number + float | double |
| number + double | double |
| boolean | bool |
| array | List<T> |
| object | Map<String, dynamic>（propertiesなし） |
| object + properties | 生成クラス |

### 6.2.1 JsonOptional生成（PATCH/PUT部分更新）

#### 背景

JSONにおける「キーが存在しない」と「キーがnullである」は異なるセマンティクスを持つ。
Dartの型システムには「undefined」に相当する概念がないため、sentinel型で3状態を表現する。

他のswaggerライブラリ（swagger_parser, openapi_generator等）は全フィールドをnullableにするだけで区別不能。florvalの差別化ポイントの一つ。

#### 生成物

```
lib/api/generated/
├── core/
│   └── json_optional.dart          ← florvalが生成するランタイム型
│   └── json_optional.freezed.dart  ← build_runnerが生成
├── models/
│   └── update_user_request.dart    ← optionalフィールドにJsonOptional適用
└── api.dart                        ← export 'core/json_optional.dart'; を含む
```

#### IR拡張

`FlorvalField`に`absentable`フラグを追加：

```dart
class FlorvalField {
  final String name;
  final String jsonKey;
  final FlorvalType type;
  final bool isRequired;
  final bool absentable;  // ← 追加
  final String? defaultValue;
  final String? description;

  const FlorvalField({
    required this.name,
    required this.jsonKey,
    required this.type,
    required this.isRequired,
    this.absentable = false,  // デフォルトfalse
    this.defaultValue,
    this.description,
  });
}
```

#### Analyzer判定ロジック

`EndpointAnalyzer`がリクエストボディのフィールドを分析する際、
エンドポイントのHTTPメソッドに基づいて`absentable`を決定：

```
absentable = !isRequired && (method == 'PATCH' || method == 'PUT')
```

POST・GETのリクエストボディ、レスポンスモデルには適用しない。

#### ModelGenerator拡張

`absentable == true`のフィールドは以下のように生成：

- 型: `JsonOptional<OriginalType>` （元の型をラップ）
- デフォルト値: `@Default(JsonOptional<OriginalType>.absent())`
- import: `core/json_optional.dart`を追加

#### toJsonカスタムconverter

freezedの標準toJsonではJsonOptionalの除外制御ができないため、
`@JsonSerializable(createToJson: false)`を指定し、手動toJsonを生成する：

```dart
@freezed
@JsonSerializable(createToJson: false)
abstract class UpdateUserRequest with _$UpdateUserRequest {
  const factory UpdateUserRequest({
    required int id,
    @Default(JsonOptional<String>.absent()) JsonOptional<String> name,
  }) = _UpdateUserRequest;

  factory UpdateUserRequest.fromJson(Map<String, dynamic> json) =>
      _$UpdateUserRequestFromJson(json);

  // florvalが生成するカスタムtoJson
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json['id'] = id;
    if (name is JsonOptionalValue<String>) {
      json['name'] = (name as JsonOptionalValue<String>).value;
    }
    return json;
  }
}
```

#### JsonOptionalのfromJson対応

JSONレスポンスからの復元時（fromJson）は：
- キーが存在しない → `JsonOptional.absent()`
- キーが存在しvalueがnull → `JsonOptional.value(null)`
- キーが存在しvalueがnon-null → `JsonOptional.value(parsedValue)`

json_serializableのカスタムconverterで対応する。

#### テスト方針

- ユニット: ModelGeneratorが`absentable`フラグに基づき正しいコードを生成するか
- ユニット: toJsonがabsentフィールドを除外、value(null)をnullとして含めるか
- ユニット: fromJsonが3状態を正しく復元するか
- E2E: PATCH/PUTエンドポイントの生成結果がbuild_runner通過→dart analyzeゼロ

### 6.3 レスポンスUnion型生成（ResponseGenerator）

// freezedは不要。パターンマッチングのみ必要なため、plain Dart sealed classで生成する。
// copyWith/equality/fromJson/toJsonはレスポンスUnion型には不要。

```dart
class ResponseGenerator {
  String generate(FlorvalEndpoint endpoint) {
    final className = '${endpoint.operationId.toPascalCase()}Response';
    final buffer = StringBuffer();

    // plain sealed class（freezed不使用）
    buffer.writeln("sealed class $className {");
    buffer.writeln("  const $className();");

    for (final entry in endpoint.responses.entries) {
      final code = entry.key;
      final response = entry.value;
      final factoryName = _statusCodeToFactoryName(code);

      if (response.type != null) {
        buffer.writeln("  const factory $className.$factoryName(${response.type!.dartType} data) = ${className}${factoryName.toPascalCase()};");
      } else {
        buffer.writeln("  const factory $className.$factoryName() = ${className}${factoryName.toPascalCase()};");
      }
    }

    // unknown fallback
    buffer.writeln("  const factory $className.unknown(int statusCode, dynamic body) = ${className}Unknown;");
    buffer.writeln("}");

    // サブクラス生成（各ステータスコードに対応）
    for (final entry in endpoint.responses.entries) {
      final factoryName = _statusCodeToFactoryName(entry.key);
      final subClassName = '${className}${factoryName.toPascalCase()}';
      if (entry.value.type != null) {
        buffer.writeln("class $subClassName extends $className {");
        buffer.writeln("  final ${entry.value.type!.dartType} data;");
        buffer.writeln("  const $subClassName(this.data);");
        buffer.writeln("}");
      } else {
        buffer.writeln("class $subClassName extends $className {");
        buffer.writeln("  const $subClassName();");
        buffer.writeln("}");
      }
    }

    return buffer.toString();
  }
}
```

### 6.4 dioクライアント生成（ClientGenerator）

生成するクライアントの特徴：
- コンストラクタでDioインスタンスを受け取る（DI可能）
- 各メソッドがステータスコード別Union型を返す
- DioExceptionをcatchしてレスポンスがあればUnion型に変換
- リトライロジックはflorval.yamlの設定に基づいて生成

### 6.5 Riverpodプロバイダー生成（ProviderGenerator）

**Riverpod 3.x対応：**
- GETエンドポイント → `@riverpod` Notifier（buildのパラメータでfamily化）
- POST/PUT/DELETE/PATCH → `Mutation<ResponseType>()`定数のみ生成。Notifierは生成しない
- autoInvalidate有効時 → `runXxx()`ヘルパー関数を生成（tsx.get()でクライアント取得、GETプロバイダー無効化）
- 自動リトライはRiverpod 3.xのビルトイン機能に委譲

生成例（GET）:
```dart
@riverpod
class GetUser extends _$GetUser {
  @override
  FutureOr<GetUserResponse> build({required int id}) async {
    final client = ref.watch(userApiClientProvider);
    return client.getUser(id: id);
  }
}
```

生成例（POST / Mutation定数）:
```dart
/// Mutation for createUser (POST /users)
final createUserMutation = Mutation<CreateUserResponse>();
```

生成例（autoInvalidate有効時のヘルパー関数）:
```dart
/// Executes createUser mutation and invalidates related GET providers.
Future<CreateUserResponse> createUser(
  MutationTarget ref, {
  required CreateUserRequest body,
}) async {
  return createUserMutation.run(ref, (tsx) async {
    final client = tsx.get(usersApiClientProvider);
    final result = await client.createUser(body: body);
    ref.container.invalidate(getUserProvider);
    ref.container.invalidate(listUsersProvider);
    return result;
  });
}
```

---

## 7. CLI仕様

```bash
# 基本コマンド
dart run florval generate

# オプション
dart run florval generate --config florval.yaml
dart run florval generate --schema openapi.yaml --output lib/api/
dart run florval init  # florval.yamlのテンプレート生成
```

---

## 8. MVP スコープ

### Phase 1（MVP）
- [x] OpenAPI 3.1 JSON/YAML パース（openapi_spec_plus）
- [x] $ref解決（components/schemas のみ）
- [x] freezedモデル生成（基本型 + object + array）
- [x] ステータスコード別Union型生成
- [x] dioクライアント生成（GET/POST/PUT/DELETE）
- [x] CLIコマンド（generate）
- [x] petstore.yamlでのE2Eテスト

### Phase 2
- [x] Riverpodプロバイダー生成
- [x] リトライロジック生成（Riverpod 3.x内蔵に委譲）
- [x] oneOf/anyOf/allOf対応
- [x] discriminator対応
- [x] ミューテーション後のキャッシュ無効化

### Phase 3
- [x] OpenAPI 3.0 / 2.0 対応
- [x] カスタムテンプレート
- [x] watch モード（仕様ファイル変更時に自動再生成）
- [x] florval.yamlのバリデーション
- [x] エラーメッセージの改善

---

## 9. 依存パッケージ

### florval本体（dev_dependency として利用される）

```yaml
dependencies:
  openapi_spec_plus: ^0.6.0   # OpenAPIパーサー
  yaml: ^3.1.0                # YAML読み込み
  args: ^2.4.0                # CLI引数パース
  path: ^1.8.0                # パス操作
  recase: ^4.1.0              # 命名変換（camelCase, PascalCase等）

dev_dependencies:
  test: ^1.24.0
  lints: ^3.0.0
```

### 生成コードの利用側が必要とするパッケージ

```yaml
dependencies:
  dio: ^5.0.0
  freezed_annotation: ^3.0.0
  json_annotation: ^4.9.0
  flutter_riverpod: ^3.0.0          # Riverpod 3.x
  riverpod: ^3.0.0                  # Mutation APIはriverpod本体に含まれる（experimental）
  riverpod_annotation: ^3.0.0       # GET用Notifierのcodegen（@riverpod）で必要

dev_dependencies:
  build_runner: ^2.4.0
  freezed: ^3.0.0                   # Freezed 3.x
  json_serializable: ^6.0.0
  riverpod_generator: ^3.0.0        # Riverpod 3.x
```

### Riverpod 3.x固有の設計判断

- **自動リトライ**: Riverpod 3.xに内蔵されたため、florvalでリトライコードを生成する必要は基本的にない。ProviderScopeのretryパラメータで制御可能。ただしflorval.yamlでカスタムリトライポリシーを定義した場合は、provider単位のretryオーバーライドとして生成する。
- **Mutation API**: POST/PUT/DELETE/PATCHは`Mutation<T>()`定数として生成。Notifierは生成しない。`Mutation<T>()`はexperimentalで、import先は`package:riverpod/experimental/mutation.dart`。安定版昇格時にimportパス変更の可能性あり。
- **autoInvalidate**: 有効時は`runXxx()`ヘルパー関数を生成。`tsx.get()`でクライアント取得、`ref.container.invalidate()`でGETプロバイダー無効化。
- **FamilyNotifier廃止**: buildメソッドのパラメータでfamily化する。florvalのGETプロバイダー生成はこの形式に準拠する。
- **state_type設定廃止**: Mutation API全面移行により、async_notifier/future_providerの選択は不要。

---

## 10. テスト戦略

### 10.1 ユニットテスト
- RefResolver: $ref解決の正確性、循環参照検出
- SchemaAnalyzer: OpenAPI型→Dart型マッピングの正確性
- ResponseAnalyzer: ステータスコード別レスポンス抽出
- 各Generator: 生成コードの文字列一致テスト

### 10.2 E2Eテスト
- petstore.yamlを入力
- florvalでコード生成
- 生成コードに対してdart analyze実行（エラーゼロ確認）
- 生成コードに対してbuild_runner実行（freezed/json_serializable生成成功確認）

### 10.3 スナップショットテスト
- 特定のOpenAPI仕様に対する生成結果をスナップショットとして保存
- 生成ロジック変更時にdiffを確認
