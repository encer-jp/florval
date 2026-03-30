## 0.2.2

### Improvements
- Update package description to be more concise and highlight core features (Freezed models, status-code Union types, Riverpod 3.x)
- Add encer.co.jp vision statement to README

## 0.2.1

### Features
- **Inline enum generation**: Generate Dart enums from inline OpenAPI `enum` properties, instead of requiring top-level schema definitions
- **`readOnly` / `writeOnly` support**: Read OpenAPI `readOnly` and `writeOnly` flags on schema fields and propagate them to the intermediate representation
- **Doc comments and example output**: Generate `///` doc comments from OpenAPI `description` fields and `/// Example: ...` from `example` values on models, fields, enums, and endpoints
- **`default` value support**: Read OpenAPI `default` values and generate `@Default(...)` annotations in freezed models. Supports string, integer, number, boolean, empty array, and enum types. DateTime and non-empty array defaults emit a warning and are skipped. Fields with both `required` and `default` use `@Default(...)` (freezed does not allow both)
- **`deprecated` flag support**: Read OpenAPI `deprecated` flags at schema, property, operation, and parameter levels and generate `@Deprecated('')` annotations. Schema-level deprecated applies to class/enum definitions; property-level deprecated applies to individual fields; operation/parameter-level deprecated applies to client methods and their parameters
- **Schema title fallback for doc comments**: Use schema `title` as doc comment when `description` is not available

### Bug Fixes
- **Preserve properties in `_applyAbsentable`**: Fix `example`, `readOnly`, and `writeOnly` fields being lost when `_applyAbsentable` transforms optional fields for PATCH/PUT request bodies
- **Operation/Parameter deprecated field name**: Fix incorrect property name used when reading the `deprecated` flag from Operation and Parameter objects
- **Null safety in doc comment generation**: Fix null safety operator for `description` and `example` in doc comment generation

## 0.2.0

### Breaking Changes
- Rename response Union types from `{Op}Response` to `{Op}ApiResponse` to structurally resolve name collisions with model classes
- Switch response Union types from freezed to plain Dart sealed classes (copyWith/equality/fromJson not needed, eliminates build_runner dependency for response types)

### Features
- **JsonOptional\<T\> for PATCH/PUT partial updates**: Generate `JsonOptional<T>` sentinel type that distinguishes "key absent" (unchanged) from "key is null" (clear value) at the type level. Optional fields in PATCH/PUT request bodies are wrapped in `JsonOptional<T>` with `@Default(JsonOptional<T>.absent())`. Custom `fromJson` uses `json.containsKey()` for 3-state restoration; custom `toJson` excludes absent keys. `@Freezed(fromJson: false, toJson: false)` bypasses json_serializable entirely for absentable schemas. POST request bodies and response models are unaffected.
- **Inline anyOf/oneOf union type support**: Detect anyOf/oneOf declared inline within schema properties and automatically generate Union types for them
- **Restore freezed for discriminator union types**: Generate `@Freezed(unionKey: '...')` + `@FreezedUnionValue('...')` with variant fields inlined into factory constructors
- **Non-discriminator union fromJson/toJson**: For oneOf/anyOf without a discriminator, generate fromJson that tries each variant sequentially and toJson that branches on runtimeType
- **Logger warnings**: Emit warnings when an array type is missing `items` or when an unsupported content-type is encountered

### Bug Fixes
- **anyOf/oneOf nullable `$ref` pattern**: Fix `anyOf: [{$ref: '#/.../Foo'}, {type: 'null'}]` incorrectly resolving to `Map<String, dynamic>` instead of a nullable type
- **additionalProperties typed Map**: Generate correct `Map<String, T>` type when `additionalProperties` specifies a schema
- **ResponseAnalyzer nullable anyOf**: Fix false detection of nullable anyOf patterns during response analysis
- **`_extractType` dynamic fallback**: Fix dynamic fallback handling when type extraction fails
- **Inline object fallback**: Fix inline object schemas incorrectly falling back to `Map<String, dynamic>` instead of generating proper types
- **Inline oneOf/anyOf responses**: Fix inline oneOf/anyOf in endpoint response definitions falling back to `Map<String, dynamic>`
- **allOf + nullable `$ref`**: Fix resolution of nullable `$ref` entries within allOf compositions
- **`List<dynamic>` type error**: Fix type inference error in `florval_runner` schemas variable
- **Name collision structural fix**: Resolve response Union type vs. model class name collisions using import prefix splitting and barrel file separation
- **`json_serializable` sealed class error**: Fix `json_serializable` errors on sealed class fields with discriminator
- **`.g.dart` part directive exclusion**: Skip unnecessary `.g.dart` part directive generation for sealed classes with discriminator
- **Library import prefix lint**: Remove leading underscores from generated import prefixes to fix `no_leading_underscores_for_library_prefixes` lint violation
- **`includeIfNull: false` revert**: Revert `@JsonSerializable(includeIfNull: false)` addition due to incompatibility with demo-api default values; fix applied on API side instead

