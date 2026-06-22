import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/repositories/dashboard_repository.dart';

final dashboardSummaryProvider =
    AsyncNotifierProvider<DashboardSummaryNotifier, DashboardSummary>(
  DashboardSummaryNotifier.new,
);

class DashboardSummaryNotifier extends AsyncNotifier<DashboardSummary> {
  @override
  Future<DashboardSummary> build() => _fetch();

  Future<DashboardSummary> _fetch() async {
    final repo = ref.read(dashboardRepositoryProvider);
    return repo.getSummary();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }
}
