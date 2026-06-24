import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/api/api_client.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class AccountItem {
  final String id, accountCode, accountName, accountType, accountGroup;
  final double currentBalance;
  final bool allowDirectPosting, isActive;

  AccountItem({
    required this.id, required this.accountCode, required this.accountName,
    required this.accountType, required this.accountGroup,
    required this.currentBalance, required this.allowDirectPosting,
    required this.isActive,
  });

  factory AccountItem.fromJson(Map<String, dynamic> j) => AccountItem(
    id: j['id'] as String? ?? '',
    accountCode: j['accountCode'] as String? ?? '',
    accountName: j['accountName'] as String? ?? '',
    accountType: j['accountType'] as String? ?? '',
    accountGroup: j['accountGroup'] as String? ?? '',
    currentBalance: (j['currentBalance'] as num?)?.toDouble() ?? 0,
    allowDirectPosting: j['allowDirectPosting'] as bool? ?? true,
    isActive: true, // management endpoint returns all
  );
}

// ── Provider ──────────────────────────────────────────────────────────────────

final _coaProvider = FutureProvider.autoDispose<List<AccountItem>>((ref) async {
  final dio = ref.watch(dioProvider);
  final res = await dio.get('/api/v1/accounting/chart-of-accounts/manage');
  final data = (res.data as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];
  return data.map((e) => AccountItem.fromJson(e as Map<String, dynamic>)).toList();
});

// ── Type colors & icons ───────────────────────────────────────────────────────

Color _typeColor(String type) {
  switch (type) {
    case 'Asset':     return const Color(0xFF2196F3);
    case 'Liability': return const Color(0xFFFF9800);
    case 'Equity':    return const Color(0xFF9C27B0);
    case 'Income':    return AppColors.secondary;
    case 'Expense':   return AppColors.error;
    default:          return AppColors.textSecondary;
  }
}

IconData _typeIcon(String type) {
  switch (type) {
    case 'Asset':     return Icons.account_balance_wallet_rounded;
    case 'Liability': return Icons.credit_card_rounded;
    case 'Equity':    return Icons.pie_chart_rounded;
    case 'Income':    return Icons.trending_up_rounded;
    case 'Expense':   return Icons.trending_down_rounded;
    default:          return Icons.account_tree_rounded;
  }
}

// ── Page ──────────────────────────────────────────────────────────────────────

class ChartOfAccountsPage extends ConsumerStatefulWidget {
  const ChartOfAccountsPage({super.key});

  @override
  ConsumerState<ChartOfAccountsPage> createState() => _ChartOfAccountsPageState();
}

class _ChartOfAccountsPageState extends ConsumerState<ChartOfAccountsPage> {
  String _selectedType = 'All';
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _isSubmitting = false;

