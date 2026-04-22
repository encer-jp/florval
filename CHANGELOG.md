## 0.3.5

### Bug Fixes
- **Wrap single-statement `if` blocks in braces**: The `_isComplexObjectField` method had `if` statements with single-line return statements, triggering the `curly_braces_in_flow_control_structures` Dart lint. All `if` statements now properly wrap their bodies in braces for full lint compliance

## 0.3.4

### Bug Fixes
- **Apply `JsonOptional<T>` to DTO schemas referenced from `multipart/form-data` PATCH/PUT endpoints**: When a PATCH/PUT endpoint used `multipart/form-data` with a complex object form field (e.g. `updateUserDto: {$ref: '#/components/schemas/UpdateUserDto'}` alongside a binary `iconFile`), the referenced DTO's optional fields were not wrapped in `JsonOptional<T>` because `_markAbsentableFields()` unconditionally excluded all multipart request bodies. Now iterates multipart form fields and marks any complex object DTO (named `$ref`, inline object, or `allOf`-wrapped schema) as absentable, generating proper `@Freezed(fromJson: false, toJson: false)` with `containsKey`-based 3-state fromJson/toJson

## 0.3.3

### Bug Fixes
- **Fix nullable lost on `allOf`/`$ref` schemas without `type` field**: When an OpenAPI 3.0 property used `nullable: true` with `allOf` (e.g. `nullable: true, allOf: [{$ref: '#/components/schemas/Foo'}]`), the v3.0→v3.1 normalizer silently discarded the nullable information because it only converted `nullable` when an explicit `type` field was present. Now properly converts `nullable: true` to `type: ['null']` for all schemas, ensuring nullable `$ref` properties generate `T?` instead of `required T`

## 0.3.2

### Bug Fixes
- **Serialize complex object fields in `multipart/form-data` as JSON**: Non-binary complex types (`$ref` or object schemas) in multipart form fields were passed directly to `FormData.fromMap()`, causing dio to call `.toString()` instead of properly serializing the data. Now generates `MultipartFile.fromString(jsonEncode(dto.toJson()), contentType: MediaType('application', 'json'))` for such fields. Also handles enum fields with `.jsonValue` and list-of-enum fields with `.map((e) => e.jsonValue).toList()`. Conditionally adds `dart:convert` and `http_parser` imports only when complex multipart fields are present

## 0.3.1

### Features
- **`exclude_auto_invalidate` option**: Skip auto-invalidation for specific mutations by operationId. Useful for optimistic updates or mutations where cache invalidation should be handled manually. Configure via `riverpod.exclude_auto_invalidate` list in `florval.yaml`

## 0.3.0

### Breaking Changes
- **Centralize API Dio provider**: Generate a single `apiDioProvider` instead of per-tag client providers that throw `UnimplementedError`. Each client provider now uses `ref.watch(apiDioProvider)` to obtain its Dio instance. Users only need one override in `ProviderScope` instead of N per-tag overrides. Migration: replace individual client provider overrides with `apiDioProvider.overrideWithValue(yourDio)`

## 0.2.13

### Bug Fixes
- **Add missing imports for multipart form field `$ref` types**: When a `multipart/form-data` request body contained fields referencing `$ref` types (e.g. `UpdateUserDto`), the generated provider and client files did not include import statements for those model types, causing `Undefined class` errors. Both `_collectModelImports()` methods now iterate `formFields` to collect imports for multipart requests

## 0.2.12

### Bug Fixes
- **Fix multipart form `$ref` fields resolving to wrong type name**: When a `multipart/form-data` request body contained a field with `$ref` (e.g. `updateUserDto: $ref: '#/components/schemas/UpdateUserDto'`), the generated code produced an incorrect contextName-based type like `UserControllerUpdateV1UpdateUserDto` instead of the referenced `UpdateUserDto`. The cause was `resolveSchema()` being called too early, stripping the `$ref` before `schemaToType` could detect it

## 0.2.11

### Bug Fixes
- **Promote inline enums everywhere and serialize params via `jsonValue`**: Inline `enum` schemas (e.g. `type: string, enum: [...]` written directly in a parameter, request body, multipart form field, array element, `additionalProperties`, or pagination wrapper field) were silently generated as `String`/`int` because `SchemaAnalyzer.schemaToType` needs a `contextName` to name the anonymous enum and several call sites did not pass one. `contextName` is now required, with a documented naming convention (`${OperationId}${ParamName}` for params, `${ParentContext}Item` / `${ParentContext}Value` for array/map children, etc.), so every call site articulates a name and inline enums are always promoted to first-class Dart `enum` types
- **Serialize enum query/path parameters via `.jsonValue` instead of `.name`**: The generated client used `.name` (the Dart identifier) for enum query params and relied on `toString()` for enum path params. For enum values whose OpenAPI string differs from the Dart identifier (e.g. `"in-progress"` → `inProgress`) this produced the wrong value on the wire. Switch to `.jsonValue`, which returns the original OpenAPI string, and interpolate enum path params as `${x.jsonValue}`

