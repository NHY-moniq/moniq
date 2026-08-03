import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:moniq/data/providers/settings_providers.dart';
import 'package:moniq/presentation/router/app_router.dart';
import 'package:moniq/presentation/theme/app_theme.dart';
import 'package:moniq/presentation/theme/shift_theme.dart';

class MoniqApp extends HookConsumerWidget {
  const MoniqApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    final fontScale = ref.watch(fontScaleProvider);
    // 라이트: 오늘 근무가 나이트·오프면 surface 계열을 쿨톤으로 바꾼다.
    // 다크: surface가 무채색이라 톤 구분 없이 primary만 근무 색으로 맞춘다.
    final shiftTheme = ref.watch(todayShiftThemeProvider);

    return MaterialApp.router(
      title: 'OnorOff',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(shift: shiftTheme),
      darkTheme: AppTheme.dark(shift: shiftTheme),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(fontScale),
          ),
          child: child!,
        );
      },
    );
  }
}
