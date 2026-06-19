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
  case GetTaskResponseSuccess(:final data):       // data is Task
    showTask(data);
  case GetTaskResponseNotFound(:final data):
    showError(data.message);
  case GetTaskResponseUnauthorized(:final data):
    handleAuth(data);
  case GetTaskResponseUnknown(:final statusCode):
    showError('Error: $statusCode');
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
  case CreateTaskResponseCreated(:final data):              // data is Task
    showTask(data);
  case CreateTaskResponseUnprocessableEntity(:final data):
    showErrors(data.errors);
  case CreateTaskResponseUnauthorized(:final data):
    handleAuth(data);
  case CreateTaskResponseUnknown(:final statusCode):
    showError('Error: $statusCode');
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
  case GetTaskResponseSuccess(:final data):
    showTask(data);
  case GetTaskResponseNotFound(:final data):
    showError(data.message);
  case GetTaskResponseUnauthorized(:final data):
    handleAuth(data);
  case GetTaskResponseUnknown(:final statusCode):
    showError('Error: $statusCode');
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
  florval: ^0.3.0
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

> **Tip — scope build_runner to the generated code.** On a real app, running freezed/json_serializable over your whole `lib/` is slow and may clash with other builders. Add a [`build.yaml`](#recommended-buildyaml) that restricts generation to florval's output directory. See below.

### 5. Wire up your Dio

This is the one manual step, and the most important. **florval never creates an HTTP client for you** — it generates a single Riverpod seam, `apiDioProvider`, and every generated client reads its `Dio` from it:

```dart
// providers/api_dio_provider.dart  (generated — do not edit)
@riverpod
Dio apiDio(Ref ref) {
  throw UnimplementedError('Override apiDioProvider with your Dio instance');
}
```

You override it once at the root of your app with a `Dio` you fully control — base URL, timeouts, auth headers, interceptors:

```dart
void main() {
  runApp(
    ProviderScope(
      overrides: [
        apiDioProvider.overrideWith(authedDio), // ← the integration point
      ],
      child: const App(),
    ),
  );
}
```

Because the base URL and timeouts live on *your* `Dio`, you get full control and can swap implementations per flavor/environment without regenerating. A realistic provider looks like this:

```dart
@Riverpod(keepAlive: true)
Dio authedDio(Ref ref) {
  final tokenStore = ref.read(tokenStoreProvider);

  final dio = Dio(
    BaseOptions(
      // Pick the base URL at build time: --dart-define=API_BASE_URL=https://api.example.com
      baseUrl: const String.fromEnvironment('API_BASE_URL'),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {Headers.acceptHeader: Headers.jsonContentType},
    ),
  );

  // Attach the bearer token to every request.
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await tokenStore.accessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ),
  );

  return dio;
}
```

See [Wiring patterns](#wiring-patterns) below for token-refresh-on-401 and transport-level retry.

## Configuration

Full `florval.yaml` reference:

```yaml
florval:
  schema_path: openapi.yaml               # Required. Path to OpenAPI spec.
  output_directory: lib/api/generated     # Output directory.

  riverpod:
    enabled: true                         # Generate Riverpod providers.
    auto_invalidate: false                # Invalidate same-tag GET providers after mutations.

    # When auto_invalidate is on, skip these mutations (by operationId).
    # Useful for optimistic updates (e.g. like/unlike) where a full refetch
    # would undo the optimistic state or cause a visible flicker.
    exclude_auto_invalidate:
      - likePost
      - unlikePost

    # Riverpod-level retry, emitted as the `retry()` function used by
    # `@Riverpod(retry: retry)` on every generated GET provider (linear backoff).
    retry:
      max_attempts: 3
      delay: 1000                         # Initial delay (ms).

    # Cursor-based pagination. `defaults` applies to every listed endpoint;
    # per-endpoint entries override individual fields.
    pagination:
      defaults:
        cursor_param: cursor              # Query parameter that carries the cursor.
        next_cursor_field: nextCursor     # Response field holding the next cursor.
        items_field: items                # Response field holding the data array.
      endpoints:
        - listPosts                       # Shorthand: just the operationId, uses defaults.
        - listComments
        - operation_id: listOrders        # Object form: override specific fields.
          cursor_param: after
          items_field: edges
```

> **`next_cursor_field` and `items_field` support dot paths** for nested envelopes.
> If your API wraps the cursor under a `pagination` object and the rows under
> `data`, write `next_cursor_field: pagination.nextCursor` and `items_field: data`.

### The `client` section is optional

`florval.yaml` also accepts a `client:` block (`base_url_env`, `timeout`). These are
**reserved/validated but no longer drive generation** — the base URL, timeouts, and
interceptors all live on the `Dio` you supply via [`apiDioProvider`](#5-wire-up-your-dio).
Configure them there, not here.

### Recommended `build.yaml`

Scope the codegen builders to florval's output so build_runner is fast and doesn't
fight other generators in your project. `checked` and `explicit_to_json` make
json_serializable validate types and serialize nested objects correctly:

```yaml
# build.yaml
targets:
  $default:
    builders:
      json_serializable:
        options:
          checked: true
          explicit_to_json: true
      freezed:
        generate_for:
          include:
            - lib/api/generated/clients/**
            - lib/api/generated/core/**
            - lib/api/generated/models/**
```

### Regenerating

Wrap the two-step regen in a script or `Makefile` target so the whole team runs it the same way:

```makefile
api:
	dart run florval generate
	dart run build_runner build --delete-conflicting-outputs
```

## Wiring patterns

These live in *your* code (not generated), on the `Dio` you expose through
[`apiDioProvider`](#5-wire-up-your-dio). They're the patterns most apps end up
needing; florval stays out of your way so you can use whichever you like.

### Refresh the token on 401

When the access token expires the server returns `401`. You can refresh it
transparently and replay the original request — but if several requests hit `401`
at the same moment, a naive interceptor fires several refreshes in parallel. With
**rotating refresh tokens** (each refresh invalidates the previous one) all but the
first refresh then fail and the user is logged out unexpectedly.

`QueuedInterceptorsWrapper` serializes `onError`, so only one request refreshes at a
time. Combine it with a "did someone already refresh?" check (compare the token the
failed request used against the current one) to collapse a burst of 401s into a single
refresh:

```dart
dio.interceptors.add(
  QueuedInterceptorsWrapper(
    onError: (error, handler) async {
      if (error.response?.statusCode != 401) {
        return handler.next(error);
      }

      final usedAuth = error.requestOptions.headers['Authorization'];
      final current = await tokenStore.accessToken();

      // Another queued request already refreshed — just replay with the fresh token.
      if (current != null && 'Bearer $current' != usedAuth) {
        final opts = error.requestOptions..headers['Authorization'] = 'Bearer $current';
        return handler.resolve(await dio.fetch<dynamic>(opts));
      }

      // Our turn to refresh (only one request reaches here at a time).
      final refreshed = await tokenStore.refresh();
      if (refreshed == null) {
        return handler.next(error); // refresh token dead → surface the 401
      }
      final opts = error.requestOptions..headers['Authorization'] = 'Bearer $refreshed';
      return handler.resolve(await dio.fetch<dynamic>(opts));
    },
  ),
);
```

### Two layers of retry

There are two independent retry layers — use whichever fits, or both:

| Layer | Configured by | Scope |
|-------|---------------|-------|
| **Provider retry** | `riverpod.retry` in `florval.yaml` → generated `retry()` on every `@Riverpod(retry: retry)` GET provider | Re-runs the whole provider build (re-fetch) when it throws |
| **Transport retry** | An interceptor on your `Dio` (e.g. [`dio_smart_retry`](https://pub.dev/packages/dio_smart_retry)) | Re-sends the HTTP request before it ever returns |

For transport retry, restrict it to **idempotent GETs** so a `POST`/`PUT`/`PATCH`/`DELETE`
isn't executed twice, and only on transient failures (connection/timeout, `5xx`):

```dart
dio.interceptors.add(
  RetryInterceptor(
    dio: dio,
    retries: 2,
    retryDelays: const [Duration(seconds: 1), Duration(seconds: 2)],
    retryEvaluator: (error, attempt) {
      if (error.requestOptions.method.toUpperCase() != 'GET') {
        return false;
      }
      const transient = {
        DioExceptionType.connectionError,
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      };
      return transient.contains(error.type) || (error.response?.statusCode ?? 0) >= 500;
    },
  ),
);
```

> Order matters: add the auth/refresh interceptor **before** the retry interceptor so
> retries carry the refreshed token.

## Cursor-based pagination

Mark an endpoint under `riverpod.pagination` (see [Configuration](#configuration)) and
florval generates a paginating Notifier. Its state is a `PaginatedData<Item, Page>` that
accumulates items across pages, plus a `fetchMore…()` helper:

```dart
// Generated runtime container (models/paginated_data.dart):
class PaginatedData<T, P> {
  final List<T> items;     // accumulated across all loaded pages
  final String? nextCursor;
  final bool hasMore;
  final P lastPage;        // raw last page — read API-specific fields like totalCount
}
```

**You write** — `watch` the provider for the accumulated list, call the helper to load more:

```dart
class PostsView extends HookConsumerWidget {
  const PostsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(listPostsProvider());
    final controller = useScrollController();

    // Guard against the scroll listener firing twice in one frame: `isPending`
    // only flips after a frame, so without this the next page is requested twice.
    final inFlight = useRef(false);
    useEffect(() {
      void onScroll() {
        final data = async.valueOrNull;
        if (data == null || !data.hasMore || inFlight.value) {
          return;
        }
        final pos = controller.position;
        if (pos.pixels < pos.maxScrollExtent - 200) {
          return;
        }
        inFlight.value = true;
        fetchMoreListPosts(ref).whenComplete(() => inFlight.value = false);
      }
      controller.addListener(onScroll);
      return () => controller.removeListener(onScroll);
    });

    return async.when(
      data: (page) => ListView.builder(
        controller: controller,
        itemCount: page.items.length,
        itemBuilder: (_, i) => PostTile(post: page.items[i]),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorState(error: e),
    );
  }
}
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
│   ├── json_optional.dart       # JsonOptional<T> runtime type for PATCH/PUT
│   └── date_serializer.dart     # JsonConverters for date / date-time formats
├── models/                      # freezed data classes + inline enums
│   ├── paginated_data.dart      # PaginatedData<T, P> container (if pagination is used)
│   └── api_exception.dart       # thrown by paginating providers on non-success
├── responses/                   # Status-code sealed classes (one per endpoint)
├── clients/                     # dio API clients
├── providers/                   # Riverpod Notifiers + Mutations (if riverpod.enabled)
│   ├── api_dio_provider.dart    # apiDioProvider — override this with your Dio
│   └── retry.dart               # retry() function for @Riverpod(retry: retry)
├── api.dart                     # Barrel file (export everything)
├── api_models.dart              # Barrel: models only
├── api_responses.dart           # Barrel: response unions only
├── api_clients.dart             # Barrel: clients only
└── api_providers.dart           # Barrel: providers only
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
  # Optional — only for the hooks-based pagination UI shown above
  # flutter_hooks: ^0.21.0
  # hooks_riverpod: ^3.0.0

dev_dependencies:
  build_runner: ^2.4.0
  freezed: ^3.0.0
  json_serializable: ^6.0.0
  # Only if riverpod.enabled: true
  riverpod_generator: ^3.0.0
  florval: ^0.3.0
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
