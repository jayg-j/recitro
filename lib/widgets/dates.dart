import 'package:flutter/material.dart';

/// Earliest date treated as real. Sessions saved before creation dates
/// were recorded load with the epoch, and show no date.
final _knownSince = DateTime(2020);

/// Short, human date for list rows:
/// "Today, 9:30 AM", "Yesterday, 2:10 PM", "Fri, Nov 14", "Nov 14, 2025".
/// Uses the device's locale and 12/24-hour setting.
String? sessionDateLabel(BuildContext context, DateTime date, {DateTime? now}) {
  if (date.isBefore(_knownSince)) return null;
  final l10n = MaterialLocalizations.of(context);
  final local = date.toLocal();
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final day = DateUtils.dateOnly(local);
  final diff = today.difference(day).inDays;

  String time() => l10n.formatTimeOfDay(
        TimeOfDay.fromDateTime(local),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );

  if (diff == 0) return 'Today, ${time()}';
  if (diff == 1) return 'Yesterday, ${time()}';
  if (local.year == today.year) return l10n.formatMediumDate(local);
  return l10n.formatShortDate(local);
}
