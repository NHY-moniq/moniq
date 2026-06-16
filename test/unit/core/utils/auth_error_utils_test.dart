import 'package:flutter_test/flutter_test.dart';
import 'package:moniq/core/utils/auth_error_utils.dart';

void main() {
  group('friendlyAuthError - code 기반', () {
    test('invalid_credentials', () {
      final msg = friendlyAuthError(
        'AuthApiException(message: Invalid login credentials, code: invalid_credentials)',
      );
      expect(msg, '이메일 또는 비밀번호가 맞지 않습니다.');
    });

    test('email_not_confirmed', () {
      final msg = friendlyAuthError('error(code: email_not_confirmed)');
      expect(msg, contains('이메일 인증'));
    });

    test('weak_password', () {
      final msg = friendlyAuthError('error(code: weak_password)');
      expect(msg, '비밀번호는 6자 이상이어야 합니다.');
    });

    test('user_already_exists / email_exists 동일 메시지', () {
      expect(
        friendlyAuthError('x(code: user_already_exists)'),
        '이미 가입된 이메일입니다.',
      );
      expect(
        friendlyAuthError('x(code: email_exists)'),
        '이미 가입된 이메일입니다.',
      );
    });
  });

  group('friendlyAuthError - message/raw fallback', () {
    test('code 없이 message 로 invalid credentials 추론', () {
      final msg = friendlyAuthError('message: Invalid login credentials)');
      expect(msg, '이메일 또는 비밀번호가 맞지 않습니다.');
    });

    test('SocketException 은 네트워크 오류로 매핑', () {
      final msg = friendlyAuthError('SocketException: Failed host lookup');
      expect(msg, '네트워크 연결을 확인해주세요.');
    });

    test('알 수 없는 오류는 기본 메시지', () {
      final msg = friendlyAuthError('완전히 새로운 오류');
      expect(msg, '오류가 발생했습니다. 잠시 후 다시 시도해주세요.');
    });
  });
}
