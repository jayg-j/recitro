import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/recitro_store.dart';
import '../flows/session_form_screen.dart';
import 'courses_tab.dart';
import 'sessions_tab.dart';

enum ShellSection { sessions, courses }

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  ShellSection _section = ShellSection.sessions;

  Future<void> _onAdd() async {
    switch (_section) {
      case ShellSection.sessions:
        await openSessionForm(context);
      case ShellSection.courses:
        await createCourse(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 720;

    final body = IndexedStack(
      index: _section.index,
      children: const [SessionsTab(), CoursesTab()],
    );

    final store = context.watch<RecitroStore>();
    final onSessions = _section == ShellSection.sessions;
    // Empty states show their own button; the side-by-side sessions layout
    // has "New session" in its list header instead.
    final hideFab = onSessions
        ? store.sessions.isEmpty || sessionsTwoPane(width)
        : store.courses.isEmpty;

    final fab = hideFab
        ? null
        : FloatingActionButton.extended(
            key: Key(onSessions ? 'newSessionFab' : 'newCourseFab'),
            onPressed: _onAdd,
            icon: const Icon(Icons.add_rounded),
            label: Text(onSessions ? 'New session' : 'New course'),
          );

    const sessionsIcon = Icon(Icons.auto_stories_outlined);
    const sessionsIconOn = Icon(Icons.auto_stories_rounded);
    const coursesIcon = Icon(Icons.school_outlined);
    const coursesIconOn = Icon(Icons.school_rounded);

    if (wide) {
      return Scaffold(
        floatingActionButton: fab,
        body: Row(
          children: [
            NavigationRail(
              extended: width >= 1200,
              selectedIndex: _section.index,
              onDestinationSelected: (i) =>
                  setState(() => _section = ShellSection.values[i]),
              groupAlignment: -0.9,
              destinations: const [
                NavigationRailDestination(
                  icon: sessionsIcon,
                  selectedIcon: sessionsIconOn,
                  label: Text('Sessions'),
                ),
                NavigationRailDestination(
                  icon: coursesIcon,
                  selectedIcon: coursesIconOn,
                  label: Text('Courses'),
                ),
              ],
            ),
            Expanded(child: SafeArea(child: body)),
          ],
        ),
      );
    }

    return Scaffold(
      floatingActionButton: fab,
      body: SafeArea(bottom: false, child: body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _section.index,
        onDestinationSelected: (i) =>
            setState(() => _section = ShellSection.values[i]),
        destinations: const [
          NavigationDestination(
            icon: sessionsIcon,
            selectedIcon: sessionsIconOn,
            label: 'Sessions',
          ),
          NavigationDestination(
            icon: coursesIcon,
            selectedIcon: coursesIconOn,
            label: 'Courses',
          ),
        ],
      ),
    );
  }
}
