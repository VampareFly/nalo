import 'package:flutter_test/flutter_test.dart';
import 'package:nalo/core/network/api_client.dart';

void main() {
  group('ApiResponse', () {
    test('parses a successful envelope', () {
      final response = ApiResponse<Map<String, dynamic>>.fromJson({
        'code': 0,
        'message': 'success',
        'data': {'id': 1},
      }, (data) => data! as Map<String, dynamic>);

      expect(response.code, 0);
      expect(response.data, {'id': 1});
    });

    test('rejects an invalid envelope', () {
      expect(
        () => ApiResponse<Object?>.fromJson({'message': 'success'}),
        throwsA(isA<ResponseFormatException>()),
      );
    });
  });
}
