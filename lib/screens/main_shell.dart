import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/recitro_store.dart';
import '../flows/session_form_screen.dart';
import '../flows/student_create_flow.dart';
import 'sessions_tab.dart';
import 'students_tab.dart';

enum ShellSection { sessions, students }

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
      case ShellSection.students:
        await showStudentCreateFlow(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 720;

    final body = IndexedStack(
      index: _section.index,
      children: const [SessionsTab(), StudentsTab()],
    );

    final store = context.watch<RecitroStore>();
    // The empty state already shows its own button.
    final tabEmpty = _section == ShellSection.sessions
        ? store.sessions.isEmpty
        : store.students.isEmpty;

    final fab = tabEmpty ? null : FloatingActionButton.extended(
      key: Key(
        _section == ShellSection.sessions ? 'newSessionFab' : 'addStudentFab',
      ),
      onPressed: _onAdd,
      icon: const Icon(Icons.add_rounded),
      label: Text(
        _section == ShellSection.sessions ? 'New session' : 'Add student',
      ),
    );

    if (wide) {
      return Scaffold(
        floatingActionButton: fab,
        body: Row(
          children: [
            NavigationRail(
              extended: width >= 1000,
              selectedIndex: _section.index,
              onDestinationSelected: (i) =>
                  setState(() => _section = ShellSection.values[i]),
              groupAlignment: -0.9,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.auto_stories_outlined),
                  selectedIcon: Icon(Icons.auto_stories_rounded),
                  label: Text('Sessions'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.people_outline_rounded),
                  selectedIcon: Icon(Icons.people_rounded),
                  label: Text('Students'),
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
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories_rounded),
            label: 'Sessions',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Students',
          ),
        ],
      ),
    );
  }
}

