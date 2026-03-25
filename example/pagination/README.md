# florval pagination example — Task Management API

cursorベースページネーションの生成コードを確認するためのサンプル。
架空のAPIなので実際のサーバーは存在しない。生成コードの構造確認用。

**2つのパターンを含む:**

| エンドポイント | レスポンス形式 | 生成される型 |
|---|---|---|
| `GET /tasks` | インラインobject | `ListTasksPage`（自動生成） |
| `GET /tasks/{taskId}/comments` | `$ref: CommentPage` | `CommentPage`（そのまま使用） |

## 生成コマンド

```bash
cd example/pagination/
dart run florval generate --config florval.yaml
```

## 生成されるファイル

```
generated/
├── models/
│   ├── task.dart                       # Taskモデル（freezed）
│   ├── user.dart                       # Userモデル
│   ├── comment.dart                    # Commentモデル
│   ├── comment_page.dart               # CommentPage（$refで定義済み）
│   ├── list_tasks_page.dart            # ListTasksPage（インラインから自動生成）
│   ├── create_task_request.dart
│   ├── create_comment_request.dart
│   ├── api_error.dart
│   ├── paginated_data.dart             # PaginatedData<T> ← pagination用
│   └── api_exception.dart              # ApiException ← pagination用
├── responses/
│   ├── list_tasks_response.dart        # success(ListTasksPage data)
│   ├── list_task_comments_response.dart # success(CommentPage data)
│   ├── get_task_response.dart
│   └── ...
├── clients/
│   └── tasks_api_client.dart
├── providers/
│   └── tasks_providers.dart
└── api.dart
```

## 注目ポイント

### パターン1: インラインobject → ラッパーモデル自動生成

`GET /tasks` の200レスポンスはインラインobject（`$ref`なし）:

```yaml
# openapi.yaml
responses:
  "200":
    schema:
      type: object          # ← インライン
      properties:
        items: ...
        nextCursor: ...
```

florvalが `ListTasksPage` というfreezedモデルを自動生成し、Union型で使用:

```dart
// responses/list_tasks_response.dart
const factory ListTasksResponse.success(ListTasksPage data) = ...;
```

### パターン2: $ref → 定義済みスキーマをそのまま使用

`GET /tasks/{taskId}/comments` の200レスポンスは `$ref`:

```yaml
# openapi.yaml
responses:
  "200":
    schema:
      $ref: "#/components/schemas/CommentPage"  # ← $ref
```

`CommentPage` はcomponents/schemasに定義済みなので、そのままfreeezedモデルとして生成:

```dart
// responses/list_task_comments_response.dart
const factory ListTaskCommentsResponse.success(CommentPage data) = ...;
```

### ページネーションNotifier

どちらのパターンも、providerは同じ形で生成される:

```dart
@riverpod
class ListTasks extends _$ListTasks {
  final List<Task> _allItems = [];
  String? _nextCursor;
  bool _hasMore = true;

  @override
  FutureOr<PaginatedData<Task>> build({...}) async { ... }

  Future<void> fetchMore() async { ... }
}

@riverpod
class ListTaskComments extends _$ListTaskComments {
  final List<Comment> _allItems = [];
  String? _nextCursor;
  bool _hasMore = true;

  @override
  FutureOr<PaginatedData<Comment>> build({required String taskId, ...}) async { ... }

  Future<void> fetchMore() async { ... }
}
```

### 通常のGET / Mutation

`getTask`（通常のGET）は従来通りのUnion型Notifier:

```dart
@riverpod
class GetTask extends _$GetTask {
  @override
  FutureOr<GetTaskResponse> build({required String taskId}) async { ... }
}
```

`createTask` / `updateTask` / `deleteTask` / `addTaskComment` はMutation定数:

```dart
final createTask = Mutation<CreateTaskResponse>();
final addTaskComment = Mutation<AddTaskCommentResponse>();
```

### autoInvalidate

`auto_invalidate: true`なので、mutation実行後に同じタグのGETプロバイダーが自動invalidateされる。
