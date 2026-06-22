import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api_client.dart';

class TransactionResponse {
  final String transactionId, accountNo, type;
  final double amount, balanceAfter;
  final DateTime transactionDate;
  TransactionResponse({
    required this.transactionId, required this.accountNo,
    required this.type, required this.amount,
    required this.balanceAfter, required this.transactionDate,
  });
  factory TransactionResponse.fromJson(Map<String, dynamic> j) =>
      TransactionResponse(
        transactionId: j['transactionId'] as String? ?? '',
        accountNo: j['accountNo'] as String? ?? '',
        type: j['type'] as String? ?? '',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        balanceAfter: (j['balanceAfter'] as num?)?.toDouble() ?? 0,
        transactionDate: DateTime.tryParse(j['transactionDate'] as String? ?? '') ?? DateTime.now(),
      );
}

class SavingsRepository {
  final Dio _dio;
  SavingsRepository(this._dio);

  Future<TransactionResponse> deposit({
    required String accountId,
    required double amount,
    required String mode,
    String? narration,
    String? chequeNo,
  }) async {
    final response = await _dio.post(
      '/api/v1/savings/accounts/$accountId/deposit',
      data: {
        'amount': amount,
        'mode': mode,
        if (narration != null && narration.isNotEmpty) 'narration': narration,
        if (chequeNo != null && chequeNo.isNotEmpty) 'chequeNo': chequeNo,
      },
    );
    final envelope = response.data as Map<String, dynamic>;
    final data = envelope['data'] as Map<String, dynamic>? ?? envelope;
    return TransactionResponse.fromJson(data);
  }

  Future<TransactionResponse> withdraw({
    required String accountId,
    required double amount,
    required String mode,
    String? narration,
    String? chequeNo,
  }) async {
    final response = await _dio.post(
      '/api/v1/savings/accounts/$accountId/withdraw',
      data: {
        'amount': amount,
        'mode': mode,
        if (narration != null && narration.isNotEmpty) 'narration': narration,
        if (chequeNo != null && chequeNo.isNotEmpty) 'chequeNo': chequeNo,
      },
    );
    final envelope = response.data as Map<String, dynamic>;
    final data = envelope['data'] as Map<String, dynamic>? ?? envelope;
    return TransactionResponse.fromJson(data);
  }
}

final savingsRepositoryProvider = Provider<SavingsRepository>((ref) {
  return SavingsRepository(ref.watch(dioProvider));
});
