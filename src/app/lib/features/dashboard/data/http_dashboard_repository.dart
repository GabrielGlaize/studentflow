import 'package:studyflow_app/core/network/api_client.dart';
import 'package:studyflow_app/features/dashboard/data/dashboard_repository.dart';
import 'package:studyflow_app/features/dashboard/domain/dashboard_models.dart';

class HttpDashboardRepository implements DashboardRepository {
  const HttpDashboardRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<DashboardSummary> getDashboard({String? accessToken}) async {
    final json = await _apiClient.getJson(
      '/api/v1/dashboard',
      accessToken: accessToken,
    );

    return DashboardSummary.fromJson(json);
  }
}
