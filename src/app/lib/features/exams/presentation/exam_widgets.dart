import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';
import 'package:studyflow_app/core/widgets/date_time_pickers.dart';
import 'package:studyflow_app/features/exams/domain/exam_models.dart';

/// Une couleur par matière, prise dans la palette Swikko élargie.
class SubjectPalette {
  const SubjectPalette._(this.light, this.lightSoft, this.dark);

  final Color light;
  final Color lightSoft;
  final Color dark;

  static const _all = [
    SubjectPalette._(Color(0xFF2F6F8A), Color(0xFFE4F1F7), AppColors.sky),
    SubjectPalette._(Color(0xFF347F76), Color(0xFFE3F5F2), AppColors.mint),
    SubjectPalette._(Color(0xFF9A6170), Color(0xFFF7ECEF), Color(0xFFE5B9C3)),
    SubjectPalette._(Color(0xFF55698A), Color(0xFFE9EEF6), Color(0xFFBCCCE0)),
    SubjectPalette._(Color(0xFF8C6D2F), Color(0xFFF6F0E1), Color(0xFFE6CB8E)),
    SubjectPalette._(Color(0xFF6F5A8E), Color(0xFFF0ECF6), Color(0xFFCDB8E6)),
  ];

  static SubjectPalette at(int index) => _all[index % _all.length];

  Color accent(BuildContext context) => context.sfIsDark ? dark : light;

  Color soft(BuildContext context) =>
      context.sfIsDark ? dark.withValues(alpha: 0.14) : lightSoft;
}

/// Anneau de progression avec le pourcentage au centre.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    required this.value,
    required this.color,
    this.size = 48,
    this.strokeWidth = 5,
    this.label,
    this.trackColor,
    this.labelColor,
    super.key,
  });

  final double value;
  final Color color;
  final double size;
  final double strokeWidth;
  final String? label;
  final Color? trackColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final percent = (value.clamp(0, 1) * 100).round();

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1).toDouble()),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutCubic,
        builder: (context, animated, _) => CustomPaint(
          painter: _RingPainter(
            value: animated,
            color: color,
            track: trackColor ?? color.withValues(alpha: 0.16),
            strokeWidth: strokeWidth,
          ),
          child: Center(
            child: Text(
              label ?? '$percent %',
              style: TextStyle(
                color: labelColor ?? context.sfText,
                fontSize: size * 0.24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.color,
    required this.track,
    required this.strokeWidth,
  });

  final double value;
  final Color color;
  final Color track;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(strokeWidth / 2);
    final base = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawArc(arc, 0, math.pi * 2, false, base);

    if (value <= 0) return;
    final progress = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;
    canvas.drawArc(arc, -math.pi / 2, math.pi * 2 * value, false, progress);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}

/// « J-9 », « Jour J », « En cours ».
String examCountdownLabel(ExamSession session, DateTime now) {
  final days = session.daysUntilStart(now);
  if (session.isRunning(now)) return days == 0 ? 'Jour J' : 'En cours';
  if (days < 0) return 'Terminé';
  return 'J-$days';
}

/// « du lun. 19/10 au jeu. 22/10 ».
String examPeriodLabel(ExamSession session) {
  final start = StudyFlowFormat.shortDay(session.startsOn);
  if (DateUtils.isSameDay(session.startsOn, session.endsOn)) return 'le $start';
  return 'du $start au ${StudyFlowFormat.shortDay(session.endsOn)}';
}

/// « lun. 19/10 · 09:00 », ou « Date à préciser ».
String examSlotLabel(DateTime? day, String? startsAt) {
  if (day == null) return 'Date à préciser';
  final time = startsAt == null ? '' : ' · $startsAt';
  return '${StudyFlowFormat.shortDay(day)}$time';
}

/// En-tête des partiels : compte à rebours et progression personnelle.
class ExamCountdownHeader extends StatelessWidget {
  const ExamCountdownHeader({
    required this.session,
    this.compact = false,
    this.onTap,
    super.key,
  });

  final ExamSession session;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isDark = context.sfIsDark;
    final foreground = isDark ? AppColors.darkText : Colors.white;
    final mutedForeground = foreground.withValues(alpha: 0.78);
    final ringColor = isDark ? AppColors.mint : Colors.white;
    final checked = session.checkedCount;
    final total = session.itemCount;

    final content = Padding(
      padding: EdgeInsets.all(compact ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: compact ? 62 : 74,
                height: compact ? 62 : 74,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: foreground.withValues(alpha: 0.12),
                  border: Border.all(
                    color: foreground.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: Text(
                  examCountdownLabel(session, now),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: foreground,
                    fontSize: compact ? 17 : 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PARTIELS · ${session.subjects.length} ÉPREUVE${session.subjects.length > 1 ? 'S' : ''}',
                      style: TextStyle(
                        color: mutedForeground,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      session.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontSize: compact ? 17 : 20,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      examPeriodLabel(session),
                      style: TextStyle(color: mutedForeground, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                Icon(Icons.chevron_right, color: mutedForeground),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: session.progress),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 8,
                      color: ringColor,
                      backgroundColor: foreground.withValues(alpha: 0.18),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(session.progress * 100).round()} %',
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            total == 0
                ? 'La fiche est vide : ajoute ce qu’il faut réviser.'
                : 'Ta révision : $checked point${checked > 1 ? 's' : ''} sur $total coché${checked > 1 ? 's' : ''}',
            style: TextStyle(color: mutedForeground, fontSize: 13),
          ),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF1C3A40), Color(0xFF16292D)]
              : const [AppColors.petrol, Color(0xFF1F6B78)],
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: AppColors.petrol.withValues(alpha: 0.2),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          key: const ValueKey('exam-countdown'),
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: content,
        ),
      ),
    );
  }
}
