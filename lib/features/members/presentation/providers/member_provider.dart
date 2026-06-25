import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/repositories/member_repository.dart';

// ── Member list provider (paginated + search) ─────────────────────────────────
typedef MemberListState = ({List<MemberListItem> items, int totalCount});

final memberListProvider =
    AsyncNotifierProvider<MemberListNotifier, MemberListState>(
  MemberListNotifier.new,
);

class MemberListNotifier extends AsyncNotifier<MemberListState> {
  int _page = 1;
  bool _hasMore = true;
  String _search = '';
  String _status = 'All';
  int _totalCount = 0;
  final List<MemberListItem> _items = [];

  @override
  Future<MemberListState> build() async {
    return _loadPage(reset: true);
  }

  Future<MemberListState> _loadPage({bool reset = false}) async {
    if (reset) {
      _page = 1;
      _hasMore = true;
      _items.clear();
      _totalCount = 0;
    }
    final repo = ref.read(memberRepositoryProvider);
    final result = await repo.getMembers(
        page: _page, search: _search, status: _status);
    _hasMore = result.data.length >= 20;
    _items.addAll(result.data);
    _totalCount = result.total;
    return (items: List<MemberListItem>.unmodifiable(_items), totalCount: _totalCount);
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
