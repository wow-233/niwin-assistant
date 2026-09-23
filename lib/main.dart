import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/schedule_store.dart';
import 'screens/home_screen.dart';
import 'services/custom_font_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final store = ScheduleStore(preferences);
  runApp(ShiguangApp(store: store));
  unawaited(_bootstrap(store));
}

Future<void> _bootstrap(ScheduleStore store) async {
  await store.load();
  await store.recordAppOpen();
  final path = store.customFontPath;
  final family = store.customFontFamily;
  if (path != null && family != null) {
    try {
      final loaded = await CustomFontService.load(path, family);
      if (!loaded) await store.clearCustomFont();
      if (loaded) store.refresh();
    } catch (_) {
      await store.clearCustomFont();
    }
  }
  await NotificationService.instance.initialize();
  await NotificationService.instance.rescheduleAll(
    enabled: store.notificationsEnabled,
    homework: store.homework,
    courses: store.courses,
    semesterStart: store.semesterStart,
    periods: store.periodTimes,
    courseReminderMinutes: store.courseReminderMinutes,
  );
}

class ShiguangApp extends StatelessWidget {
  const ShiguangApp({super.key, required this.store});

  final ScheduleStore store;

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (dynamicLight, dynamicDark) => AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final seed = Color(store.seedColorValue);
          final lightScheme = store.useDynamicColor && dynamicLight != null
              ? dynamicLight.harmonized()
              : ColorScheme.fromSeed(seedColor: seed);
          final darkScheme = store.useDynamicColor && dynamicDark != null
              ? dynamicDark.harmonized()
              : ColorScheme.fromSeed(
                  seedColor: seed,
                  brightness: Brightness.dark,
                );
          return MaterialApp(
            title: '泥win助手',
            debugShowCheckedModeBanner: false,
            locale: const Locale('zh', 'CN'),
            supportedLocales: const [Locale('zh', 'CN')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            themeMode: switch (store.themeMode) {
              'light' => ThemeMode.light,
              'dark' => ThemeMode.dark,
              _ => ThemeMode.system,
            },
            theme: _theme(
              lightScheme,
              store.customFontFamily,
              store.glassEffect,
            ),
            darkTheme: _theme(
              darkScheme,
              store.customFontFamily,
              store.glassEffect,
            ),
            home: HomeScreen(store: store),
          );
        },
      ),
    );
  }

  ThemeData _theme(ColorScheme scheme, String? fontFamily, bool glass) {
    final dark = scheme.brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: scheme.surfaceContainer.withValues(
          alpha: glass ? .9 : 1,
        ),
        indicatorColor: scheme.secondaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow.withValues(alpha: glass ? .78 : 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(
          alpha: dark ? 0.55 : 0.7,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        },
      ),
    );
  }
}
