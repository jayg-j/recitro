import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'data/recitro_store.dart';
import 'data/settings_store.dart';
import 'screens/main_shell.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Show the bundled font's license on Flutter's licenses page.
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(['Plus Jakarta Sans'], text);
  });
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
