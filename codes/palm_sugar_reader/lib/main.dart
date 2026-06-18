import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/settings_service.dart';
import 'theme.dart';

/// 全局设置通知 — 通过 InheritedNotifier 向下传递主题和字号
class SettingsNotifier extends ChangeNotifier {
  ThemeMode themeMode;
  double fontSize;

  SettingsNotifier({this.themeMode = ThemeMode.system, this.fontSize = 18});

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    notifyListeners();
  }

  void setFontSize(double size) {
    fontSize = size;
    notifyListeners();
  }
}

class SettingsProvider extends InheritedNotifier<SettingsNotifier> {
  const SettingsProvider({
    super.key,
    required SettingsNotifier notifier,
    required super.child,
  }) : super(notifier: notifier);

  static SettingsNotifier of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<SettingsProvider>();
    assert(provider != null, 'No SettingsProvider found in context');
    return provider!.notifier!;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsService.load();
  runApp(PalmSugarReaderApp(settings: settings));
}

class PalmSugarReaderApp extends StatelessWidget {
  final AppSettings settings;

  const PalmSugarReaderApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    final notifier = SettingsNotifier(
      themeMode: settings.themeMode,
      fontSize: settings.fontSize,
    );

    return SettingsProvider(
      notifier: notifier,
      child: ListenableBuilder(
        listenable: notifier,
        builder: (context, _) {
          return MaterialApp(
            title: 'PalmSugarReader',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: notifier.themeMode,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
