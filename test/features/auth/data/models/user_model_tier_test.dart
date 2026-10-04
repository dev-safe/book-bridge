import 'package:book_bridge/features/auth/data/models/user_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final baseJson = <String, dynamic>{
    'id': 'user-1',
    'email': 'student@example.com',
    'full_name': 'Test Student',
    'created_at': '2026-10-01T00:00:00.000Z',
  };

  group('UserModel tier', () {
    test('defaults to free when tier is absent', () {
      final model = UserModel.fromJson(baseJson);

      expect(model.tier, 'free');
      expect(model.isPowerSeller, isFalse);
    });

    test('defaults to free when tier is null', () {
      final model = UserModel.fromJson({...baseJson, 'tier': null});

      expect(model.tier, 'free');
    });

    test('parses power_seller', () {
      final model = UserModel.fromJson({...baseJson, 'tier': 'power_seller'});

      expect(model.tier, 'power_seller');
      expect(model.isPowerSeller, isTrue);
    });

    test('toJson writes tier', () {
      final model = UserModel.fromJson({...baseJson, 'tier': 'power_seller'});

      expect(model.toJson()['tier'], 'power_seller');
    });

    test('entity round-trip keeps tier', () {
      final model = UserModel.fromJson({...baseJson, 'tier': 'power_seller'});

      final restored = UserModel.fromEntity(model.toEntity());

      expect(restored.isPowerSeller, isTrue);
    });

    test('copyWith updates tier', () {
      final user = UserModel.fromJson(baseJson).toEntity();

      expect(user.copyWith(tier: 'power_seller').isPowerSeller, isTrue);
      expect(user.copyWith().tier, 'free');
    });
  });
}
