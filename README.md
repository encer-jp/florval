# florval

[![Pub Version](https://img.shields.io/pub/v/florval)](https://pub.dev/packages/florval)
[![Dart](https://img.shields.io/badge/Dart-%3E%3D3.9-blue)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Generate type-safe Flutter/Dart API clients from OpenAPI specs — with status-code-level response handling, Riverpod integration, and cursor-based pagination.**

Inspired by [orval](https://orval.dev) for React. florval brings the same level of automation to Flutter: one command turns your OpenAPI spec into production-ready Dart code.

---

## OpenAPI in, type-safe Dart out

### GET endpoint → Client + Riverpod provider

**Your OpenAPI spec:**

```yaml
/tasks/{id}:
  get:
    operationId: getTask
    parameters:
      - name: id
        in: path
        required: true
        schema: { type: string }
    responses:
      "200":
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/Task"
      "401":
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/UnauthorizedError"
      "404":
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/NotFoundError"
```

**florval generates** a dio client and Riverpod provider — each status code is routed to a typed variant automatically:

```dart
// clients/tasks_api_client.dart
class TasksApiClient {
  final Dio _dio;
  TasksApiClient(this._dio);

  Future<GetTaskResponse> getTask({required String id}) async {
    try {
      final response = await _dio.get('/tasks/$id');
      return switch (response.statusCode) {
        200 => GetTaskResponse.success(Task.fromJson(response.data)),
        401 => GetTaskResponse.unauthorized(UnauthorizedError.fromJson(response.data)),
        404 => GetTaskResponse.notFound(NotFoundError.fromJson(response.data)),
        _ => GetTaskResponse.unknown(response.statusCode ?? 0, response.data),
      };
    } on DioException catch (e) { /* same routing for error responses */ }
  }
}

// providers/tasks_providers.dart
@Riverpod(retry: retry)
class GetTask extends _$GetTask {
  @override
  FutureOr<GetTaskResponse> build({required String id}) async {
    final client = ref.watch(tasksApiClientProvider);
    return client.getTask(id: id);
  }
}
```

**You write** — pattern-match to get the freezed `Task` model directly:

```dart
final response = await client.getTask(id: taskId);

switch (response) {
  case GetTaskResponseSuccess(:final data)        => showTask(data), // data is Task
  case GetTaskResponseNotFound(:final data)       => showError(data.message),
  case GetTaskResponseUnauthorized(:final data)   => handleAuth(data),
  case GetTaskResponseUnknown(:final statusCode)  => showError('Error: $statusCode'),
}
```

### POST endpoint → Client + Mutation with auto-invalidation

**Your OpenAPI spec:**

```yaml
/tasks:
  post:
    operationId: createTask
    requestBody:
      required: true
      content:
        application/json:
          schema:
            $ref: "#/components/schemas/CreateTaskRequest"
    responses:
      "201":
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/Task"
      "401":
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/UnauthorizedError"
      "422":
        content:
          application/json:
            schema:
              $ref: "#/components/schemas/ValidationError"
```

**florval generates** a client method and a Mutation helper that auto-invalidates related GET providers:

```dart
// clients/tasks_api_client.dart
Future<CreateTaskResponse> createTask({required CreateTaskRequest body}) async {
  try {
    final response = await _dio.post('/tasks', data: body.toJson());
    return switch (response.statusCode) {
      201 => CreateTaskResponse.created(Task.fromJson(response.data)),
      401 => CreateTaskResponse.unauthorized(UnauthorizedError.fromJson(response.data)),
      422 => CreateTaskResponse.unprocessableEntity(ValidationError.fromJson(response.data)),
      _ => CreateTaskResponse.unknown(response.statusCode ?? 0, response.data),
    };
  } on DioException catch (e) { /* same routing for error responses */ }
}

// providers/tasks_providers.dart
final createTaskMutation = Mutation<CreateTaskResponse>();

Future<CreateTaskResponse> createTask(
  MutationTarget ref, {
  required CreateTaskRequest body,
}) async {
  return createTaskMutation.run(ref, (tsx) async {
    final client = tsx.get(tasksApiClientProvider);
    final result = await client.createTask(body: body);
    ref.container.invalidate(listTasksProvider);  // auto-invalidate GET providers
    ref.container.invalidate(getTaskProvider);
    return result;
  });
}
```

**You write:**

```dart
final response = await createTask(ref, body: CreateTaskRequest(title: 'New task'));

switch (response) {
  case CreateTaskResponseCreated(:final data)              => showTask(data), // data is Task
  case CreateTaskResponseUnprocessableEntity(:final data)  => showErrors(data.errors),
  case CreateTaskResponseUnauthorized(:final data)         => handleAuth(data),
  case CreateTaskResponseUnknown(:final statusCode)        => showError('Error: $statusCode'),
}
// listTasks and getTask providers are automatically refreshed!
```

### Schema → freezed model + inline enums

**Your OpenAPI spec:**

```yaml
Task:
  type: object
  required: [id, title, description, status, priority, assignee_id, tags, due_date, created_at, updated_at]
  properties:
    id:          { type: string, format: uuid }
    title:       { type: string }
    description: { type: string, nullable: true }
    status:      { type: string, enum: [todo, in_progress, done] }
    priority:    { type: string, enum: [low, medium, high, urgent] }
    assignee_id: { type: string, nullable: true, format: uuid }
    tags:        { type: array, items: { type: string } }
    due_date:    { type: string, nullable: true, format: date-time }
    created_at:  { type: string, format: date-time }
    updated_at:  { type: string, format: date-time }
```

**florval generates** — inline `enum` properties become dedicated Dart enums automatically:

```dart
// models/task.dart
@freezed
abstract class Task with _$Task {
  const factory Task({
    required String id,
    required String title,
    required String? description,
    required TaskStatus status,
    required TaskPriority priority,
    @JsonKey(name: 'assignee_id') required String? assigneeId,
    required User? assignee,
    required List<String> tags,
    @JsonKey(name: 'due_date') required DateTime? dueDate,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
  }) = _Task;

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);
}

// models/task_status.dart — generated from inline enum
enum TaskStatus {
  @JsonValue('todo')
  todo,
  @JsonValue('in_progress')
  inProgress,
  @JsonValue('done')
  done;

  String get jsonValue => switch (this) {
    TaskStatus.todo => 'todo',
    TaskStatus.inProgress => 'in_progress',
    TaskStatus.done => 'done',
  };

  static TaskStatus fromJsonValue(String value) =>
      values.firstWhere((e) => e.jsonValue == value);
}
```

### PUT request body → JsonOptional\<T\> for partial updates

**Your OpenAPI spec:**

```yaml
/tasks/{id}:
  put:
    operationId: updateTask
    # ...
UpdateTaskRequest:
  type: object
  required: [title, status, priority]     # only 3 fields required
  properties:
    title:       { type: string }
    description: { type: string, nullable: true }
    assignee_id: { type: string, nullable: true }
    due_date:    { type: string, nullable: true, format: date-time }
    tags:        { type: array, items: { type: string } }
```

**florval generates** — optional fields wrapped in `JsonOptional<T>` to distinguish "not sent" from "null":

```dart
// models/update_task_request.dart
@Freezed(fromJson: false, toJson: false)
abstract class UpdateTaskRequest with _$UpdateTaskRequest {
  const UpdateTaskRequest._();

  const factory UpdateTaskRequest({
    required String title,
    @Default(JsonOptional<String>.absent()) JsonOptional<String> description,
    required UpdateTaskRequestStatus status,
    required UpdateTaskRequestPriority priority,
    @JsonKey(name: 'assignee_id')
    @Default(JsonOptional<String>.absent()) JsonOptional<String> assigneeId,
    @JsonKey(name: 'due_date')
    @Default(JsonOptional<DateTime>.absent()) JsonOptional<DateTime> dueDate,
    @Default(JsonOptional<List<String>>.absent()) JsonOptional<List<String>> tags,
  }) = _UpdateTaskRequest;

  factory UpdateTaskRequest.fromJson(Map<String, dynamic> json) { /* ... */ }
  Map<String, dynamic> toJson() { /* ... */ }
}
```

**You write:**

```dart
// Only update title — optional fields stay untouched on the server
final body = UpdateTaskRequest(
  title: 'New title',
  status: UpdateTaskRequestStatus.done,
  priority: UpdateTaskRequestPriority.high,
);
// → {"title": "New title", "status": "done", "priority": "high"}

// Explicitly clear the due date
final body = UpdateTaskRequest(
  title: 'New title',
  status: UpdateTaskRequestStatus.done,
  priority: UpdateTaskRequestPriority.high,
  dueDate: JsonOptional.value(null),
);
// → {"title": "New title", "status": "done", "priority": "high", "due_date": null}
```

### Discriminator Union Types (oneOf/anyOf)

**Your OpenAPI spec:**

```yaml
NotificationPayload:
  oneOf:
    - $ref: "#/components/schemas/TaskAssignedPayload"
    - $ref: "#/components/schemas/CommentAddedPayload"
  discriminator:
    propertyName: type
    mapping:
      task_assigned: "#/components/schemas/TaskAssignedPayload"
      comment_added: "#/components/schemas/CommentAddedPayload"
```

**florval generates** — freezed sealed classes with `unionKey` and `@FreezedUnionValue`:

```dart
@Freezed(unionKey: 'type')
sealed class NotificationPayload with _$NotificationPayload {
  @FreezedUnionValue('task_assigned')
  const factory NotificationPayload.taskAssigned({
    @JsonKey(name: 'task_id') required String taskId,
    @JsonKey(name: 'task_title') required String taskTitle,
    @JsonKey(name: 'assigned_by') required String assignedBy,
  }) = NotificationPayloadTaskAssigned;

  @FreezedUnionValue('comment_added')
  const factory NotificationPayload.commentAdded({
    @JsonKey(name: 'task_id') required String taskId,
    @JsonKey(name: 'comment_text') required String commentText,
    @JsonKey(name: 'commented_by') required String commentedBy,
  }) = NotificationPayloadCommentAdded;

  factory NotificationPayload.fromJson(Map<String, dynamic> json) =>
      _$NotificationPayloadFromJson(json);
}
```

**You write:**

```dart
final payload = NotificationPayload.fromJson(json);
switch (payload) {
  case NotificationPayloadTaskAssigned(:final taskId, :final taskTitle):
    showAssignment(taskId, taskTitle);
  case NotificationPayloadCommentAdded(:final commentText):
    showComment(commentText);
}
```

---

## Why florval?

### The problem with other generators

Most Flutter OpenAPI generators treat every response as a single type:

```dart
// ❌ What other generators produce — you're on your own for error handling
try {
  final user = await client.getUser(id: 42);
  // What if the server returned 404? 422? 500?
  // You don't know until it throws.
} on DioException catch (e) {
  if (e.response?.statusCode == 404) { ... }
  else if (e.response?.statusCode == 422) { ... }
  // Manual, error-prone, no type safety
}
```

### What florval generates

```dart
// ✅ florval — every status code is a typed variant
final response = await client.getTask(id: taskId);

switch (response) {
  case GetTaskResponseSuccess(:final data)        => showTask(data),
  case GetTaskResponseNotFound(:final data)       => showError(data.message),
  case GetTaskResponseUnauthorized(:final data)   => handleAuth(data),
  case GetTaskResponseUnknown(:final statusCode)  => showError('Error: $statusCode'),
}
```

No exceptions. No `statusCode == 200` checks. Every response path is exhaustive and compiler-checked.

## Features

**Core — what sets florval apart:**

- **Status-code Union types** — plain Dart sealed classes for every endpoint response
- **JsonOptional\<T\> for PATCH/PUT** — distinguishes "don't send this key" from "send null"
- **Riverpod 3.x integration** — Notifiers for GET, Mutation API for POST/PUT/DELETE
- **Auto-invalidation** — mutations automatically refresh related GET providers

**Generation:**

- **freezed 3.x models** — immutable data classes with `copyWith`, JSON serialization
- **Inline enum generation** — `enum` properties in schemas become dedicated Dart enums with `@JsonValue`
- **Doc comments** — `description` and `example` from OpenAPI specs become `///` doc comments
- **`@Deprecated` annotations** — schema, property, operation, and parameter-level `deprecated` flags
- **`readOnly` / `writeOnly`** — OpenAPI field flags propagated to the intermediate representation
- **`@Default` values** — OpenAPI `default` values generate `@Default(...)` annotations
- **dio clients** — clean HTTP clients, no Retrofit, full control over your Dio instance
- **Cursor-based pagination** — `fetchMore()` with automatic data accumulation
- **Discriminator Union types** — `@Freezed(unionKey: ...)` with `@FreezedUnionValue`
- **multipart/form-data** — file uploads with `MultipartFile` support

**DX:**

- **Watch mode** — auto-regenerate on spec file changes
- **OpenAPI 3.0 & 3.1** — v3.0 specs are normalized to v3.1 automatically
- **Swagger 2.0** — partial support (auto-normalized to v3.1)
- **Zero runtime dependency** — generated code depends only on dio, freezed, and optionally Riverpod

## Quick Start

### 1. Install

```yaml
dev_dependencies:
  florval: ^0.2.0
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
```

## Comparison

| Feature | florval | swagger_parser | openapi_generator |
|---------|:-------:|:--------------:|:-----------------:|
| Status-code Union types | ✅ | ❌ | ❌ |
| JsonOptional (undefined vs null) | ✅ | ❌ | ❌ |
| Riverpod integration | ✅ | ❌ | ❌ |
| Auto-invalidation after mutations | ✅ | ❌ | ❌ |
| Inline enum generation | ✅ | ✅ | ✅ |
| Doc comments from description/example | ✅ | ❌ | ✅ |
| @Deprecated from OpenAPI flags | ✅ | ❌ | ✅ |
| @Default from OpenAPI defaults | ✅ | ❌ | ❌ |
| Cursor-based pagination | ✅ | ❌ | ❌ |
| freezed 3.x | ✅ | ✅ | ❌ |
| No Retrofit dependency | ✅ | ❌ | N/A |
| OpenAPI 3.0 + 3.1 | ✅ | ✅ | ✅ |
| Swagger 2.0 | ✅ | ✅ | ✅ |
| multipart/form-data | ✅ | ✅ | ✅ |

## Generated Output Structure

```
lib/api/generated/
├── core/
│   └── json_optional.dart       # Runtime type for PATCH/PUT
├── models/                      # freezed data classes
├── responses/                   # Status-code sealed classes
├── clients/                     # dio API clients
├── providers/                   # Riverpod Notifiers + Mutations
└── api.dart                     # Barrel file
```

## CLI

```bash
dart run florval init                              # Create florval.yaml template
dart run florval init --config custom.yaml --force  # Custom config path
dart run florval generate                          # Generate from florval.yaml
dart run florval generate --watch                  # Watch mode
dart run florval generate --schema api.yaml --output lib/api/
dart run florval generate --verbose                # Debug output
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
  florval: ^0.2.0
```

## OpenAPI Version Support

| Version | Support |
|---------|---------|
| OpenAPI 3.1 | Full |
| OpenAPI 3.0 | Full (auto-normalized to 3.1) |
| Swagger 2.0 | Partial (auto-normalized to 3.1) |

## License

MIT

---

<p align="center"><b>encer.co.jp is committed to shaping the future of Flutter.</b></p>
