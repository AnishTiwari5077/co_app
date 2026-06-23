import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api_client.dart';

// ── Response model — matches backend TransactionResponse exactly ─────────────

class TransactionResponse {
  final String transactionId;
  final String receiptNumber;
  final double amount;
  final double balanceAfter;
  final DateTime transactionDate;

  TransactionResponse({
    required this.transactionId,
    required this.receiptNumber,
    required this.amount,
    required this.balanceAfter,
    required this.transactionDate,
  });

  factory TransactionResponse.fromJson(Map<String, dynamic> j) =>
      TransactionResponse(
        transactionId: j['transactionId'] as String? ??
            j['TransactionId'] as String? ?? '',
        receiptNumber: j['receiptNumber'] as String? ??
            j['ReceiptNumber'] as String? ?? '',
        amount: (j['amount'] as num? ?? j['Amount'] as num?)?.toDouble() ?? 0,
        balanceAfter:
            (j['balanceAfter'] as num? ?? j['BalanceAfter'] as num?)
                ?.toDouble() ??
                0,
        transactionDate: DateTime.tryParse(
                j['transactionDate'] as String? ??
                    j['TransactionDate'] as String? ??
                    '') ??
            DateTime.now(),
      );
}

// ── Repository ────────────────────────────────────────────────────────────────

class SavingsRepository {
  final Dio _dio;
  SavingsRepository(this._dio);

  /// POST /api/v1/savings/accounts/{id}/deposit
  /// Backend DepositRequest: { Amount, DepositMode, Narration?, CollectedBy? }
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
        'depositMode': mode,                          // ← correct field name
        if (narration != null && narration.isNotEmpty) 'narration': narration,
      },
    );
    final envelope = response.data as Map<String, dynamic>;
    final data = envelope['data'] as Map<String, dynamic>? ?? envelope;
    return TransactionResponse.fromJson(data);
  }

  /// POST /api/v1/savings/accounts/{id}/withdraw
  /// Backend WithdrawRequest: { Amount, WithdrawalMode, Narration?, VerifiedById? }
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
        'withdrawalMode': mode,                       // ← correct field name
        if (narration != null && narration.isNotEmpty) 'narration': narration,
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
