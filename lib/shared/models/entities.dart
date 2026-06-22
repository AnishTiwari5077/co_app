// ─── Auth ─────────────────────────────────────────────────────────────────────
class UserEntity {
  final String id;
  final String username;
  final String fullName;
  final String email;
  final String branchId;
  final String branchCode;
  final String branchName;
  final List<String> roles;
  final List<String> permissions;
  final bool isHeadOffice;

  const UserEntity({
    required this.id,
    required this.username,
    required this.fullName,
    required this.email,
    required this.branchId,
    required this.branchCode,
    required this.branchName,
    required this.roles,
    required this.permissions,
    this.isHeadOffice = false,
  });

  bool hasPermission(String permission) => permissions.contains(permission);
  bool hasRole(String role) => roles.contains(role);
  bool get isAdmin => hasRole('Administrator') || isHeadOffice;
  bool get isManager => hasRole('Manager') || isAdmin;
  bool get isCashier => hasRole('Cashier');
  bool get isLoanOfficer => hasRole('LoanOfficer');

  factory UserEntity.fromJson(Map<String, dynamic> json) => UserEntity(
    id: json['id'] as String,
    username: json['username'] as String? ?? '',
    fullName: json['fullName'] as String,
    email: json['email'] as String? ?? '',
    branchId: (json['branchId'] ?? '') as String,
    branchCode: json['branchCode'] as String? ?? 'HO',
    branchName: json['branchName'] as String? ?? '',
    roles: List<String>.from(json['roles'] as List? ?? []),
    permissions: List<String>.from(json['permissions'] as List? ?? []),
    isHeadOffice: json['isHeadOffice'] as bool? ?? false,
  );
}

// ─── Dashboard Models ─────────────────────────────────────────────────────────
class DashboardSummary {
  final int activeMembers;
  final int newMembersThisMonth;
  final double totalSavings;
  final double totalLoanOutstanding;
  final double todayDeposits;
  final double todayWithdrawals;
  final double todayLoanRepayments;
  final int overdueLoans;
  final int pendingMemberApprovals;
  final int pendingLoanApprovals;
  final double cashPosition;
  final String fiscalYear;
  final NpaSummary npa;
  final List<MonthlyVolume> monthlyVolume;

