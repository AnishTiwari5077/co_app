import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/repositories/savings_repository.dart';

class TransactionState {
  final bool isLoading;
  final String? error;
  final TransactionResponse? result;
  const TransactionState({this.isLoading = false, this.error, this.result});
  TransactionState copyWith({bool? isLoading, String? error, TransactionResponse? result}) =>
      TransactionState(
        isLoading: isLoading ?? this.isLoading,
        error: error,
        result: result ?? this.result,
      );
}

final depositProvider =
    StateNotifierProvider.autoDispose<TransactionNotifier, TransactionState>(
        (ref) => TransactionNotifier(ref.watch(savingsRepositoryProvider), 'deposit'));

final withdrawProvider =
    StateNotifierProvider.autoDispose<TransactionNotifier, TransactionState>(
        (ref) => TransactionNotifier(ref.watch(savingsRepositoryProvider), 'withdraw'));

class TransactionNotifier extends StateNotifier<TransactionState> {
  final SavingsRepository _repo;
  final String _type;
  TransactionNotifier(this._repo, this._type) : super(const TransactionState());

  Future<bool> submit({
    required String accountId,
    required double amount,
    required String mode,
    String? narration,
    String? chequeNo,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = _type == 'deposit'
          ? await _repo.deposit(
              accountId: accountId, amount: amount,
              mode: mode, narration: narration, chequeNo: chequeNo)
          : await _repo.withdraw(
              accountId: accountId, amount: amount,
              mode: mode, narration: narration, chequeNo: chequeNo);
      state = state.copyWith(isLoading: false, result: result);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}
