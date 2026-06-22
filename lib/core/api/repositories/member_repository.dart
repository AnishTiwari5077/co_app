import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api_client.dart';

// ── DTOs ──────────────────────────────────────────────────────────────────────
class MemberListItem {
  final String id, memberCode, fullName, phone, status, memberType;
  final String? email, photoUrl;
  final DateTime registeredAt;
  MemberListItem({
    required this.id, required this.memberCode, required this.fullName,
    required this.phone, required this.status, required this.memberType,
    this.email, this.photoUrl, required this.registeredAt,
  });
  factory MemberListItem.fromJson(Map<String, dynamic> j) => MemberListItem(
    id: j['id'] as String,
    memberCode: j['memberCode'] as String? ?? '',
    fullName: j['fullName'] as String? ?? '',
    phone: j['phone'] as String? ?? '',
    status: j['status'] as String? ?? 'Pending',
    memberType: j['memberType'] as String? ?? 'Regular',
    email: j['email'] as String?,
    photoUrl: j['photoUrl'] as String?,
    registeredAt: DateTime.tryParse(j['registeredAt'] as String? ?? '') ?? DateTime.now(),
  );
}

class RegisterMemberRequest {
  final String firstName, lastName, phone, gender, occupation, education;
  final String? firstNameNp, lastNameNp, email, dateOfBirth;
  final String? citizenshipNo, panNo;
  final String? district, municipality, ward, tole;
  final String? nomineeName, nomineeRelation, nomineePhone;

  const RegisterMemberRequest({
    required this.firstName, required this.lastName,
    required this.phone, required this.gender,
    required this.occupation, required this.education,
    this.firstNameNp, this.lastNameNp, this.email, this.dateOfBirth,
    this.citizenshipNo, this.panNo,
    this.district, this.municipality, this.ward, this.tole,
    this.nomineeName, this.nomineeRelation, this.nomineePhone,
  });

  Map<String, dynamic> toJson() => {
    'firstName': firstName,
    'lastName': lastName,
    'firstNameNp': firstNameNp,
    'lastNameNp': lastNameNp,
    'phone': phone,
    'email': email,
    'gender': gender,
    'dateOfBirth': dateOfBirth,
    'occupation': occupation,
    'educationLevel': education,
    'citizenshipNo': citizenshipNo,
    'panNo': panNo,
    'permanentAddress': {
      'district': district,
      'municipality': municipality,
      'ward': ward,
      'tole': tole,
    },
    'nominee': nomineeName != null ? {
      'name': nomineeName,
      'relation': nomineeRelation,
      'phone': nomineePhone,
    } : null,
  };
}

// ── Repository ────────────────────────────────────────────────────────────────
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
    final items = (envelope['data'] as List<dynamic>? ?? [])
        .map((e) => MemberListItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return (data: items, total: envelope['totalCount'] as int? ?? items.length);
  }

  Future<String> registerMember(RegisterMemberRequest request) async {
    final response = await _dio.post('/api/v1/members', data: request.toJson());
    final envelope = response.data as Map<String, dynamic>;
    return envelope['id'] as String? ?? '';
  }

  Future<void> approveMember(String id) async {
    await _dio.post('/api/v1/members/$id/approve');
  }
}

final memberRepositoryProvider = Provider<MemberRepository>((ref) {
  return MemberRepository(ref.watch(dioProvider));
});