  static const _types = ['All', 'Asset', 'Liability', 'Equity', 'Income', 'Expense'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openAddDialog() async {
    final codeCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final nameNpCtrl = TextEditingController();
    final groupCtrl = TextEditingController();
    String selectedType = 'Asset';
    bool allowPosting = true;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Add Account', style: AppTextStyles.titleMedium),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: codeCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Code *',
                            hintText: 'e.g. 6001',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      Expanded(
                        flex: 5,
                        child: TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Account Name (English) *',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  TextField(
                    controller: nameNpCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Account Name (Nepali)',
                      hintText: 'नेपालीमा नाम',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Account Type *',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Asset', 'Liability', 'Equity', 'Income', 'Expense']
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setDlg(() => selectedType = v!),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  TextField(
                    controller: groupCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Account Group',
                      hintText: 'e.g. Cash & Bank, Fee Income',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  SwitchListTile(
                    title: const Text('Allow Direct Posting'),
                    subtitle: const Text('Can be used in journal entries'),
                    value: allowPosting,
                    onChanged: (v) => setDlg(() => allowPosting = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (codeCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code and Name are required')),
                  );
                  return;
                }
                Navigator.pop(ctx);
                await _createAccount(
                  codeCtrl.text.trim(), nameCtrl.text.trim(),
                  nameNpCtrl.text.trim(), selectedType,
                  groupCtrl.text.trim().isEmpty ? selectedType : groupCtrl.text.trim(),
                  allowPosting,
                );
              },
              child: const Text('Add Account'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createAccount(String code, String name, String nameNp,
      String type, String group, bool allowPosting) async {
    setState(() => _isSubmitting = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.post('/api/v1/accounting/chart-of-accounts', data: {
        'accountCode': code,
        'accountName': name,
        'accountNameNp': nameNp,
        'accountType': type,
        'accountGroup': group,
        'allowDirectPosting': allowPosting,
      });
      ref.invalidate(_coaProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Account $code - $name added'),
          backgroundColor: AppColors.secondary,
        ));
      }
    } catch (e) {
      if (mounted) {
        final msg = _extractError(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _toggleAccount(AccountItem acc) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.put('/api/v1/accounting/chart-of-accounts/${acc.id}/toggle');
      ref.invalidate(_coaProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_extractError(e)), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteAccount(AccountItem acc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: Text('Delete "${acc.accountCode} - ${acc.accountName}"?\n\nThis cannot be undone if there are no transactions.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/api/v1/accounting/chart-of-accounts/${acc.id}');
      ref.invalidate(_coaProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${acc.accountCode} deleted'), backgroundColor: AppColors.secondary),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_extractError(e)), backgroundColor: AppColors.error),
        );
      }
    }
  }

  String _extractError(dynamic e) {
    try {
      final data = (e as dynamic).response?.data as Map<String, dynamic>?;
      return data?['message'] as String? ?? e.toString();
    } catch (_) {
      return e.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final coaAsync = ref.watch(_coaProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chart of Accounts', style: AppTextStyles.titleLarge),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_isSubmitting)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Add Account',
              onPressed: _openAddDialog,
            ),
        ],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(AppDimensions.md, AppDimensions.sm, AppDimensions.md, 0),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by code or name...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
                filled: true,
                fillColor: AppColors.surface,
              ),
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            ),
          ),
          // Type filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md, vertical: AppDimensions.sm),
            child: Row(
              children: _types.map((t) {
                final selected = _selectedType == t;
                final color = t == 'All' ? AppColors.primary : _typeColor(t);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(t),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedType = t),
                    selectedColor: color.withValues(alpha: 0.15),
                    checkmarkColor: color,
                    labelStyle: TextStyle(
                      color: selected ? color : AppColors.textSecondary,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 13,
                    ),
                    side: BorderSide(color: selected ? color : const Color(0xFFE0E0E0)),
                  ),
                );
              }).toList(),
            ),
          ),
          // List
          Expanded(
            child: coaAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text(e.toString(), style: AppTextStyles.bodySmall),
                    TextButton.icon(
                      onPressed: () => ref.invalidate(_coaProvider),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (accounts) {
                final filtered = accounts.where((a) {
                  final matchType = _selectedType == 'All' || a.accountType == _selectedType;
                  final matchSearch = _searchQuery.isEmpty ||
                      a.accountCode.toLowerCase().contains(_searchQuery) ||
                      a.accountName.toLowerCase().contains(_searchQuery);
                  return matchType && matchSearch;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.account_tree_outlined, size: 56,
                            color: AppColors.textSecondary.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(accounts.isEmpty ? 'No accounts yet' : 'No results found',
                            style: AppTextStyles.titleSmall),
                        if (accounts.isEmpty) ...[
                          const SizedBox(height: 8),
                          Text('Tap + to add your first account',
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(AppDimensions.md),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _AccountCard(
                    account: filtered[i],
                    onToggle: () => _toggleAccount(filtered[i]),
                    onDelete: () => _deleteAccount(filtered[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Account'),
      ),
    );
  }
}

// ── Account Card ──────────────────────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  final AccountItem account;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _AccountCard({required this.account, required this.onToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(account.accountType);
    final icon  = _typeIcon(account.accountType);

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.sm),
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md, vertical: AppDimensions.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: const Color(0xFFE8EDF3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(account.accountCode,
                          style: AppTextStyles.labelSmall.copyWith(
                              color: color, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(account.accountName,
                        style: AppTextStyles.bodyMedium,
                        overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const SizedBox(height: 2),
                Text('${account.accountType} · ${account.accountGroup}',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
          // Actions
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textSecondary),
            onSelected: (v) {
              if (v == 'toggle') onToggle();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'toggle',
                child: Row(children: [
                  Icon(account.allowDirectPosting
                      ? Icons.toggle_off_rounded : Icons.toggle_on_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(account.allowDirectPosting ? 'Deactivate' : 'Activate'),
                ]),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: AppColors.error)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