  const DashboardSummary({
    required this.activeMembers,
    required this.newMembersThisMonth,
    required this.totalSavings,
    required this.totalLoanOutstanding,
    required this.todayDeposits,
    required this.todayWithdrawals,
    required this.todayLoanRepayments,
    required this.overdueLoans,
    required this.pendingMemberApprovals,
    required this.pendingLoanApprovals,
    required this.cashPosition,
    required this.fiscalYear,
    required this.npa,
    required this.monthlyVolume,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> j) => DashboardSummary(
    activeMembers: j['activeMembers'] as int? ?? 0,
    newMembersThisMonth: j['newMembersMonth'] as int? ?? 0,
    totalSavings: (j['totalSavings'] as num?)?.toDouble() ?? 0,
    totalLoanOutstanding: (j['totalLoanOutstanding'] as num?)?.toDouble() ?? 0,
    todayDeposits: (j['todayDeposits'] as num?)?.toDouble() ?? 0,
    todayWithdrawals: (j['todayWithdrawals'] as num?)?.toDouble() ?? 0,
    todayLoanRepayments: (j['todayLoanRepayments'] as num?)?.toDouble() ?? 0,
    overdueLoans: j['overdueLoans'] as int? ?? 0,
    pendingMemberApprovals: j['pendingMemberApprovals'] as int? ?? 0,
    pendingLoanApprovals: j['pendingLoanApprovals'] as int? ?? 0,
    cashPosition: (j['cashPosition'] as num?)?.toDouble() ?? 0,
    fiscalYear: j['fiscalYear'] as String? ?? '',
    npa: NpaSummary.fromJson(j['npa'] as Map<String, dynamic>? ?? {}),
    monthlyVolume: (j['monthlyVolume'] as List? ?? [])
        .map((e) => MonthlyVolume.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  double get todayNetCash => todayDeposits + todayLoanRepayments - todayWithdrawals;
}

class NpaSummary {
  final double standardPercent;
  final double watchlistPercent;
  final double substandardPercent;
  final double doubtfulPercent;
  final double lossPercent;
  final double totalNpaAmount;
  final double npaPercentOfPortfolio;

  const NpaSummary({
    required this.standardPercent,
    required this.watchlistPercent,
    required this.substandardPercent,
    required this.doubtfulPercent,
    required this.lossPercent,
    required this.totalNpaAmount,
    required this.npaPercentOfPortfolio,
  });

  factory NpaSummary.fromJson(Map<String, dynamic> j) => NpaSummary(
    standardPercent: (j['standardPercent'] as num?)?.toDouble() ?? 95,
    watchlistPercent: (j['watchlistPercent'] as num?)?.toDouble() ?? 2.5,
    substandardPercent: (j['substandardPercent'] as num?)?.toDouble() ?? 1.3,
    doubtfulPercent: (j['doubtfulPercent'] as num?)?.toDouble() ?? 0.7,
    lossPercent: (j['lossPercent'] as num?)?.toDouble() ?? 0.5,
    totalNpaAmount: (j['totalNpaAmount'] as num?)?.toDouble() ?? 0,
    npaPercentOfPortfolio: (j['npaPercent'] as num?)?.toDouble() ?? 0,
  );

  bool get isHealthy => npaPercentOfPortfolio < 3.0;
}

class MonthlyVolume {
  final String month;
  final double deposits;
  final double withdrawals;
  final double loanRepayments;

  const MonthlyVolume({
    required this.month,
    required this.deposits,
    required this.withdrawals,
    required this.loanRepayments,
  });

  factory MonthlyVolume.fromJson(Map<String, dynamic> j) => MonthlyVolume(
    month: j['month'] as String? ?? '',
    deposits: (j['deposits'] as num?)?.toDouble() ?? 0,
    withdrawals: (j['withdrawals'] as num?)?.toDouble() ?? 0,
    loanRepayments: (j['loanRepayments'] as num?)?.toDouble() ?? 0,
  );
}

// ─── Member Models ────────────────────────────────────────────────────────────
class MemberEntity {
  final String id;
  final String memberCode;
  final String branchId;
  final String firstName;
  final String lastName;
  final String? firstNameNp;
  final String? lastNameNp;
  final String gender;
  final String dateOfBirthAd;
  final String? dateOfBirthBs;
  final String citizenshipNumber;
  final String phonePrimary;
  final String? phoneSecondary;
  final String? email;
  final String? occupation;
  final String? addressDistrict;
  final String? addressMunicipality;
  final bool kycVerified;
  final String status;
  final String? membershipDateAd;
  final String? membershipDateBs;
  final double totalSavings;
  final double totalLoanOutstanding;
  final int sharesHeld;

  const MemberEntity({
    required this.id,
    required this.memberCode,
    required this.branchId,
    required this.firstName,
    required this.lastName,
    this.firstNameNp,
    this.lastNameNp,
    required this.gender,
    required this.dateOfBirthAd,
    this.dateOfBirthBs,
    required this.citizenshipNumber,
    required this.phonePrimary,
    this.phoneSecondary,
    this.email,
    this.occupation,
    this.addressDistrict,
    this.addressMunicipality,
    required this.kycVerified,
    required this.status,
    this.membershipDateAd,
    this.membershipDateBs,
    this.totalSavings = 0,
    this.totalLoanOutstanding = 0,
    this.sharesHeld = 0,
  });

  String get fullName => '$firstName $lastName'.trim();
  bool get isActive => status == 'Active';
  bool get isPending => status == 'Pending';
  bool get isSuspended => status == 'Suspended';

  factory MemberEntity.fromJson(Map<String, dynamic> j) => MemberEntity(
    id: j['id'] as String,
    memberCode: j['memberCode'] as String? ?? '',
    branchId: j['branchId'] as String,
    firstName: j['firstName'] as String,
    lastName: j['lastName'] as String,
    firstNameNp: j['firstNameNp'] as String?,
    lastNameNp: j['lastNameNp'] as String?,
    gender: j['gender'] as String,
    dateOfBirthAd: j['dateOfBirthAd'] as String,
    dateOfBirthBs: j['dateOfBirthBs'] as String?,
    citizenshipNumber: j['citizenshipNumber'] as String,
    phonePrimary: j['phonePrimary'] as String,
    phoneSecondary: j['phoneSecondary'] as String?,
    email: j['email'] as String?,
    occupation: j['occupation'] as String?,
    addressDistrict: j['addressDistrict'] as String?,
    addressMunicipality: j['addressMunicipality'] as String?,
    kycVerified: j['kycVerified'] as bool? ?? false,
    status: j['status'] as String,
    membershipDateAd: j['membershipDateAd'] as String?,
    membershipDateBs: j['membershipDateBs'] as String?,
    totalSavings: (j['totalSavings'] as num?)?.toDouble() ?? 0,
    totalLoanOutstanding: (j['totalLoanOutstanding'] as num?)?.toDouble() ?? 0,
    sharesHeld: j['sharesHeld'] as int? ?? 0,
  );
}

// ─── Loan Models ──────────────────────────────────────────────────────────────
class LoanEntity {
  final String id;
  final String loanNumber;
  final String memberId;
  final String memberName;
  final String branchId;
  final String productName;
  final double requestedAmount;
  final double approvedAmount;
  final double disbursedAmount;
  final double outstandingPrincipal;
  final double outstandingInterest;
  final double accruedPenalty;
  final double interestRate;
  final int tenureMonths;
  final double emiAmount;
  final String interestMethod;
  final String status;
  final String npaClassification;
  final int overdueDays;
  final String? disbursedDateBs;
  final String? maturityDateBs;
  final String? nextEmiDateAd;
  final String purpose;

  const LoanEntity({
    required this.id,
    required this.loanNumber,
    required this.memberId,
    required this.memberName,
    required this.branchId,
    required this.productName,
    required this.requestedAmount,
    required this.approvedAmount,
    required this.disbursedAmount,
    required this.outstandingPrincipal,
    required this.outstandingInterest,
    required this.accruedPenalty,
    required this.interestRate,
    required this.tenureMonths,
    required this.emiAmount,
    required this.interestMethod,
    required this.status,
    required this.npaClassification,
    required this.overdueDays,
    this.disbursedDateBs,
    this.maturityDateBs,
    this.nextEmiDateAd,
    required this.purpose,
  });

  bool get isActive => status == 'Active';
  bool get isOverdue => status == 'Overdue';
  bool get isNpa => npaClassification != 'Standard';
  double get totalOutstanding => outstandingPrincipal + outstandingInterest + accruedPenalty;
  double get repaymentPercent => disbursedAmount > 0
      ? ((disbursedAmount - outstandingPrincipal) / disbursedAmount * 100).clamp(0, 100)
      : 0;

  factory LoanEntity.fromJson(Map<String, dynamic> j) => LoanEntity(
    id: j['id'] as String,
    loanNumber: j['loanNumber'] as String,
    memberId: j['memberId'] as String,
    memberName: j['memberName'] as String? ?? '',
    branchId: j['branchId'] as String,
    productName: j['productName'] as String? ?? '',
    requestedAmount: (j['requestedAmount'] as num?)?.toDouble() ?? 0,
    approvedAmount: (j['approvedAmount'] as num?)?.toDouble() ?? 0,
    disbursedAmount: (j['disbursedAmount'] as num?)?.toDouble() ?? 0,
    outstandingPrincipal: (j['outstandingPrincipal'] as num?)?.toDouble() ?? 0,
    outstandingInterest: (j['outstandingInterest'] as num?)?.toDouble() ?? 0,
    accruedPenalty: (j['accruedPenalty'] as num?)?.toDouble() ?? 0,
    interestRate: (j['interestRate'] as num?)?.toDouble() ?? 0,
    tenureMonths: j['tenureMonths'] as int? ?? 0,
    emiAmount: (j['emiAmount'] as num?)?.toDouble() ?? 0,
    interestMethod: j['interestMethod'] as String? ?? 'ReducingBalance',
    status: j['status'] as String,
    npaClassification: j['npaClassification'] as String? ?? 'Standard',
    overdueDays: j['overdueDays'] as int? ?? 0,
    disbursedDateBs: j['disbursedDateBs'] as String?,
    maturityDateBs: j['maturityDateBs'] as String?,
    nextEmiDateAd: j['nextEmiDateAd'] as String?,
    purpose: j['purpose'] as String? ?? '',
  );
}

// ─── Saving Account Models ────────────────────────────────────────────────────
class SavingAccountEntity {
  final String id;
  final String accountNumber;
  final String memberId;
  final String memberName;
  final String branchId;
  final String schemeName;
  final String schemeType;
  final double currentBalance;
  final double minimumBalance;
  final double? pledgedBalance;
  final double accruedInterest;
  final double totalDeposits;
  final double totalWithdrawals;
  final String status;
  final String openedDateBs;
  final String? lastTransactionAt;
  final double interestRate;

  const SavingAccountEntity({
    required this.id,
    required this.accountNumber,
    required this.memberId,
    required this.memberName,
    required this.branchId,
    required this.schemeName,
    required this.schemeType,
    required this.currentBalance,
    required this.minimumBalance,
    this.pledgedBalance,
    required this.accruedInterest,
    required this.totalDeposits,
    required this.totalWithdrawals,
    required this.status,
    required this.openedDateBs,
    this.lastTransactionAt,
    required this.interestRate,
  });

  bool get isActive => status == 'Active';
  bool get isFrozen => status == 'Frozen';
  double get availableBalance =>
      currentBalance - (pledgedBalance ?? 0) - minimumBalance;

  factory SavingAccountEntity.fromJson(Map<String, dynamic> j) =>
      SavingAccountEntity(
        id: j['id'] as String,
        accountNumber: j['accountNumber'] as String,
        memberId: j['memberId'] as String,
        memberName: j['memberName'] as String? ?? '',
        branchId: j['branchId'] as String,
        schemeName: j['schemeName'] as String? ?? '',
        schemeType: j['schemeType'] as String? ?? 'Regular',
        currentBalance: (j['currentBalance'] as num?)?.toDouble() ?? 0,
        minimumBalance: (j['minimumBalance'] as num?)?.toDouble() ?? 0,
        pledgedBalance: (j['pledgedBalance'] as num?)?.toDouble(),
        accruedInterest: (j['accruedInterest'] as num?)?.toDouble() ?? 0,
        totalDeposits: (j['totalDeposits'] as num?)?.toDouble() ?? 0,
        totalWithdrawals: (j['totalWithdrawals'] as num?)?.toDouble() ?? 0,
        status: j['status'] as String,
        openedDateBs: j['openedDateBs'] as String? ?? '',
        lastTransactionAt: j['lastTransactionAt'] as String?,
        interestRate: (j['interestRate'] as num?)?.toDouble() ?? 0,
      );
}

// ─── Transaction Model ────────────────────────────────────────────────────────
class TransactionEntity {
  final String id;
  final String receiptNumber;
  final String transactionType;  // Deposit | Withdrawal | Interest | Penalty
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String narration;
  final String transactionDateBs;
  final String transactionDateAd;
  final String processedBy;

  const TransactionEntity({
    required this.id,
    required this.receiptNumber,
    required this.transactionType,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.narration,
    required this.transactionDateBs,
    required this.transactionDateAd,
    required this.processedBy,
  });

  bool get isCredit =>
      transactionType == 'Deposit' || transactionType == 'Interest';

  factory TransactionEntity.fromJson(Map<String, dynamic> j) =>
      TransactionEntity(
        id: j['id'] as String,
        receiptNumber: j['receiptNumber'] as String? ?? '',
        transactionType: j['transactionType'] as String,
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        balanceBefore: (j['balanceBefore'] as num?)?.toDouble() ?? 0,
        balanceAfter: (j['balanceAfter'] as num?)?.toDouble() ?? 0,
        narration: j['narration'] as String? ?? '',
        transactionDateBs: j['transactionDateBs'] as String? ?? '',
        transactionDateAd: j['transactionDateAd'] as String? ?? '',
        processedBy: j['processedBy'] as String? ?? '',
      );
}

// ─── EMI Schedule Entry ───────────────────────────────────────────────────────
class EmiScheduleEntry {
  final int emiNumber;
  final String dueDateBs;
  final String dueDateAd;
  final double emiAmount;
  final double principalComponent;
  final double interestComponent;
  final double openingBalance;
  final double closingBalance;
  final String status;  // Pending | Paid | Overdue

  const EmiScheduleEntry({
    required this.emiNumber,
    required this.dueDateBs,
    required this.dueDateAd,
    required this.emiAmount,
    required this.principalComponent,
    required this.interestComponent,
    required this.openingBalance,
    required this.closingBalance,
    required this.status,
  });

  bool get isPaid => status == 'Paid';
  bool get isOverdue => status == 'Overdue';

  factory EmiScheduleEntry.fromJson(Map<String, dynamic> j) => EmiScheduleEntry(
    emiNumber: j['emiNumber'] as int,
    dueDateBs: j['dueDateBs'] as String? ?? '',
    dueDateAd: j['dueDateAd'] as String? ?? '',
    emiAmount: (j['emiAmount'] as num?)?.toDouble() ?? 0,
    principalComponent: (j['principalComponent'] as num?)?.toDouble() ?? 0,
    interestComponent: (j['interestComponent'] as num?)?.toDouble() ?? 0,
    openingBalance: (j['openingBalance'] as num?)?.toDouble() ?? 0,
    closingBalance: (j['closingBalance'] as num?)?.toDouble() ?? 0,
    status: j['status'] as String? ?? 'Pending',
  );
}

// ─── Pagination ───────────────────────────────────────────────────────────────
class PaginatedResponse<T> {
  final List<T> items;
  final int totalCount;
  final int page;
  final int pageSize;
  final bool hasNextPage;
  final bool hasPreviousPage;

  const PaginatedResponse({
    required this.items,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.hasNextPage,
    required this.hasPreviousPage,
  });

  int get totalPages => (totalCount / pageSize).ceil();
}
