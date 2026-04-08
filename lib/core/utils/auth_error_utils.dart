/// Supabase AuthApiException 및 기타 인증 오류를 한국어 사용자 메시지로 변환합니다.
String friendlyAuthError(Object error) {
  final raw = error.toString();

  // Supabase error code 파싱 (code: xxx)
  final codeMatch = RegExp(r'code:\s*(\w+)').firstMatch(raw);
  final code = codeMatch?.group(1);

  // message 파싱 (message: xxx)
  final msgMatch = RegExp(r'message:\s*([^,)]+)').firstMatch(raw);
  final msg = msgMatch?.group(1)?.toLowerCase().trim() ?? '';

  if (code != null) {
    switch (code) {
      case 'invalid_credentials':
        return '이메일 또는 비밀번호가 맞지 않습니다.';
      case 'email_not_confirmed':
        return '이메일 인증이 완료되지 않았습니다. 받은 편지함을 확인해주세요.';
      case 'user_not_found':
        return '가입되지 않은 이메일입니다.';
      case 'user_already_exists':
      case 'email_exists':
        return '이미 가입된 이메일입니다.';
      case 'weak_password':
        return '비밀번호는 6자 이상이어야 합니다.';
      case 'email_address_invalid':
        return '올바르지 않은 이메일 형식입니다.';
      case 'over_email_send_rate_limit':
      case 'over_request_rate_limit':
        return '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.';
      case 'otp_expired':
        return '인증 링크가 만료되었습니다. 다시 요청해주세요.';
      case 'same_password':
        return '현재 비밀번호와 다른 비밀번호를 입력해주세요.';
      case 'signup_disabled':
        return '현재 회원가입이 불가합니다.';
      case 'session_not_found':
      case 'no_session':
        return '로그인 세션이 만료되었습니다. 다시 로그인해주세요.';
    }
  }

  // message 기반 fallback
  if (msg.contains('invalid login credentials') ||
      msg.contains('invalid password')) {
    return '이메일 또는 비밀번호가 맞지 않습니다.';
  }
  if (msg.contains('email not confirmed')) {
    return '이메일 인증이 완료되지 않았습니다. 받은 편지함을 확인해주세요.';
  }
  if (msg.contains('user already registered') ||
      msg.contains('already been registered')) {
    return '이미 가입된 이메일입니다.';
  }
  if (msg.contains('network') || raw.contains('SocketException')) {
    return '네트워크 연결을 확인해주세요.';
  }
  if (msg.contains('timeout')) {
    return '요청 시간이 초과되었습니다. 다시 시도해주세요.';
  }

  return '오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
}
