import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/settings_store.dart';
import '../theme/app_theme.dart';
import 'ui.dart';

/// Gear button shown in page headers.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('openSettings'),
      tooltip: 'Settings',
      icon: Icon(Icons.settings_outlined, color: context.palette.muted),
      onPressed: () => showSettingsSheet(context),
    );
  }
}

Future<void> showSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
    builder: (_) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.page, 0, Space.page, Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Settings', style: text.titleLarge),
            const SizedBox(height: Space.xl),
            Text('Appearance', style: text.titleSmall),
            const SizedBox(height: Space.sm),
            LayoutBuilder(
              builder: (context, constraints) {
                // Icons only when there's room, so labels never wrap.
                final icons = constraints.maxWidth >= 320;
                ButtonSegment<ThemeMode> segment(
                  ThemeMode mode,
                  IconData icon,
                  String label,
                ) => ButtonSegment(
                  value: mode,
                  icon: icons ? Icon(icon, size: 18) : null,
                  label: Text(label, maxLines: 1, softWrap: false),
                );
                return SegmentedButton<ThemeMode>(
                  key: const Key('themeMode'),
                  showSelectedIcon: false,
                  segments: [
                    segment(
                      ThemeMode.system,
                      Icons.brightness_auto_outlined,
                      'System',
                    ),
                    segment(
                      ThemeMode.light,
                      Icons.light_mode_outlined,
                      'Light',
                    ),
                    segment(ThemeMode.dark, Icons.dark_mode_outlined, 'Dark'),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (s) => settings.setThemeMode(s.first),
                );
              },
            ),
            const SizedBox(height: Space.sm),
            Text(
              settings.themeMode == ThemeMode.system
                  ? 'Follows your device\'s setting.'
                  : 'Always ${settings.themeMode.name}, whatever the device uses.',
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
