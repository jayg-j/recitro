import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/recitro_store.dart';
import '../flows/course_form.dart';
import '../models/course.dart';
import '../theme/app_theme.dart';
import '../widgets/settings_sheet.dart';
import '../widgets/ui.dart';
import 'course_detail_screen.dart';

/// Opens the new-course dialog and then the new course.
Future<void> createCourse(BuildContext context) async {
  final id = await showCourseForm(context);
  if (id != null && context.mounted) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => CourseDetailScreen(courseId: id)),
    );
  }
}

class CoursesTab extends StatelessWidget {
  const CoursesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecitroStore>();
    final courses = store.courses;

    if (courses.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ContentWidth(
            child: PageTitle(title: 'Courses', trailing: SettingsButton()),
          ),
          Expanded(
            child: EmptyState(
              title: 'Add your first course',
              message:
                  'Each course has its own students and subjects, so you can '
                  'handle several classes.',
              action: FilledButton(
                key: const Key('firstCourse'),
                onPressed: () => createCourse(context),
                child: const Text('New course'),
              ),
            ),
          ),
        ],
      );
    }

    final total = store.students.length;
    return ContentWidth(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          PageTitle(
            title: 'Courses',
            subtitle:
                '${courses.length} ${courses.length == 1 ? 'course' : 'courses'}'
                ' · $total ${total == 1 ? 'student' : 'students'}',
            trailing: const SettingsButton(),
          ),
          const SizedBox(height: Space.md),
          for (final c in courses)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.page,
                0,
                Space.page,
                Space.md,
              ),
              child: _CourseCard(course: c),
            ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<RecitroStore>();
    final text = Theme.of(context).textTheme;
    final students = store.studentsInCourse(course.id).length;
    final sessions = store.sessionsInCourse(course.id).length;

    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CourseDetailScreen(courseId: course.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                course.name,
                style: text.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '$students ${students == 1 ? 'student' : 'students'}'
                ' · $sessions ${sessions == 1 ? 'session' : 'sessions'}',
                style: text.bodySmall,
              ),
              if (course.subjects.isNotEmpty) ...[
                const SizedBox(height: Space.md),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in course.subjects) SubjectTag(label: s),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Small, quiet label for a subject.
class SubjectTag extends StatelessWidget {
  const SubjectTag({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: p.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: p.ink, fontWeight: FontWeight.w500),
      ),
    );
  }
}
