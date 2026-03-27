# florval - CLAUDE.md

## プロジェクト概要

florvalは、OpenAPI仕様からFlutter/Dart向けの型安全なAPIクライアントコードを自動生成するCLIツールである。
名前はFlutter + orvalに由来する。orval（React/TypeScript向け）のFlutter版として、Flutter圏に欠落しているAPI層の自動化を実現する。

## 技術スタック

- **言語**: Dart
- **パーサー**: openapi_spec_plus（OpenAPI v2.0/v3.0/v3.1対応）
- **HTTP**: dio（Retrofitは使わない。florval自体がコード生成ツールのため二重生成になる）
- **モデル生成**: freezed 3.x（abstract class + sealed class。when/mapは廃止、Dart 3 switch式を使用）
- **状態管理**: riverpod 3.x（自動リトライ内蔵、Mutation実験的サポート、FamilyNotifier廃止）
- **CLI**: dart標準のargs パッケージ

## アーキテクチャ原則

### 1. パーサーとジェネレーターの完全分離
- openapi_spec_plusはOpenAPI仕様のDart POJO変換のみに使用する
- $ref解決はflorval内で自前実装する（単純なMap参照で実装可能）
- コード生成ロジックはすべてflorval独自のテンプレートエンジンで行う

### 2. Retrofitを使わない理由
- florval自体がコード生成ツールであり、Retrofitのアノテーション生成→build_runnerで再生成という二重構造は不要
- dioを直接呼ぶコードを生成することで、リトライ・インターセプター・ステータスコード分岐をflorvalのテンプレートで完全制御する

### 3. ステータスコード別型分岐（最大の差別化ポイント）
- OpenAPIのresponsesセクションから全ステータスコード（200, 400, 401, 422, 500等）のスキーマを抽出
- freezedのsealed class（Union型）として生成
- dioのレスポンスをステータスコードで自動的に正しい型へ振り分ける

### 4. 生成コードの品質基準
- 生成されたコードは人間が読んで理解できること
- dart analyzeでwarning/errorが出ないこと
- 生成コードのみでbuild_runnerを実行してfreezed/json_serializableの生成が通ること

## ディレクトリ構成

```
florval/
├── bin/
│   └── florval.dart              # CLIエントリーポイント
├── lib/
│   ├── src/
│   │   ├── config/               # florval.yaml設定の読み込み
│   │   │   └── florval_config.dart
│   │   ├── parser/               # OpenAPI仕様のパース・$ref解決
│   │   │   ├── spec_reader.dart       # openapi_spec_plusのラッパー
│   │   │   └── ref_resolver.dart      # $ref解決
│   │   ├── analyzer/             # パース結果の分析・中間表現への変換
│   │   │   ├── schema_analyzer.dart   # スキーマ→型情報への変換
│   │   │   ├── endpoint_analyzer.dart # エンドポイント情報の抽出
│   │   │   └── response_analyzer.dart # ステータスコード別レスポンスの抽出
│   │   ├── model/                # florval内部の中間表現
│   │   │   ├── api_endpoint.dart
│   │   │   ├── api_response.dart      # ステータスコード別レスポンス型
│   │   │   ├── api_schema.dart
│   │   │   └── api_type.dart
│   │   ├── generator/            # Dartコード生成
│   │   │   ├── model_generator.dart       # freezedモデル生成
│   │   │   ├── client_generator.dart      # dioクライアント生成
│   │   │   ├── provider_generator.dart    # riverpodプロバイダー生成
│   │   │   ├── response_generator.dart    # ステータスコード別Union型生成
│   │   │   └── template/                  # 生成テンプレート
│   │   └── utils/
│   └── florval.dart              # ライブラリエクスポート
├── test/
├── pubspec.yaml
├── CLAUDE.md                     # このファイル
├── DESIGN.md                     # 詳細設計書
└── florval.yaml.example          # 設定ファイルサンプル
```

## 設定ファイル仕様（florval.yaml）

```yaml
florval:
  schema_path: openapi.yaml          # OpenAPI仕様ファイルパス
  output_directory: lib/api/generated # 出力先ディレクトリ
  
  # モデル設定
  model:
    serializer: freezed               # MVP: freezed固定
    
  # クライアント設定
  client:
    base_url_env: API_BASE_URL        # 環境変数名
    timeout: 30000                    # デフォルトタイムアウト(ms)
    retry:
      max_attempts: 3
      delay: 1000                     # 初回リトライまでの待機(ms)
      
  # Riverpod設定
  riverpod:
    enabled: true
    auto_invalidate: true             # 自動リフレッシュ
```

## 生成コードの理想形

