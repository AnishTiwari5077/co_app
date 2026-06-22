import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/repositories/member_repository.dart';

// ── Member list provider (paginated + search) ─────────────────────────────────
final memberListProvider =
    AsyncNotifierProvider<MemberListNotifier, List<MemberListItem>>(
  MemberListNotifier.new,
);

class MemberListNotifier extends AsyncNotifier<List<MemberListItem>> {
  int _page = 1;
  bool _hasMore = true;
  String _search = '';
  String _status = 'All';
  final List<MemberListItem> _items = [];

  @override
  Future<List<MemberListItem>> build() async {
    return _loadPage(reset: true);
  }

  Future<List<MemberListItem>> _loadPage({bool reset = false}) async {
    if (reset) {
      _page = 1;
      _hasMore = true;
      _items.clear();
    }
    final repo = ref.read(memberRepositoryProvider);
    final result = await repo.getMembers(
        page: _page, search: _search, status: _status);
    _hasMore = result.data.length >= 20;
    _items.addAll(result.data);
    return List.unmodifiable(_items);
  }

  Future<void> search(String query) async {
    _search = query;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadPage(reset: true));
  }

  Future<void> filterByStatus(String status) async {
    _status = status;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadPage(reset: true));
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _loadPage(reset: true));
  }

  Future<void> loadMore() async {
    if (!_hasMore || state.isLoading) return;
    _page++;
    state = await AsyncValue.guard(() => _loadPage());
  }
}

// ── Register member provider ───────────────────────────────────────────────────
class RegisterMemberState {
  final bool isLoading;
  final String? error;
  final String? newMemberId;
  const RegisterMemberState({
    this.isLoading = false, this.error, this.newMemberId,
  });
  RegisterMemberState copyWith({bool? isLoading, String? error, String? newMemberId}) =>
      RegisterMemberState(
        isLoading: isLoading ?? this.isLoading,
        error: error,
        newMemberId: newMemberId ?? this.newMemberId,
      );
}

final registerMemberProvider =
    StateNotifierProvider<RegisterMemberNotifier, RegisterMemberState>((ref) {
  return RegisterMemberNotifier(ref.watch(memberRepositoryProvider));
});

class RegisterMemberNotifier extends StateNotifier<RegisterMemberState> {
  final MemberRepository _repo;
  RegisterMemberNotifier(this._repo) : super(const RegisterMemberState());

  Future<bool> submit(RegisterMemberRequest request) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final id = await _repo.registerMember(request);
      state = state.copyWith(isLoading: false, newMemberId: id);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}