### Refactoring
- **Analyzers as pure functions**: Convert `SchemaAnalyzer`, `EndpointAnalyzer`, and `ResponseAnalyzer` to stateless pure functions for improved testability (+477/-305 lines)
- **FlorvalRunner phase splitting**: Clearly separate Parse → Resolve → Analyze → Generate → Write phases with an `AnalysisResult` intermediate representation
- **Generator layer deduplication**: Extract shared status code conversion and import collection logic from `client_generator` / `response_generator` into `utils/status_code.dart` and `utils/import_collector.dart` (+72/-115 lines)
- **Import deduplication**: Reduce unnecessary import generation in provider generator
- **Test readability improvements**: Unify formatting and structure in `model_generator_test`, remove unnecessary forced unwraps in `response_analyzer_test`
- **Deduplicate toJson serialization logic**: Unify `_writeToJsonField` and `_toJsonValueExpression` in ModelGenerator — `_writeToJsonField` now delegates to `_toJsonValueExpression`, eliminating duplicated type-dispatch logic (DateTime, enum, List, reference types)
- **Barrel file separation**: Exclude `api_responses.dart` from `api.dart` re-exports, keeping only models/clients/providers

### Demo / Example
- **Add demo-api server**: Hono + @hono/zod-openapi based mock API server with full endpoint coverage (auth, CRUD, file upload, notifications)
- **Add Flutter Web project**: Flutter Web example app connecting to demo-api at localhost:3000
- **Add CLI verification script**: `example/lib/verify.dart` for integration testing against demo-api
- **Update example generated code**: Regenerate all code based on demo-api OpenAPI spec (6 tags, 15 response types, 35 models)
- **Remove unused files**: Delete petstore-derived API client, model, provider, and response files

## 0.1.1

### Bug Fixes
- Fix mutation helpers missing query parameters
- Fix List request body calling `toJson()` which doesn't exist on `List`
- Fix empty-property schema causing `build_runner` error
- Fix double `??` in generated nullable optional parameters
- Fix null-aware operator on enum query params inside null-check guard
- Fix Schema enum property name: `$enum` → `enumValues`

### Improvements
- Expand Riverpod reserved name handling with generated super params
- Rename Riverpod reserved param names in generated providers
- Handle non-ASCII characters in field names and enum values
- Generate mutation helper functions even when no GET endpoints exist in tag
- Remove unnecessary `dart:async` import from generated providers
- Skip unused request body imports in mutation-only providers
- Always generate `part` directive and `riverpod_annotation` import in providers

### Other
- Remove deprecated pagination examples and related schemas from openapi.yaml

## 0.1.0

- Initial release
- OpenAPI 3.0 / 3.1 spec parsing with automatic v3.0 → v3.1 normalization
- Swagger 2.0 partial support (auto-normalized to 3.1)
- `$ref` resolution with circular reference detection
- freezed 3.x data model generation (abstract class)
- Status-code Union type generation (freezed sealed class)
- Dart 3 switch expression support (no when/map)
- dio API client generation (no Retrofit dependency)
- DioException handling with status-code routing
- Riverpod 3.x provider generation (optional)
  - GET → `@riverpod` Notifier with build() parameters
  - POST/PUT/DELETE/PATCH → `Mutation<T>()` constants
  - Auto-invalidation of GET providers after mutations
  - `@Riverpod(retry:)` support from config
- Cursor-based pagination with `fetchMore()` and `PaginatedData<T>`
- multipart/form-data support with `MultipartFile`
- oneOf / anyOf / allOf / discriminator support
- Watch mode for auto-regeneration on spec changes
- `florval init` command for config template generation
- `florval.yaml` configuration with validation
- Custom template headers and imports
- Tag-based endpoint grouping
- Barrel file generation
