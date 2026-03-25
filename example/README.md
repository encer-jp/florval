# florval example — Petstore v3 検証プロジェクト

florvalが生成するコードが実際にコンパイル・ビルド・実行できるか検証するプロジェクト。
Swagger Petstore v3の公開APIを使用し、生成コード → build_runner → API呼び出しまで一気通貫で確認する。

## 手順

### Step 1: 依存関係の取得

```bash
cd example/
flutter pub get
```

### Step 2: florvalでコード生成

```bash
cd example/
dart run florval generate --config florval.yaml
```

生成先: `lib/api/generated/`

### Step 3: build_runner実行

```bash
cd example/
dart run build_runner build --delete-conflicting-outputs
```

**ここが最重要検証ポイント。**
生成されたfreezed/json_serializable/riverpod_generatorのコードがエラーなくビルドされることを確認する。

### Step 4: dart analyze

```bash
cd example/
dart analyze
```

警告・エラーがゼロであること。

### Step 5: 実行

```bash
cd example/
flutter run -d chrome
```

## 成功基準

1. `dart run florval generate` がエラーなく完了
2. `dart run build_runner build` がエラーなく完了（freezed/json_serializable/riverpod_generator全て）
3. `dart analyze` が警告・エラーゼロ
4. 実際のPetstore APIへのリクエストが成功し、レスポンスが型安全にパターンマッチングできる
5. 404等のエラーレスポンスもUnion型で正しくハンドリングされる

## 検証対象API

| # | メソッド | パス | 検証内容 |
|---|----------|------|----------|
| 1 | GET | /pet/findByStatus | ペット一覧取得（成功レスポンス） |
| 2 | POST | /pet | ペット作成（成功） |
| 3 | GET | /pet/{petId} | 存在するpetId（成功）と存在しないpetId（404） |
| 4 | DELETE | /pet/{petId} | ペット削除 |

## トラブルシューティング

### build_runnerでエラーが出る場合

生成コードに問題がある。以下を確認：

- freezed 3.xの構文（abstract class vs sealed class）
- import文のパスが正しいか
- part/part of ディレクティブが正しいか
- riverpod_generatorの@riverpod/@mutationの使い方

エラー内容に基づいてflorval本体のジェネレーターを修正し、再生成 → 再ビルドを繰り返す。

## 備考

- Petstore v3 base URL: `https://petstore3.swagger.io/api/v3`
- Swagger UI: `https://petstore3.swagger.io/`
- 認証不要で全エンドポイント使用可能
- データは共有なので、他のユーザーが作成/削除したデータが見える場合がある