### 1. freezedモデル（成功レスポンス） - Freezed 3.x Mixed Mode
```dart
@freezed
abstract class User with _$User {
  const factory User({
    required int id,
    required String name,
    String? email,
  }) = _User;
  
  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
```
※ Freezed 3.xでは単純なデータクラスは`abstract class`を使用。`sealed`はUnion型のみ。

### 2. ステータスコード別Union型 - Freezed 3.x sealed class
```dart
@freezed
sealed class GetUserApiResponse with _$GetUserApiResponse {
  const factory GetUserApiResponse.success(User data) = GetUserApiResponseSuccess;
  const factory GetUserApiResponse.badRequest(ValidationError error) = GetUserApiResponseBadRequest;
  const factory GetUserApiResponse.unauthorized(UnauthorizedError error) = GetUserApiResponseUnauthorized;
  const factory GetUserApiResponse.notFound() = GetUserApiResponseNotFound;
  const factory GetUserApiResponse.serverError(ServerError error) = GetUserApiResponseServerError;
  const factory GetUserApiResponse.unknown(int statusCode, dynamic body) = GetUserApiResponseUnknown;
}
```
※ when/mapは廃止済み。利用側ではDart 3のswitch式でパターンマッチングする：
```dart
final response = await client.getUser(id: 1);
switch (response) {
  case GetUserApiResponseSuccess(:final data):
    // 成功処理
  case GetUserApiResponseBadRequest(:final error):
    // バリデーションエラー処理
  case GetUserApiResponseUnknown(:final statusCode, :final body):
    // 未知のエラー
}
```
```

### 3. dioクライアント
```dart
class UserApiClient {
  final Dio _dio;
  
  UserApiClient(this._dio);
  
  Future<GetUserApiResponse> getUser({required int id}) async {
    try {
      final response = await _dio.get('/users/$id');
      switch (response.statusCode) {
        case 200:
          return GetUserApiResponse.success(User.fromJson(response.data));
        case 400:
          return GetUserApiResponse.badRequest(ValidationError.fromJson(response.data));
        case 401:
          return GetUserApiResponse.unauthorized(UnauthorizedError.fromJson(response.data));
        case 404:
          return GetUserApiResponse.notFound();
        default:
          return GetUserApiResponse.unknown(response.statusCode ?? 0, response.data);
      }
    } on DioException catch (e) {
      if (e.response != null) {
        return _handleErrorResponse(e.response!);
      }
      rethrow;
    }
  }
}
```

### 4. Riverpodプロバイダー（Riverpod 3.x）

GET用（従来通りNotifier）:
```dart
@riverpod
class GetUser extends _$GetUser {
  @override
  FutureOr<GetUserApiResponse> build({required int id}) async {
    final client = ref.watch(userApiClientProvider);
    return client.getUser(id: id);
  }
}
```

POST/PUT/DELETE用（Mutation API）:
```dart
/// Mutation for createUser (POST /users)
final createUserMutation = Mutation<CreateUserApiResponse>();
```

autoInvalidate有効時のヘルパー関数:
```dart
/// Executes createUser mutation and invalidates related GET providers.
Future<CreateUserApiResponse> createUser(
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

※ Riverpod 3.xでは以下が標準化：
- FamilyNotifierは廃止。Notifierに統合（buildのパラメータでfamily化）
- 自動リトライがビルトイン（ProviderScopeのretryで設定可能）
- Mutation APIでPOST/PUT/DELETEの状態管理（`Mutation<T>()`定数 + `run()`で実行）

## コーディング規約

- Dart公式スタイルガイドに準拠
- `dart analyze`で警告ゼロ
- `dart format`適用済み
- テストカバレッジ: パーサー・ジェネレーター共に単体テスト必須
- 生成コードのE2Eテスト: petstore.yamlを入力として生成→ビルド→テスト

## 開発フロー

1. openapi_spec_plusでOpenAPI仕様をパース
2. $refを解決して完全なスキーマツリーを構築
3. 中間表現（api_endpoint, api_response等）に変換
4. 中間表現からDartコードを生成
5. 生成コードをファイルに出力

## 注意事項

- openapi_spec_plusの`Operation.responses`は`Map<String, Response>`でキーがステータスコード文字列（"200", "400"等）
- `Response.content`は`Map<String, MediaType>`でcontent-type別
- `Schema.ref`には`$ref`文字列がそのまま入る（`#/components/schemas/User`形式）
- `Schema`には`oneOf`, `anyOf`, `allOf`, `discriminator`がすべて定義済み
- openapi_spec_plusは$ref解決を自動で行わないため、florval側で実装が必要
