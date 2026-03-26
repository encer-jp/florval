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
