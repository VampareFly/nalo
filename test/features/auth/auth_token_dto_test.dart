import 'package:flutter_test/flutter_test.dart';
import 'package:nalo/features/auth/auth_token.dart';

void main() {
  test('maps expires_in as a Unix-seconds timestamp', () {
    final token = AuthTokenDto.fromJson({
      'access_token': 'access',
      'refresh_token': 'refresh',
      'expires_in': 1786087969,
    }).toModel();

    expect(token.expiresAt.millisecondsSinceEpoch, 1786087969000);
  });
}
