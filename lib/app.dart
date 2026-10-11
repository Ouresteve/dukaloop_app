import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/main_shell.dart';
import 'features/onboarding/splash_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/shop_setup_screen.dart';
import 'providers/providers.dart';

class DukaLoopApp extends ConsumerStatefulWidget {
  const DukaLoopApp({super.key});

  @override
  ConsumerState<DukaLoopApp> createState() => _DukaLoopAppState();
}

class _DukaLoopAppState extends ConsumerState<DukaLoopApp> {
  bool _showSplash = true;
  bool? _onboardingDone;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _onboardingDone = prefs.getBool('onboarding_done') ?? false;
    });
  }

  void _finishSplash() {
    setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: SplashScreen(onFinished: _finishSplash),
      );
    }

    final shopAsync = ref.watch(currentShopProvider);

    return MaterialApp(
      title: 'DukaLoop',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: shopAsync.when(
        data: (shop) {
          if (shop == null) {
            // First time
            if (_onboardingDone == false) {
              return const OnboardingScreen();
            }
            return const ShopSetupScreen();
          }
          return const MainShell();
        },
        loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
        error: (err, _) => Scaffold(
          body: Center(child: Text('Error: $err')),
        ),
      ),
    );
  }
}