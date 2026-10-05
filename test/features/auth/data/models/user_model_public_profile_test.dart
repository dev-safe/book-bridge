import 'package:book_bridge/features/auth/data/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final row = <String, dynamic>{
    'id': 'seller-1',
    'full_name': 'Ama Seller',
    'locality': 'Buea',
    'avatar_url': 'https://cdn.example.com/a.jpg',
    'rating': 4.5,
    'review_count': 2,
    'trust_score': 70,
    'trust_level': 'Sprout',
    'completed_deals_count': 3,
    'created_at': '2026-10-01T00:00:00.000Z',
    'tier': 'power_seller',
    'id_verified': true,
  };

  group('UserModel.fromPublicProfile', () {
    test('maps the public_profiles columns', () {
      final model = UserModel.fromPublicProfile(row);

      expect(model.id, 'seller-1');
      expect(model.fullName, 'Ama Seller');
      expect(model.locality, 'Buea');
      expect(model.rating, 4.5);
      expect(model.reviewCount, 2);
      expect(model.completedDealsCount, 3);
      expect(model.tier, 'power_seller');
      expect(model.idVerificationStatus, 'verified');
    });

    test('never carries contact or ID details', () {
      final model = UserModel.fromPublicProfile(row);

      expect(model.email, isEmpty);
      expect(model.whatsappNumber, isNull);
      expect(model.dateOfBirth, isNull);
      expect(model.guardianPhone, isNull);
    });

    test('treats a missing or false id_verified as unverified', () {
      expect(
        UserModel.fromPublicProfile({
          ...row,
          'id_verified': false,
        }).idVerificationStatus,
        'unverified',
      );
      expect(
        UserModel.fromPublicProfile(
          Map.of(row)..remove('id_verified'),
        ).idVerificationStatus,
        'unverified',
      );
    });

    test('select list matches the public_profiles view', () {
      expect(
        UserModel.publicProfileColumns.split(', ').toSet(),
        containsAll(['id', 'full_name', 'avatar_url', 'id_verified']),
      );
      expect(UserModel.publicProfileColumns, isNot(contains('whatsapp')));
    });
  });
}
