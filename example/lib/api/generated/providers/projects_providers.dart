import 'package:riverpod/experimental/mutation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'api_dio_provider.dart';
import 'retry.dart';
import '../clients/projects_api_client.dart';
import '../models/create_project_request.dart';
import '../api_responses.dart' as r;

part 'projects_providers.g.dart';

@riverpod
ProjectsApiClient projectsApiClient(Ref ref) {
  return ProjectsApiClient(ref.watch(apiDioProvider));
}

@Riverpod(retry: retry)
class ListProjects extends _$ListProjects {
  @override
  FutureOr<r.ListProjectsResponse> build() {
    final client = ref.watch(projectsApiClientProvider);
    return client.listProjects();
  }
}

/// Mutation for createProject (POST /projects)
final createProjectMutation = Mutation<r.CreateProjectResponse>();

/// Executes createProject mutation.
Future<r.CreateProjectResponse> createProject(
  MutationTarget ref, {
  required CreateProjectRequest body,
}) {
  return createProjectMutation.run(ref, (tsx) async {
    final client = tsx.get(projectsApiClientProvider);
    final result = await client.createProject(body: body);
    return result;
  });
}

@Riverpod(retry: retry)
class GetProject extends _$GetProject {
  @override
  FutureOr<r.GetProjectResponse> build({
    required String id,
  }) {
    final client = ref.watch(projectsApiClientProvider);
    return client.getProject(id: id);
  }
}
