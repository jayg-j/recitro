import 'package:flutter/material.dart';

import '../models/call_outcome.dart';
import '../theme/app_theme.dart';

/// Initials avatar used for every student.
class StudentAvatar extends StatelessWidget {
  const StudentAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.background,
    this.foreground,
  });

  final String name;
  final double size;
  final Color? background;
  final Color? foreground;

  static String initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background ?? AppColors.navy.withValues(alpha: 0.08),
      ),
      child: Text(
        initials(name),
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: foreground ?? AppColors.navy,
        ),
      ),
    );
  }
}

/// Uppercase section label with an optional count.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.count, this.trailing});

  final String title;
  final int? count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.page,
        Space.xl,
        Space.page,
        Space.sm,
      ),
      child: Row(
        children: [
          Text(title.toUpperCase(), style: style),
          if (count != null) ...[
            const SizedBox(width: Space.sm),
            Text('$count', style: style?.copyWith(color: AppColors.ink)),
          ],
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

/// Large page title used at the top of each tab.
class PageTitle extends StatelessWidget {
  const PageTitle({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.page,
        Space.xl,
        Space.page,
        Space.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: text.headlineMedium),
          if (subtitle != null) ...[
            const SizedBox(height: Space.xs),
            Text(subtitle!, style: text.bodyMedium?.copyWith(
              color: AppColors.muted,
            )),
          ],
        ],
      ),
    );
  }
}

/// Small rounded label, e.g. a status.
class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.filled = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: fg, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class PriorityPill extends StatelessWidget {
  const PriorityPill({super.key});

  @override
  Widget build(BuildContext context) => const Pill(
        label: 'Priority',
        color: AppColors.navy,
        icon: Icons.flag_rounded,
      );
}

Color outcomeColor(CallOutcome outcome) => switch (outcome) {
      CallOutcome.notCalled => AppColors.muted,
      CallOutcome.pending => AppColors.amberInk,
      CallOutcome.answered => AppColors.teal,
      CallOutcome.notAnswered => AppColors.red,
    };

IconData outcomeIcon(CallOutcome outcome) => switch (outcome) {
      CallOutcome.notCalled => Icons.schedule_rounded,
      CallOutcome.pending => Icons.record_voice_over_rounded,
      CallOutcome.answered => Icons.check_circle_rounded,
      CallOutcome.notAnswered => Icons.remove_circle_rounded,
    };

/// A label/value pair used in summary cards.
class Stat extends StatelessWidget {
  const Stat({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: text.titleLarge),
        const SizedBox(height: 2),
        Text(label, style: text.bodySmall),
      ],
    );
  }
}

/// Points progress bar toward a reward.
class PointsProgress extends StatelessWidget {
  const PointsProgress({
    super.key,
    required this.earned,
    required this.required,
    this.height = 6,
  });

  final int earned;
  final int required;
  final double height;

  @override
  Widget build(BuildContext context) {
    final value = required <= 0 ? 1.0 : (earned / required).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: value,
        minHeight: height,
        backgroundColor: AppColors.line,
        color: value >= 1 ? AppColors.teal : AppColors.amber,
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.navy.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: AppColors.navy),
            ),
            const SizedBox(height: Space.lg),
            Text(title, style: text.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: Space.sm),
            Text(
              message,
              style: text.bodyMedium?.copyWith(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: Space.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Info banner with an icon, used for rules and notices.
class NoticeCard extends StatelessWidget {
  const NoticeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.color = AppColors.navy,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleSmall),
                const SizedBox(height: 2),
                Text(message, style: text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.red)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}
