import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/recitro_store.dart';
import 'data/settings_store.dart';
import 'screens/main_shell.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = RecitroStore();
  final settings = SettingsStore();
  await Future.wait([store.init(), settings.init()]);
  runApp(RecitroApp(store: store, settings: settings));
}

class RecitroApp extends StatelessWidget {
  const RecitroApp({super.key, required this.store, this.settings});

  final RecitroStore store;
  final SettingsStore? settings;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(
          value: settings ?? SettingsStore(persist: false),
        ),
      ],
      child: Consumer<SettingsStore>(
        builder: (context, settings, _) => MaterialApp(
          title: 'Recitro',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,
          home: const MainShell(),
        ),
      ),
    );
  }
}
