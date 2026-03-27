import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/generated/api.dart';
import 'api/generated/api_responses.dart' as r;
import 'screens/mutation_tab.dart';
import 'screens/error_tab.dart';
import 'screens/pagination_tab.dart';

void main() {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://localhost:3000',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        authApiClientProvider.overrideWithValue(AuthApiClient(dio)),
        tasksApiClientProvider.overrideWithValue(TasksApiClient(dio)),
        usersApiClientProvider.overrideWithValue(UsersApiClient(dio)),
        projectsApiClientProvider.overrideWithValue(ProjectsApiClient(dio)),
        notificationsApiClientProvider
            .overrideWithValue(NotificationsApiClient(dio)),
        uploadsApiClientProvider.overrideWithValue(UploadsApiClient(dio)),
      ],
      child: DemoApp(dio: dio),
    ),
  );
}

class DemoApp extends StatelessWidget {
  final Dio dio;
  const DemoApp({super.key, required this.dio});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'florval Showcase',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: ShowcaseHome(dio: dio),
    );
  }
}

class ShowcaseHome extends ConsumerStatefulWidget {
  final Dio dio;
  const ShowcaseHome({super.key, required this.dio});

  @override
  ConsumerState<ShowcaseHome> createState() => _ShowcaseHomeState();
}

class _ShowcaseHomeState extends ConsumerState<ShowcaseHome> {
  bool _loggedIn = false;
  String? _loginError;

  @override
  void initState() {
    super.initState();
    _autoLogin();
  }

  /// Auto-login for ErrorTab and PaginationTab.
  /// MutationTab manages its own login state separately.
  Future<void> _autoLogin() async {
    final authClient = ref.read(authApiClientProvider);
    final response = await authClient.login(
      body: LoginRequest(email: 'demo@example.com', password: 'password'),
    );
    switch (response) {
      case r.LoginResponseSuccess(:final data):
        widget.dio.options.headers['Authorization'] = 'Bearer ${data.token}';
        setState(() => _loggedIn = true);
      default:
        setState(() => _loginError = 'Auto-login failed: $response');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loggedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('florval Showcase')),
        body: Center(
          child: _loginError != null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(_loginError!),
                    const SizedBox(height: 12),
                    const Text('Make sure demo-api is running:\n  cd demo-api && npm run dev'),
                  ],
                )
              : const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Logging in...'),
                  ],
                ),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('florval Showcase'),
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.touch_app), text: 'Mutation'),
            Tab(icon: Icon(Icons.error_outline), text: 'Errors'),
            Tab(icon: Icon(Icons.view_list), text: 'Pagination'),
          ]),
        ),
        body: TabBarView(children: [
          MutationTab(dio: widget.dio),
          ErrorTab(dio: widget.dio),
          const PaginationTab(),
        ]),
      ),
    );
  }
}
