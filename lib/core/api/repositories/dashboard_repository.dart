import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api_client.dart';

class DashboardSummary {
  final int totalMembers, activeMembers, pendingMembers;
  final double totalSavings, totalLoans, totalNpa;
  final int activeLoans;

  DashboardSummary({
    required this.totalMembers, required this.activeMembers,
    required this.pendingMembers, required this.totalSavings,
    required this.totalLoans, required this.totalNpa,
    required this.activeLoans,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> j) =>
      DashboardSummary(
        totalMembers: j['totalMembers'] as int? ?? j['TotalMembers'] as int? ?? 0,
        activeMembers: j['activeMembers'] as int? ?? j['ActiveMembers'] as int? ?? 0,
        pendingMembers: j['pendingMembers'] as int? ?? j['PendingMembers'] as int? ?? 0,
        totalSavings: (j['totalSavingsBalance'] as num?)?.toDouble()
            ?? (j['TotalSavingsBalance'] as num?)?.toDouble()
            ?? (j['totalSavings'] as num?)?.toDouble() ?? 0,
        totalLoans: (j['totalLoanOutstanding'] as num?)?.toDouble()
            ?? (j['TotalLoanOutstanding'] as num?)?.toDouble()
            ?? (j['totalLoans'] as num?)?.toDouble() ?? 0,
        totalNpa: (j['npaPercent'] as num?)?.toDouble()
            ?? (j['NpaPercent'] as num?)?.toDouble()
            ?? (j['totalNpa'] as num?)?.toDouble() ?? 0,
        activeLoans: j['activeLoans'] as int? ?? j['ActiveLoans'] as int? ?? 0,
      );

  factory DashboardSummary.empty() => DashboardSummary(
    totalMembers: 0, activeMembers: 0, pendingMembers: 0,
    totalSavings: 0, totalLoans: 0, totalNpa: 0, activeLoans: 0,
  );
}

class DashboardRepository {
  final Dio _dio;
  DashboardRepository(this._dio);

  Future<DashboardSummary> getSummary() async {
    final response = await _dio.get('/api/v1/dashboard/summary');
    final envelope = response.data as Map<String, dynamic>;
    final data = envelope['data'] as Map<String, dynamic>? ?? envelope;
    return DashboardSummary.fromJson(data);
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(dioProvider));
});
