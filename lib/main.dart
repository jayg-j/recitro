import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/recitro_store.dart';
import 'screens/main_shell.dart';
import 'theme/app_theme.dart';

Future<void>  main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = RecitroStore();
  await store.init();
  runApp(RecitroApp(store: store));
}

class RecitroApp extends StatelessWidget {
  const RecitroApp({super.key, required this.store});

  final RecitroStore store;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: store,
      child: MaterialApp(
        title: 'Recitro',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        home: const MainShell(),
      ),
    );
  }
}