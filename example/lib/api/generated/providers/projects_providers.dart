import 'package:riverpod/experimental/mutation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'retry.dart';
import '../clients/projects_api_client.dart';
import '../models/create_project_request.dart';
import '../api_responses.dart' as _r;

part 'projects_providers.g.dart';

@riverpod
ProjectsApiClient projectsApiClient(Ref ref) {
  throw UnimplementedError('Provide a Dio instance via override');
}

@Riverpod(retry: retry)
class ListProjects extends _$ListProjects {
  @override
  FutureOr<_r.ListProjectsResponse> build() async {
    final client = ref.watch(projectsApiClientProvider);
    return client.listProjects();
  }
}

/// Mutation for createProject (POST /projects)
final createProjectMutation = Mutation<_r.CreateProjectResponse>();

/// Executes createProject mutation and invalidates related GET providers.
Future<_r.CreateProjectResponse> createProject(
  MutationTarget ref, {
  required CreateProjectRequest body,
}) async {
  return createProjectMutation.run(ref, (tsx) async {
    final client = tsx.get(projectsApiClientProvider);
    final result = await client.createProject(body: body);
    ref.container.invalidate(listProjectsProvider);
    ref.container.invalidate(getProjectProvider);
    return result;
  });
}

@Riverpod(retry: retry)
class GetProject extends _$GetProject {
  @override
  FutureOr<_r.GetProjectResponse> build({
    required String id,
  }) async {
    final client = ref.watch(projectsApiClientProvider);
    return client.getProject(id: id);
  }
}

