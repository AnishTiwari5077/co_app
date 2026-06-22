import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api_client.dart';

class LoanApplication {
  final String memberId, loanProductId, purpose;
  final double requestedAmount;
  final int tenureMonths;
  LoanApplication({
    required this.memberId, required this.loanProductId,
    required this.purpose, required this.requestedAmount,
    required this.tenureMonths,
  });
  Map<String, dynamic> toJson() => {
    'memberId': memberId,
    'loanProductId': loanProductId,
    'purpose': purpose,
    'requestedAmount': requestedAmount,
    'tenureMonths': tenureMonths,
  };
}

class LoanRepository {
  final Dio _dio;
  LoanRepository(this._dio);

  Future<String> applyLoan(LoanApplication application) async {
    final response = await _dio.post('/api/v1/loans', data: application.toJson());
    final envelope = response.data as Map<String, dynamic>;
    return envelope['id'] as String? ?? '';
  }

  Future<void> approveLoan(String id, double amount, {String? remarks}) async {
    await _dio.post('/api/v1/loans/$id/approve', data: {
      'approvedAmount': amount,
      if (remarks != null) 'remarks': remarks,
    });
  }

  Future<List<Map<String, dynamic>>> getSchedule(String loanId) async {
    final response = await _dio.get('/api/v1/loans/$loanId/schedule');
    final envelope = response.data as Map<String, dynamic>;
    final list = envelope['data'] as List<dynamic>? ?? [];
    return list.map((e) => e as Map<String, dynamic>).toList();
  }
}

final loanRepositoryProvider = Provider<LoanRepository>((ref) {
  return LoanRepository(ref.watch(dioProvider));
});
