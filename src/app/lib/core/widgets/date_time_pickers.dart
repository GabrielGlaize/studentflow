import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';

/// Sélecteurs de date et d'heure communs à toute l'app.
///
/// La date s'ouvre sur un calendrier (en français) et l'heure sur une roue
/// 24 h par pas de 5 minutes, avec un bouton « Valider » explicite.
abstract final class StudyFlowPickers {
  static Future<DateTime?> pickDate(
    BuildContext context, {
    required DateTime initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    String? helpText,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    final today = DateUtils.dateOnly(DateTime.now());
    final first = firstDate ?? today.subtract(const Duration(days: 365));
    final last = lastDate ?? today.add(const Duration(days: 730));
    final initial = initialDate.isBefore(first)
        ? first
        : initialDate.isAfter(last)
        ? last
        : initialDate;

    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: helpText,
      cancelText: 'Annuler',
      confirmText: 'Valider',
    );
  }

  static Future<TimeOfDay?> pickTime(
    BuildContext context, {
    required TimeOfDay initialTime,
    String title = 'Choisir l’heure',
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    // La roue exige une minute multiple du pas choisi.
    final rounded = _roundToFive(initialTime);
    var selected = rounded;

    return showModalBottomSheet<TimeOfDay>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.sfText,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(
                  height: 200,
                  child: CupertinoTheme(
                    data: CupertinoThemeData(
                      brightness: Theme.of(context).brightness,
                      textTheme: CupertinoTextThemeData(
                        dateTimePickerTextStyle: TextStyle(
                          color: context.sfText,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.time,
                      use24hFormat: true,
                      minuteInterval: 5,
                      initialDateTime: DateTime(
                        2000,
                        1,
                        1,
                        rounded.hour,
                        rounded.minute,
                      ),
                      onDateTimeChanged: (value) {
                        selected = TimeOfDay(
                          hour: value.hour,
                          minute: value.minute,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  key: const ValueKey('time-picker-confirm'),
                  onPressed: () => Navigator.pop(context, selected),
                  child: const Text('Valider'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static TimeOfDay _roundToFive(TimeOfDay value) {
    final total = ((value.hour * 60 + value.minute) / 5).round() * 5;
    final clamped = total.clamp(0, 23 * 60 + 55);
    return TimeOfDay(hour: clamped ~/ 60, minute: clamped % 60);
  }
}

/// Calculs de dates en jours de calendrier.
///
/// `date.add(Duration(days: 7))` ajoute 7 × 24 h : au passage à l'heure
/// d'hiver, on tombe la veille à 23 h et le cours change de jour.
abstract final class StudyFlowDates {
  static DateTime addDays(DateTime day, int days) =>
      DateTime(day.year, day.month, day.day + days);

  static DateTime mondayOf(DateTime day) =>
      DateTime(day.year, day.month, day.day - (day.weekday - DateTime.monday));
}

abstract final class StudyFlowFormat {
  static const _weekdays = [
    'lundi',
    'mardi',
    'mercredi',
    'jeudi',
    'vendredi',
    'samedi',
    'dimanche',
  ];

  static const _months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

  /// « Lundi 12 octobre ».
  static String longDay(DateTime day) {
    final weekday = _weekdays[day.weekday - 1];
    return '${weekday[0].toUpperCase()}${weekday.substring(1)} ${day.day} ${_months[day.month - 1]}';
  }

  /// « lun. 12/10 ».
  static String shortDay(DateTime day) {
    final weekday = _weekdays[day.weekday - 1].substring(0, 3);
    return '$weekday. ${_two(day.day)}/${_two(day.month)}';
  }

  static String time(TimeOfDay value) =>
      '${_two(value.hour)}:${_two(value.minute)}';

  static String timeOf(DateTime value) =>
      '${_two(value.hour)}:${_two(value.minute)}';

  /// « 1 h 30 », « 45 min ».
  static String duration(int minutes) {
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours == 0) return '$rest min';
    return rest == 0 ? '$hours h' : '$hours h ${_two(rest)}';
  }

  static TimeOfDay? parseTime(String? value) {
    if (value == null) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static int minutes(TimeOfDay value) => value.hour * 60 + value.minute;

  static TimeOfDay fromMinutes(int minutes) {
    final clamped = minutes.clamp(0, 23 * 60 + 59);
    return TimeOfDay(hour: clamped ~/ 60, minute: clamped % 60);
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
