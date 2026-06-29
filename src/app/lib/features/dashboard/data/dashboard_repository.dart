import 'package:studyflow_app/features/dashboard/domain/dashboard_models.dart';

abstract interface class DashboardRepository {
  Future<DashboardSummary> getDashboard({String? accessToken});
}
