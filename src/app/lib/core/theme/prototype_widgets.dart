import 'package:flutter/material.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';

/// Components inspired by the HTML prototype.
///
/// They keep the visual language consistent across screens: soft background,
/// rounded white cards, small overlines, muted captions and petrol accents.
class ProtoCard extends StatelessWidget {
  const ProtoCard({
    required this.child,
    this.padding = const EdgeInsets.all(15),
    this.margin = const EdgeInsets.only(bottom: 12),
    this.borderColor = AppColors.line,
    this.backgroundColor = Colors.white,
    this.borderRadius = 18,
    this.onTap,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color borderColor;
  final Color backgroundColor;
  final double borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBackground = isDark
        ? _darkCardBackground(backgroundColor)
        : backgroundColor;
    final effectiveBorder = borderColor == AppColors.line && isDark
        ? Colors.white.withValues(alpha: 0.14)
        : borderColor;

    final card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveBackground,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: effectiveBorder),
      ),
      child: isDark
          ? IconTheme.merge(
              data: IconThemeData(color: Colors.white.withValues(alpha: 0.82)),
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: Colors.white),
                child: child,
              ),
            )
          : child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap,
        child: card,
      ),
    );
  }

  Color _darkCardBackground(Color color) {
    if (color == Colors.white || color.computeLuminance() > 0.72) {
      return const Color(0xFF0A4658);
    }

    return color;
  }
}

class ProtoGradientCard extends StatelessWidget {
  const ProtoGradientCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const RadialGradient(
          center: Alignment(0.9, -0.8),
          radius: 1.2,
          colors: [Color(0x6684DCCF), AppColors.petrol],
          stops: [0, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.petrol.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class ProtoOverline extends StatelessWidget {
  const ProtoOverline(this.text, {this.color = AppColors.muted, super.key});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: color == AppColors.muted && isDark ? Colors.white70 : color,
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
      ),
    );
  }
}

class ProtoScreenTitle extends StatelessWidget {
  const ProtoScreenTitle({
    required this.title,
    required this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                    color: isDark ? Colors.white : AppColors.petrol,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : AppColors.muted,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

class ProtoSectionHeading extends StatelessWidget {
  const ProtoSectionHeading({
    required this.title,
    this.overline,
    this.trailing,
    super.key,
  });

  final String title;
  final String? overline;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (overline case final text?) ProtoOverline(text),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                  color: isDark ? Colors.white : AppColors.petrol,
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class ProtoIconBox extends StatelessWidget {
  const ProtoIconBox({
    required this.icon,
    this.backgroundColor = AppColors.primarySoft,
    this.foregroundColor = AppColors.petrol,
    this.size = 36,
    super.key,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBackground =
        isDark && backgroundColor.computeLuminance() > 0.72
        ? Colors.white.withValues(alpha: 0.14)
        : backgroundColor;
    final effectiveForeground = isDark && foregroundColor == AppColors.petrol
        ? Colors.white
        : foregroundColor;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: effectiveBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: effectiveForeground, size: size * 0.52),
    );
  }
}

class ProtoChip extends StatelessWidget {
  const ProtoChip({
    required this.label,
    this.backgroundColor = AppColors.primarySoft,
    this.foregroundColor = AppColors.petrol,
    super.key,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBackground =
        isDark && backgroundColor.computeLuminance() > 0.72
        ? Colors.white.withValues(alpha: 0.14)
        : backgroundColor;
    final effectiveForeground = isDark && foregroundColor == AppColors.petrol
        ? Colors.white
        : foregroundColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: effectiveBackground,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: effectiveForeground,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class ProtoActionButton extends StatelessWidget {
  const ProtoActionButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.keyValue,
    super.key,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final String? keyValue;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: keyValue == null ? null : ValueKey(keyValue),
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.petrol,
        foregroundColor: Colors.white,
        fixedSize: const Size(38, 38),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 19),
    );
  }
}

class ProtoMutedText extends StatelessWidget {
  const ProtoMutedText(this.text, {this.maxLines, super.key});

  final String text;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Text(
      text,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: TextStyle(
        color: isDark ? Colors.white70 : AppColors.muted,
        fontSize: 11,
        height: 1.45,
      ),
    );
  }
}

class ProtoPageLoader extends StatelessWidget {
  const ProtoPageLoader({this.label = 'Chargement…', super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ProtoStateCard(
        icon: Icons.hourglass_empty_outlined,
        title: label,
        message: 'On récupère les dernières informations.',
        compact: true,
      ),
    );
  }
}

class ProtoStateCard extends StatelessWidget {
  const ProtoStateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.all(compact ? 18 : 24),
      child: ProtoCard(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.all(compact ? 16 : 18),
        backgroundColor: isDark ? AppColors.petrol : const Color(0xFFF8FCFE),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProtoIconBox(icon: icon, size: compact ? 46 : 54),
            SizedBox(height: compact ? 12 : 15),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isDark ? Colors.white : AppColors.petrol,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 5),
            ProtoMutedText(message),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh, size: 17),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
