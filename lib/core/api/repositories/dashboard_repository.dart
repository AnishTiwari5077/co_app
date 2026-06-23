import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api_client.dart';

/// Mirrors backend DashboardSummaryDto exactly:
/// TotalMembers, ActiveLoans, TotalSavingsBalance, TotalLoanOutstanding,
/// TodayDeposits, TodayWithdrawals, LoanRecoveryRate, NpaPercent,
/// NewMembersThisMonth, CashPosition
class DashboardSummary {
  final int totalMembers;
  final int activeLoans;
  final double totalSavings;
  final double totalLoans;
  final double todayDeposits;
  final double todayWithdrawals;
  final double loanRecoveryRate;
  final double npaPercent;
  final int newMembersThisMonth;
  final double cashPosition;

  DashboardSummary({
    required this.totalMembers,
    required this.activeLoans,
    required this.totalSavings,
    required this.totalLoans,
    required this.todayDeposits,
    required this.todayWithdrawals,
    required this.loanRecoveryRate,
    required this.npaPercent,
    required this.newMembersThisMonth,
    required this.cashPosition,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> j) => DashboardSummary(
        totalMembers: j['totalMembers'] as int? ??
            j['TotalMembers'] as int? ?? 0,
        activeLoans: j['activeLoans'] as int? ??
            j['ActiveLoans'] as int? ?? 0,
        totalSavings: (j['totalSavingsBalance'] as num? ??
                j['TotalSavingsBalance'] as num? ??
                j['totalSavings'] as num?)
            ?.toDouble() ??
            0,
        totalLoans: (j['totalLoanOutstanding'] as num? ??
                j['TotalLoanOutstanding'] as num? ??
                j['totalLoans'] as num?)
            ?.toDouble() ??
            0,
        todayDeposits: (j['todayDeposits'] as num? ??
                j['TodayDeposits'] as num?)
            ?.toDouble() ??
            0,
        todayWithdrawals: (j['todayWithdrawals'] as num? ??
                j['TodayWithdrawals'] as num?)
            ?.toDouble() ??
            0,
        loanRecoveryRate: (j['loanRecoveryRate'] as num? ??
                j['LoanRecoveryRate'] as num?)
            ?.toDouble() ??
            0,
        npaPercent: (j['npaPercent'] as num? ?? j['NpaPercent'] as num?)
                ?.toDouble() ??
            0,
        newMembersThisMonth: j['newMembersThisMonth'] as int? ??
            j['NewMembersThisMonth'] as int? ?? 0,
        cashPosition: (j['cashPosition'] as num? ??
                j['CashPosition'] as num?)
            ?.toDouble() ??
            0,
      );

  factory DashboardSummary.empty() => DashboardSummary(
        totalMembers: 0, activeLoans: 0, totalSavings: 0, totalLoans: 0,
        todayDeposits: 0, todayWithdrawals: 0, loanRecoveryRate: 0,
        npaPercent: 0, newMembersThisMonth: 0, cashPosition: 0,
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
