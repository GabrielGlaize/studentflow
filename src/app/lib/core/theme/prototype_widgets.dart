import 'package:flutter/material.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';

/// Composants partagés par tous les écrans : fonds neutres, cartes blanches
/// arrondies, petits sur-titres, légendes discrètes et accents pétrole.
class ProtoCard extends StatelessWidget {
  const ProtoCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.only(bottom: 12),
    this.borderColor = AppColors.line,
    this.backgroundColor = Colors.white,
    this.borderRadius = 18,
    this.onTap,
    this.onLongPress,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color borderColor;
  final Color backgroundColor;
  final double borderRadius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final isDark = context.sfIsDark;
    final effectiveBackground = isDark
        ? darkVariant(backgroundColor)
        : backgroundColor;
    final effectiveBorder = isDark && borderColor.computeLuminance() > 0.5
        ? AppColors.darkLine
        : borderColor;

    final card = Container(
      margin: margin,
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: effectiveBackground,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: effectiveBorder),
      ),
      child: child,
    );

    if (onTap == null && onLongPress == null) return card;

    return Padding(
      padding: margin,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            padding: padding,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: effectiveBackground,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: effectiveBorder),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  /// Un fond clair (blanc ou pastel) devient une surface anthracite qui garde
  /// une légère teinte de la couleur d'origine.
  static Color darkVariant(Color color) {
    if (color.computeLuminance() < 0.5) return color;
    if (color == Colors.white || color.computeLuminance() > 0.9) {
      return AppColors.darkSurface;
    }
    return Color.alphaBlend(
      color.withValues(alpha: 0.10),
      AppColors.darkSurface,
    );
  }
}

class ProtoGradientCard extends StatelessWidget {
  const ProtoGradientCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.petrol, Color(0xFF0E5A6E)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.petrol.withValues(
              alpha: context.sfIsDark ? 0 : 0.18,
            ),
            blurRadius: 24,
            offset: const Offset(0, 10),
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
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: color == AppColors.muted ? context.sfMuted : color,
        fontSize: 11,
        fontWeight: FontWeight.w800,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
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
                    letterSpacing: -0.8,
                    color: context.sfText,
                  ),
                ),
                const SizedBox(height: 4),
                // Deux lignes au plus : avec un bouton à droite (ou un grand
                // texte d'accessibilité), l'en-tête ne mange pas l'écran.
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.sfMuted,
                    fontSize: 14,
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
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (overline case final text?) ...[
                ProtoOverline(text),
                const SizedBox(height: 2),
              ],
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  letterSpacing: -0.3,
                  color: context.sfText,
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
    this.size = 40,
    super.key,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDark = context.sfIsDark;
    final effectiveBackground =
        isDark && backgroundColor.computeLuminance() > 0.5
        ? Color.alphaBlend(
            backgroundColor.withValues(alpha: 0.16),
            AppColors.darkSurfaceHigh,
          )
        : backgroundColor;
    final effectiveForeground =
        isDark && foregroundColor.computeLuminance() < 0.2
        ? AppColors.darkText
        : foregroundColor;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: effectiveBackground,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: effectiveForeground, size: size * 0.5),
    );
  }
}

class ProtoChip extends StatelessWidget {
  const ProtoChip({
    required this.label,
    this.backgroundColor = AppColors.primarySoft,
    this.foregroundColor = AppColors.petrol,
    this.icon,
    super.key,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isDark = context.sfIsDark;
    final effectiveBackground =
        isDark && backgroundColor.computeLuminance() > 0.5
        ? AppColors.darkSurfaceHigh
        : backgroundColor;
    final effectiveForeground =
        isDark && foregroundColor.computeLuminance() < 0.2
        ? AppColors.darkText
        : foregroundColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: effectiveBackground,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: effectiveForeground),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: effectiveForeground,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Indique d'un coup d'œil si un élément est partagé avec la classe ou
/// visible seulement par l'élève.
class ProtoVisibilityChip extends StatelessWidget {
  const ProtoVisibilityChip({required this.shared, super.key});

  final bool shared;

  @override
  Widget build(BuildContext context) {
    return ProtoChip(
      icon: shared ? Icons.groups_2_outlined : Icons.lock_outline,
      label: shared ? 'Classe' : 'Perso',
      backgroundColor: shared ? context.sfSharedSoft : context.sfPersonalSoft,
      foregroundColor: shared ? context.sfShared : context.sfPersonal,
    );
  }
}

/// Bandeau en tête des formulaires : rappelle qui verra ce qu'on crée.
class ProtoVisibilityBanner extends StatelessWidget {
  const ProtoVisibilityBanner({required this.shared, super.key});

  final bool shared;

  @override
  Widget build(BuildContext context) {
    final color = shared ? context.sfShared : context.sfPersonal;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: shared ? context.sfSharedSoft : context.sfPersonalSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            shared ? Icons.groups_2_outlined : Icons.lock_outline,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              shared
                  ? 'Partagé avec toute la classe'
                  : 'Visible uniquement par toi',
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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
      key: keyValue == null ? null : ValueKey<String>(keyValue!),
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: context.sfAccent,
        foregroundColor: context.sfOnAccent,
        fixedSize: const Size(42, 42),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
    );
  }
}

class ProtoMutedText extends StatelessWidget {
  const ProtoMutedText(this.text, {this.maxLines, super.key});

  final String text;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: TextStyle(color: context.sfMuted, fontSize: 13, height: 1.4),
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
    this.actionIcon = Icons.refresh,
    this.compact = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData actionIcon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(compact ? 0 : 24),
      child: ProtoCard(
        margin: EdgeInsets.only(bottom: compact ? 12 : 0),
        padding: EdgeInsets.all(compact ? 16 : 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProtoIconBox(icon: icon, size: compact ? 42 : 52),
            SizedBox(height: compact ? 10 : 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: context.sfText,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.sfMuted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ligne cliquable « libellé · valeur » des formulaires (date, heure…).
/// Elle ferme le clavier avant d'ouvrir le sélecteur, sinon le champ texte
/// précédent récupère le focus à la fermeture.
class ProtoPickerField extends StatelessWidget {
  const ProtoPickerField({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.keyValue,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final String? keyValue;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.sfCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: keyValue == null ? null : ValueKey<String>(keyValue!),
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          FocusManager.instance.primaryFocus?.unfocus();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.sfLine),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: context.sfMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(color: context.sfMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        color: context.sfText,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.expand_more, color: context.sfChevron),
            ],
          ),
        ),
      ),
    );
  }
}

/// Titre de groupe dans un formulaire (« Matière », « Horaires »…).
class ProtoFormLabel extends StatelessWidget {
  const ProtoFormLabel(this.text, {this.trailing, super.key});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: context.sfText,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