## 0.2.10

### Bug Fixes
- **Always generate mutation helper functions regardless of `autoInvalidate`**: When `auto_invalidate` was `false`, mutation helper functions were not generated at all. Now helpers are always generated — `autoInvalidate` only controls whether `ref.container.invalidate()` calls are included

## 0.2.9

### Bug Fixes
- **Add braces to retry function `if`-statement**: Single-line `if (...) return null;` triggers the `statement_on_same_line` Dart lint. Wrap in braces for compliance

## 0.2.8

### Bug Fixes
- **Remove unnecessary `async` from GET provider `build()` methods**: The `build()` methods in GET providers just return `client.methodName()` without `await`, so the `async` modifier was unnecessary and triggered the `unnecessary_async` Dart lint warning

## 0.2.7

### Bug Fixes
- **Remove unnecessary `async` from mutation helper functions**: The outer helper functions just return `mutation.run()` without `await`, so the `async` modifier was unnecessary and triggered the `unnecessary_async` Dart lint warning

## 0.2.6

### Bug Fixes
- **Fix dio method calls to use explicit type arguments**: Add explicit type parameters (e.g., `<Map<String, dynamic>>`, `<dynamic>`) to all generated `dio.get()`, `dio.post()`, `dio.put()`, `dio.patch()`, and `dio.delete()` calls for improved type safety. Calls without a response body now use `<dynamic>` instead of `<void>` to match dio's expected return type

## 0.2.5

### Features
- **Paginated `fetchMore` as Mutation pattern**: Convert paginated provider's `fetchMore()` to Riverpod 3.x Mutation pattern. The Notifier now exposes `loadNextPage()` as an internal state-management method, while an external `Mutation<PaginatedData<T, P>>()` constant and `fetchMoreXxx(MutationTarget ref)` helper function are generated alongside it. This enables `MutationState`-based duplicate call prevention and loading state tracking from the UI
- **Dot-notated `next_cursor_field` in pagination config**: Support nested field paths like `pagination.nextCursor` in `florval.yaml` pagination config. The analyzer resolves dot-separated segments through nested schema properties (including `allOf`-wrapped `$ref`), and the generator emits chained property access (e.g., `data.pagination.nextCursor`)

### Bug Fixes
- **Fix `PaginatedData<dynamic, ...>` type inference in `loadNextPage()`**: Add explicit type parameters to `PaginatedData<T, P>(...)` constructor calls in generated paginated providers. Without them, Dart's type inference falls back to `dynamic` when the `PaginatedData` result is assigned to a local variable before being passed to `state = AsyncData(result)`
- **Fix Family provider `.notifier` access in paginated Mutation helpers**: Pass build parameters (path/query params) through to the Mutation helper function so it can construct the correct Family provider instance (e.g., `xxxProvider(eventId: eventId).notifier`) instead of calling `.notifier` directly on the Family type
- **Fix `allOf`-wrapped `$ref` resolution in pagination field validation**: When validating `next_cursor_field` existence, resolve `allOf` compositions by merging properties from all entries, not just following top-level `$ref`. This fixes pagination detection for OpenAPI specs where nested objects use the common NestJS `allOf: [$ref: ...]` pattern
- **Fix `readOnly`/`writeOnly` test assertions in absentable schemas**: Test was checking the entire generated code for absence of `json['field']`, but the field correctly appeared in the counterpart method (`fromJson` for readOnly, `toJson` for writeOnly). Narrow assertions to check only the relevant method body

### Refactoring
- Move `_dotFieldAccess` from top-level private function to `ProviderGenerator` static method
- Fix E2E test assertion for Mutation constant that was broken by `dart format` line wrapping

## 0.2.4

### Features
- **Auto-apply `dart fix` and `dart format` on generated code**: Run `dart fix --apply` followed by `dart format` as a post-processing step after code generation. This automatically resolves lint violations (`directives_ordering`, `prefer_const_constructors`, etc.) without modifying individual generators

### Improvements
- **Reformat generated API client methods**: Improve readability and consistency of generated API client code by aligning parameters and return statements

## 0.2.3

### Bug Fixes
- **Fix ambiguous exports for union type subclass names**: Resolve `dart analyze` errors caused by union variant subclass names (e.g., `RequestDataRoomInvitation`) being exported from both the union type file and a standalone model file. Implemented 3-layer defense:
  1. Clean output directory before generation to remove stale files from previous runs
  2. Pre-filter `variantSchemaNames()` to exclude discriminator union variants from standalone model generation
  3. Barrel-level deduplication via `unionSubclassNames()` as a safety net to remove colliding names from exports
- **Fix variant schema filtering for inline unions**: Only use component schemas (not inline union schemas from response bodies) for variant filtering, preventing independent component schemas like `EventNotFoundErrorDto` from being incorrectly excluded

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
