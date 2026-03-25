# florval

[![Pub Version](https://img.shields.io/pub/v/florval)](https://pub.dev/packages/florval)
[![Dart](https://img.shields.io/badge/Dart-%3E%3D3.9-blue)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Generate type-safe Flutter/Dart API clients from OpenAPI specs — with status-code-level response handling, Riverpod integration, and cursor-based pagination.**

Inspired by [orval](https://orval.dev) for React. florval brings the same level of automation to Flutter: one command turns your OpenAPI spec into production-ready Dart code.

## Why florval?

Most OpenAPI code generators for Flutter treat every response as a single success type. Real APIs return **different shapes for different status codes** — 200 returns a `User`, 404 returns nothing, 422 returns `ValidationError`.

florval generates **freezed sealed classes** so you can pattern-match on every status code with Dart 3 switch expressions:

```dart
final response = await client.getUser(id: 42);

switch (response) {
  case GetUserResponseSuccess(:final data) => Text(data.name),
  case GetUserResponseNotFound()           => Text('User not found'),
  case GetUserResponseServerError(:final data) => Text(data.message),
  case GetUserResponseUnknown(:final statusCode) => Text('Unexpected: $statusCode'),
}
```

No more `try/catch` guessing. No more `response.statusCode == 200` checks.

## Features

- **Status-code Union types** — freezed sealed classes for every endpoint response
- **freezed 3.x models** — immutable data classes with `copyWith`, JSON serialization
- **dio clients** — clean HTTP clients, no Retrofit, full control over your Dio instance
- **Riverpod 3.x integration** — Notifiers for GET, Mutation API for POST/PUT/DELETE
- **Cursor-based pagination** — `fetchMore()` with automatic data accumulation
- **Auto-invalidation** — mutations automatically refresh related GET providers
- **Retry** — `@Riverpod(retry:)` generation from config
- **OpenAPI 3.0 & 3.1** — v3.0 specs are normalized to v3.1 automatically
- **multipart/form-data** — file uploads with `MultipartFile` support
- **Watch mode** — auto-regenerate on spec file changes
- **Zero runtime dependency** — generated code depends only on dio, freezed, and optionally Riverpod

## Quick Start

### 1. Install

Add florval as a dev dependency:

```yaml
dev_dependencies:
  florval: ^0.1.0
```

### 2. Initialize

```bash
dart run florval init
```

This creates a `florval.yaml` config file. Edit `schema_path` to point to your OpenAPI spec.

### 3. Generate

```bash
dart run florval generate
```

### 4. Build

```bash
dart run build_runner build --delete-conflicting-outputs
```

This runs freezed, json_serializable, and riverpod_generator on the generated code.

### Generated output

```
lib/api/generated/
├── models/           # freezed data classes
├── responses/        # status-code Union types (sealed classes)
├── clients/          # dio API clients (grouped by tag)
├── providers/        # Riverpod Notifiers & Mutations (optional)
└── api.dart          # barrel file
```

## Generated Code

### Models

```dart
@freezed
abstract class Pet with _$Pet {
  const factory Pet({
    required int id,
    required String name,
    String? tag,
    Category? category,
  }) = _Pet;

  factory Pet.fromJson(Map<String, dynamic> json) => _$PetFromJson(json);
}
```

### Status-Code Union Types

```dart
@freezed
sealed class GetPetResponse with _$GetPetResponse {
  const factory GetPetResponse.success(Pet data) = GetPetResponseSuccess;
  const factory GetPetResponse.notFound() = GetPetResponseNotFound;
  const factory GetPetResponse.serverError(Error data) = GetPetResponseServerError;
  const factory GetPetResponse.unknown(int statusCode, dynamic body) = GetPetResponseUnknown;
}
```

### Dio Client

```dart
class PetsApiClient {
  final Dio _dio;

  PetsApiClient(this._dio);

  Future<GetPetResponse> getPet({required int petId}) async {
    try {
      final response = await _dio.get('/pets/$petId');
      return switch (response.statusCode) {
        200 => GetPetResponse.success(Pet.fromJson(response.data)),
        404 => GetPetResponse.notFound(),
        500 => GetPetResponse.serverError(Error.fromJson(response.data)),
        _ => GetPetResponse.unknown(response.statusCode!, response.data),
      };
    } on DioException catch (e) {
      if (e.response != null) { /* error status code handling */ }
      rethrow;
    }
  }
}
```

You provide your own `Dio` instance — configure base URL, interceptors, retry, and auth however you like.

### Riverpod Providers (optional)

**GET → Notifier:**

```dart
@Riverpod(retry: _retry)
class GetPet extends _$GetPet {
  @override
  FutureOr<GetPetResponse> build({required int petId}) async {
    final client = ref.watch(petsApiClientProvider);
    return client.getPet(petId: petId);
  }
}
```

**POST/PUT/DELETE → Mutation:**

```dart
final createPet = Mutation<CreatePetResponse>();
```

**Auto-invalidation helper (opt-in):**

```dart
Future<CreatePetResponse> runCreatePet(
  MutationTarget ref, {required CreatePetRequest body}
) async {
  return createPet.run(ref, (tsx) async {
    final client = tsx.get(petsApiClientProvider);
    final result = await client.createPet(body: body);
    ref.container.invalidate(listPetsProvider);
    return result;
  });
}
```

### Cursor-Based Pagination

Configure in `florval.yaml`:

```yaml
riverpod:
  pagination:
    - operation_id: listPets
      cursor_param: after
      next_cursor_field: nextCursor
      items_field: items
```

Generated Notifier with `fetchMore()`:

```dart
@Riverpod(retry: _retry)
class ListPets extends _$ListPets {
  @override
  FutureOr<PaginatedData<Pet>> build() async { /* initial fetch */ }

  Future<void> fetchMore() async { /* loads next page, appends to list */ }
}
```

## Configuration

Full `florval.yaml` reference:

```yaml
florval:
  schema_path: openapi.yaml              # Required. Path to OpenAPI spec.
  output_directory: lib/api/generated     # Output directory.

  client:
    base_url_env: API_BASE_URL            # Env var name for base URL.
    timeout: 30000                        # Request timeout (ms).

  riverpod:
    enabled: false                        # Generate Riverpod providers.
    auto_invalidate: false                # Invalidate GET providers after mutations.
    retry:                                # Riverpod-level retry for GET providers.
      max_attempts: 3
      delay: 1000                         # Initial delay (ms), linear backoff.
    pagination:                           # Cursor-based pagination endpoints.
      - operation_id: listItems
        cursor_param: after
        next_cursor_field: nextCursor
        items_field: items

  templates:
    header: null                          # Custom header for generated files.
    model_imports: []                     # Extra imports for model files.
    client_imports: []                    # Extra imports for client files.
    provider_imports: []                  # Extra imports for provider files.
```

## CLI

```bash
# Generate config template
dart run florval init
dart run florval init --config custom.yaml --force

# Generate code
dart run florval generate
dart run florval generate --config custom.yaml
dart run florval generate --schema api.yaml --output lib/api/
dart run florval generate --watch
dart run florval generate --verbose
```

## Requirements

### Your project's dependencies

```yaml
dependencies:
  dio: ^5.0.0
  freezed_annotation: ^3.0.0
  json_annotation: ^4.0.0
  # Only if riverpod.enabled: true
  riverpod: ^3.0.0
  riverpod_annotation: ^3.0.0

dev_dependencies:
  build_runner: ^2.4.0
  freezed: ^3.0.0
  json_serializable: ^6.0.0
  # Only if riverpod.enabled: true
  riverpod_generator: ^3.0.0
  florval: ^0.1.0
```

## OpenAPI Version Support

| Version | Support |
|---------|---------|
| OpenAPI 3.1 | Full |
| OpenAPI 3.0 | Full (auto-normalized to 3.1) |
| Swagger 2.0 | Partial (auto-normalized to 3.1) |

## License

MIT
