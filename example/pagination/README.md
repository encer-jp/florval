# florval pagination example — Task Management API

cursorベースページネーションの生成コードを確認するためのサンプル。
架空のAPIなので実際のサーバーは存在しない。生成コードの構造確認用。

## 生成コマンド

```bash
cd example/pagination/
dart run florval generate --config florval.yaml
```

## 生成されるファイル

```
generated/
├── models/
│   ├── task.dart                    # Taskモデル（freezed）
│   ├── user.dart                    # Userモデル（freezed）
│   ├── create_task_request.dart     # リクエストモデル
│   ├── api_error.dart               # エラーモデル
│   ├── paginated_data.dart          # PaginatedData<T> ← pagination用
│   └── api_exception.dart           # ApiException ← pagination用
├── responses/
│   ├── list_tasks_response.dart     # Union型（ステータスコード別）
│   ├── get_task_response.dart
│   └── ...
├── clients/
│   └── tasks_api_client.dart        # dioクライアント
├── providers/
│   └── tasks_providers.dart         # Riverpodプロバイダー
└── api.dart                         # バレルファイル
```

## 注目ポイント

### providers/tasks_providers.dart

`listTasks`はpagination設定があるため、通常の`@riverpod` Notifierではなく
**fetchMore()付きのページネーションNotifier**が生成される:

```dart
@riverpod
class ListTasks extends _$ListTasks {
  final List<Task> _allItems = [];
  String? _nextCursor;
  bool _hasMore = true;

  @override
  FutureOr<PaginatedData<Task>> build({...}) async {
    // 初回フェッチ
  }

  Future<void> fetchMore() async {
    // 次ページ取得 → _allItemsに追記
  }
}
```

一方 `getTask`（通常のGET）は従来通りのUnion型Notifier:

```dart
@riverpod
class GetTask extends _$GetTask {
  @override
  FutureOr<GetTaskResponse> build({required String taskId}) async {
    // ...
  }
}
```

`createTask` / `updateTask` / `deleteTask` はMutation定数:

```dart
final createTask = Mutation<CreateTaskResponse>();
```

### autoInvalidate

`auto_invalidate: true`なので、createTask/updateTask/deleteTask実行後に
listTasksProvider / getTaskProvider が自動的にinvalidateされる。
