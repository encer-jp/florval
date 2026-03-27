import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/generated/api.dart';
import 'screens/status_code_tab.dart';
import 'screens/mutation_tab.dart';
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
        tasksApiClientProvider.overrideWithValue(TasksApiClient(dio)),
        usersApiClientProvider.overrideWithValue(UsersApiClient(dio)),
        projectsApiClientProvider.overrideWithValue(ProjectsApiClient(dio)),
        notificationsApiClientProvider
            .overrideWithValue(NotificationsApiClient(dio)),
        uploadsApiClientProvider.overrideWithValue(UploadsApiClient(dio)),
      ],
      child: const DemoApp(),
    ),
  );
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'florval Showcase',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const ShowcaseHome(),
    );
  }
}

class ShowcaseHome extends StatelessWidget {
  const ShowcaseHome({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('florval Showcase'),
          bottom: const TabBar(tabs: [
            Tab(icon: Icon(Icons.http), text: 'Status Code'),
            Tab(icon: Icon(Icons.edit_note), text: 'Task'),
            Tab(icon: Icon(Icons.view_list), text: 'Pagination'),
          ]),
        ),
        body: const TabBarView(children: [
          StatusCodeTab(),
          MutationTab(),
          PaginationTab(),
        ]),
      ),
    );
  }
}
