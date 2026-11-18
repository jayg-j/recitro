import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/recitro_store.dart';
import '../flows/session_form_screen.dart';
import '../models/recitation_session.dart';
import '../theme/app_theme.dart';
import '../widgets/dates.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/ui.dart';
import 'courses_tab.dart';
import 'session_detail_screen.dart';

/// Window width from which sessions show list and detail side by side
/// (tablets, landscape). Leaves ~360 for the list and 360+ for the session
/// next to the navigation rail.
bool sessionsTwoPane(double windowWidth) => windowWidth >= 800;

const double _listPaneWidth = 360;

class SessionsTab extends StatefulWidget {
  const SessionsTab({super.key});

  @override
  State<SessionsTab> createState() => _SessionsTabState();
}

class _SessionsTabState extends State<SessionsTab> {
  final _search = TextEditingController();
  bool _searching = false;
  String? _courseFilter;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;
      if (!_searching) _search.clear();
    });
  }

  List<RecitationSession> _visible(RecitroStore store) {
    final courseNames = {for (final c in store.courses) c.id: c.name};
    return store.sessions.reversed
        .where((s) => _courseFilter == null || s.courseId == _courseFilter)
        .where(
          (s) => matchesQuery(_search.text, [
            s.name,
            s.subject,
            courseNames[s.courseId] ?? '',
          ]),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecitroStore>();
    final twoPane = sessionsTwoPane(MediaQuery.sizeOf(context).width);

    // A filter for a deleted course is dropped.
    if (_courseFilter != null && store.courseById(_courseFilter!) == null) {
      _courseFilter = null;
    }

    if (store.sessions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ContentWidth(
            child: PageTitle(title: 'Sessions', trailing: SettingsButton()),
          ),
          Expanded(
            child: store.courses.isEmpty
                ? EmptyState(
                    title: 'Start with a course',
                    message:
                        'Add a course with its students and subjects, then '
                        'run sessions for it.',
                    action: FilledButton(
                      onPressed: () => createCourse(context),
                      child: const Text('New course'),
                    ),
                  )
                : EmptyState(
                    title: 'No sessions yet',
                    message: 'Start one when you\'re ready to call students.',
                    action: FilledButton(
                      onPressed: () => openSessionForm(
                        context,
                        onCreated: twoPane ? _select : null,
                      ),
                      child: const Text('New session'),
                    ),
                  ),
          ),
        ],
      );
    }

    final visible = _visible(store);

    if (!twoPane) {
      return ContentWidth(child: _list(store, visible, twoPane: false));
    }

    // Side by side: keep a valid selection, defaulting to the newest.
    if (_selectedId == null || store.sessionById(_selectedId!) == null) {
      _selectedId = visible.isNotEmpty ? visible.first.id : null;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: _listPaneWidth,
          child: _list(store, visible, twoPane: true),
        ),
        VerticalDivider(width: 1, color: context.palette.line),
        Expanded(
          child: _selectedId == null
              ? const EmptyState(
                  title: 'No session selected',
                  message: 'Choose a session from the list.',
                )
              : SessionDetailScreen(
                  key: ValueKey(_selectedId),
                  sessionId: _selectedId!,
                  embedded: true,
                  onClosed: () => setState(() => _selectedId = null),
                ),
        ),
      ],
    );
  }

  void _select(String id) => setState(() => _selectedId = id);

  Widget _list(
    RecitroStore store,
    List<RecitationSession> visible, {
    required bool twoPane,
  }) {
    final text = Theme.of(context).textTheme;
    final courses = store.courses;

    return ListView(
      padding: EdgeInsets.only(bottom: twoPane ? Space.xl : 96),
      children: [
        PageTitle(
          title: 'Sessions',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: const Key('searchSessions'),
                tooltip: _searching ? 'Close search' : 'Search sessions',
                isSelected: _searching,
                icon: Icon(Icons.search_rounded, color: context.palette.muted),
                selectedIcon:
                    Icon(Icons.close_rounded, color: context.palette.muted),
                onPressed: _toggleSearch,
              ),
              if (twoPane)
                IconButton(
                  key: const Key('newSessionPane'),
                  tooltip: 'New session',
                  icon: Icon(Icons.add_rounded, color: context.palette.muted),
                  onPressed: () =>
                      openSessionForm(context, onCreated: _select),
                ),
              const SettingsButton(),
            ],
          ),
        ),
        if (_searching)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.page,
              Space.sm,
              Space.page,
              0,
            ),
            child: SearchField(
              key: const Key('sessionSearch'),
              controller: _search,
              hint: 'Session, course or subject',
              autofocus: true,
            ),
          ),
        if (courses.length > 1)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(
                Space.page,
                Space.sm,
                Space.page,
                0,
              ),
              children: [
                _FilterChip(
                  label: 'All courses',
                  selected: _courseFilter == null,
                  onTap: () => setState(() => _courseFilter = null),
                ),
                for (final c in courses)
                  _FilterChip(
                    label: c.name,
                    selected: _courseFilter == c.id,
                    onTap: () => setState(
                      () => _courseFilter = _courseFilter == c.id ? null : c.id,
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: Space.md),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.page,
              vertical: Space.xl,
            ),
            child: Text(
              'No sessions match.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: context.palette.muted),
            ),
          ),
        for (final session in visible)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.page,
              0,
              Space.page,
              Space.md,
            ),
            child: _SessionCard(
              session: session,
              selected: twoPane && session.id == _selectedId,
              onTap: twoPane
                  ? () => _select(session.id)
                  : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              SessionDetailScreen(sessionId: session.id),
                        ),
                      ),
            ),
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(right: Space.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
        labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: 13,
              color: selected ? p.onPrimary : p.ink,
            ),
        selectedColor: p.primary,
        backgroundColor: p.surface,
        side: BorderSide(color: selected ? p.primary : p.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.selected,
    required this.onTap,
  });

  final RecitationSession session;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecitroStore>();
    final text = Theme.of(context).textTheme;
    final p = context.palette;
    final total = store.studentsFor(session).length;
    final called = store.calledCount(session);
    final priority = store.priorityWaitingCount(session);
    final date = sessionDateLabel(context, session.createdAt);
    final where = [
      store.courseById(session.courseId)?.name ?? '',
      session.subject,
    ].where((s) => s.isNotEmpty).join(' · ');

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? p.primary : p.line,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      session.name,
                      style: text.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (date != null) ...[
                    const SizedBox(width: Space.md),
                    Text(date, style: text.bodySmall),
                  ],
                ],
              ),
              if (where.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  where,
                  style: text.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: Space.lg),
              ProgressBar(value: called, max: total, height: 4),
              const SizedBox(height: Space.sm),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      total > 0 && called >= total
                          ? 'Everyone called'
                          : '$called of $total called',
                      style: text.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (priority > 0)
                    Text(
                      '$priority missed last time',
                      style: text.bodySmall?.copyWith(
                        color: p.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
