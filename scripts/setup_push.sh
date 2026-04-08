#!/usr/bin/env bash
# Moniq FCM 푸시 설정 스크립트
# 사용자가 한 번에 실행할 수 있도록 묶음. 단계마다 멈추고 안내함.

set -e
cd "$(dirname "$0")/.."

bold() { printf "\033[1m%s\033[0m\n" "$*"; }
green() { printf "\033[32m%s\033[0m\n" "$*"; }
red() { printf "\033[31m%s\033[0m\n" "$*"; }

bold "=== Moniq FCM 푸시 설정 ==="
echo

# 1) Flutter 패키지
bold "[1/6] flutter pub get"
if command -v flutter >/dev/null 2>&1; then
  flutter pub get
  green "  ✓ pub get 완료"
else
  red "  ✗ flutter가 설치되지 않았습니다. https://docs.flutter.dev/get-started/install 참고"
  exit 1
fi
echo

# 2) freezed 재생성
bold "[2/6] build_runner (freezed 재생성)"
dart run build_runner build --delete-conflicting-outputs
green "  ✓ 코드 생성 완료"
echo

# 3) flutterfire CLI
bold "[3/6] flutterfire CLI 확인"
if ! command -v flutterfire >/dev/null 2>&1; then
  echo "  flutterfire CLI 설치 중..."
  dart pub global activate flutterfire_cli
  echo "  ⚠ ~/.pub-cache/bin 을 PATH에 추가하세요:"
  echo "    export PATH=\"\$PATH\":\"\$HOME/.pub-cache/bin\""
fi
green "  ✓ flutterfire 사용 가능"
echo

# 4) Firebase 프로젝트 연결
bold "[4/6] flutterfire configure (Firebase 프로젝트 선택)"
echo "  → 브라우저가 열리면 Google 로그인 후 프로젝트를 선택하세요."
echo "  → lib/firebase_options.dart 가 생성됩니다."
read -p "  계속하려면 Enter (건너뛰기 q): " skip
if [ "$skip" != "q" ]; then
  flutterfire configure
  green "  ✓ Firebase 프로젝트 연결 완료"

  # main.dart에 firebase_options import 자동 패치
  if [ -f lib/firebase_options.dart ] && ! grep -q "firebase_options.dart" lib/main.dart; then
    echo "  main.dart에 DefaultFirebaseOptions 적용 중..."
    sed -i '' "s|import 'package:firebase_core/firebase_core.dart';|import 'package:firebase_core/firebase_core.dart';\\
import 'firebase_options.dart';|" lib/main.dart
    sed -i '' "s|await Firebase.initializeApp();|await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);|" lib/main.dart
    green "  ✓ main.dart 패치 완료"
  fi
fi
echo

# 5) Supabase Edge Function 배포
bold "[5/6] Supabase Edge Function 배포"
if ! command -v supabase >/dev/null 2>&1; then
  red "  ✗ supabase CLI가 없습니다. brew install supabase/tap/supabase"
  exit 1
fi

if ! supabase projects list >/dev/null 2>&1; then
  echo "  Supabase에 로그인되어 있지 않습니다. supabase login 실행 중..."
  supabase login
fi

echo "  send-push 함수 배포 중..."
supabase functions deploy send-push
green "  ✓ Edge Function 배포 완료"
echo

# 6) FCM secrets
bold "[6/6] FCM 시크릿 등록"
echo "  Firebase Console → 프로젝트 설정 → 서비스 계정 → '새 비공개 키 생성'"
echo "  로 다운로드한 JSON 파일 경로를 입력하세요."
read -p "  Service account JSON 경로: " sa_path
read -p "  Firebase 프로젝트 ID: " fcm_project

if [ -f "$sa_path" ]; then
  supabase secrets set FCM_PROJECT_ID="$fcm_project"
  supabase secrets set FCM_SERVICE_ACCOUNT_JSON="$(cat "$sa_path")"
  green "  ✓ 시크릿 등록 완료"
else
  red "  ✗ 파일을 찾을 수 없습니다: $sa_path"
fi
echo

bold "=== 완료 ==="
echo
echo "남은 수동 작업:"
echo "  1) iOS: Xcode → Runner → Signing & Capabilities → +Capability"
echo "     → Push Notifications 추가, Background Modes → Remote notifications 체크"
echo "  2) iOS: Apple Developer Console에서 APNs Authentication Key 생성"
echo "     → Firebase Console → 프로젝트 설정 → Cloud Messaging에 업로드"
echo "  3) supabase db push 로 마이그레이션 적용"
echo "  4) flutter run 으로 실행 후 로그인하면 자동으로 fcm_token이 등록됨"
