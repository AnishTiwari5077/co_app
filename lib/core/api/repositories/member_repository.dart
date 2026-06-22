import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api_client.dart';
class MemberListItem {
  final String id, memberCode, fullName, phone, status;
  final String? email, photoUrl;
  final double? totalSavings, totalLoans;

  MemberListItem({
    required this.id, required this.memberCode, required this.fullName,
    required this.phone, required this.status,
    this.email, this.photoUrl, this.totalSavings, this.totalLoans,
  });

  factory MemberListItem.fromJson(Map<String, dynamic> j) => MemberListItem(
    id: j['id'] as String? ?? '',
    memberCode: j['memberCode'] as String? ?? '',
    fullName: j['fullName'] as String? ?? '',
    phone: j['phoneNumber'] as String? ?? j['phone'] as String? ?? '',
    status: j['status'] as String? ?? 'Pending',
    email: j['email'] as String?,
    photoUrl: j['photoUrl'] as String?,
    totalSavings: (j['totalSavings'] as num?)?.toDouble(),
    totalLoans: (j['totalLoanOutstanding'] as num?)?.toDouble(),
  );
}
/// Matches backend RegisterMemberRequest exactly
class RegisterMemberRequest {
  final String firstName;
  final String? middleName;
  final String lastName;
  final String gender;
  final String? dateOfBirthAd;   // "yyyy-MM-dd"
  final String? citizenshipNumber;
  final String phoneNumber;
  final String? email;
  final String? addressDistrict;
  final String? addressMunicipality;
  final String? addressWard;
  final String? addressTole;
  final String? occupation;
  final String branchId;

  const RegisterMemberRequest({
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.gender,
    this.dateOfBirthAd,
    this.citizenshipNumber,
    required this.phoneNumber,
    this.email,
    this.addressDistrict,
    this.addressMunicipality,
    this.addressWard,
    this.addressTole,
    this.occupation,
    required this.branchId,
  });

  Map<String, dynamic> toJson() => {
    'firstName': firstName,
    if (middleName != null && middleName!.isNotEmpty) 'middleName': middleName,
    'lastName': lastName,
    'gender': gender,
    if (dateOfBirthAd != null && dateOfBirthAd!.isNotEmpty)
      'dateOfBirthAd': dateOfBirthAd,
    if (citizenshipNumber != null && citizenshipNumber!.isNotEmpty)
      'citizenshipNumber': citizenshipNumber,
    'phoneNumber': phoneNumber,
    if (email != null && email!.isNotEmpty) 'email': email,
    if (addressDistrict != null && addressDistrict!.isNotEmpty)
      'addressDistrict': addressDistrict,
    if (addressMunicipality != null && addressMunicipality!.isNotEmpty)
      'addressMunicipality': addressMunicipality,
    if (addressWard != null && addressWard!.isNotEmpty)
      'addressWard': addressWard,
    if (addressTole != null && addressTole!.isNotEmpty)
      'addressTole': addressTole,
    if (occupation != null && occupation!.isNotEmpty) 'occupation': occupation,
    'branchId': branchId,
  };
}

// â”€â”€ Repository â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class MemberRepository {
  final Dio _dio;
  MemberRepository(this._dio);

  Future<({List<MemberListItem> data, int total})> getMembers({
    int page = 1, int pageSize = 20, String? search, String? status,
  }) async {
    final response = await _dio.get('/api/v1/members', queryParameters: {
      'page': page,
      'pageSize': pageSize,
      if (search != null && search.isNotEmpty) 'search': search,
      if (status != null && status != 'All') 'status': status,
    });
    final envelope = response.data as Map<String, dynamic>;
    final raw = envelope['data'];
    final items = (raw is List ? raw : [])
        .map((e) => MemberListItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final pagination = envelope['pagination'] as Map<String, dynamic>?;
    final total = pagination?['totalCount'] as int?
        ?? envelope['totalCount'] as int?
        ?? items.length;
    return (data: items, total: total);
  }

  Future<String> registerMember(RegisterMemberRequest request) async {
    final response = await _dio.post('/api/v1/members', data: request.toJson());
    final body = response.data;
    if (body is Map<String, dynamic>) {
      // Backend returns {id, status} directly (201 CreatedAtAction)
      return body['id'] as String?
          ?? (body['data'] as Map<String, dynamic>?)?['id'] as String?
          ?? '';
    }
    return '';
  }

  Future<void> approveMember(String id) async {
    await _dio.post('/api/v1/members/$id/approve');
  }
}

final memberRepositoryProvider = Provider<MemberRepository>((ref) {
  return MemberRepository(ref.watch(dioProvider));
});


