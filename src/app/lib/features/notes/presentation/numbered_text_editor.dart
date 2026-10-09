import 'package:flutter/material.dart';
import 'package:studyflow_app/core/theme/app_colors.dart';

/// Chiffres de la gouttière : à chasse fixe, comme dans un éditeur de code.
TextStyle lineNumberStyle(BuildContext context, {double fontSize = 13}) {
  return TextStyle(
    color: context.sfMuted.withValues(alpha: 0.75),
    fontSize: fontSize,
    fontFamily: 'Menlo',
    fontFamilyFallback: const ['RobotoMono', 'monospace', 'Courier New'],
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

/// Zone de texte avec numéros de ligne, façon éditeur de code. Une ligne trop
/// longue qui passe à la ligne garde un seul numéro, comme dans un IDE.
class NumberedTextEditor extends StatelessWidget {
  const NumberedTextEditor({
    required this.controller,
    this.focusNode,
    this.onChanged,
    this.autofocus = false,
    this.hintText,
    this.fieldKey,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final String? hintText;
  final Key? fieldKey;

  static const _fontSize = 16.0;
  static const _lineHeight = 1.45;
  static const _gutterWidth = 30.0;
  static const _gap = 12.0;

  /// Place réservée au curseur par le champ de texte, à droite des lignes.
  static const _caretMargin = 3.0;

  @override
  Widget build(BuildContext context) {
    // Même hauteur imposée pour chaque ligne du texte et de la gouttière :
    // les numéros restent alignés quelles que soient les polices.
    const strut = StrutStyle(
      fontSize: _fontSize,
      height: _lineHeight,
      forceStrutHeight: true,
    );
    // Même style que celui du champ (police du thème comprise) : les
    // hauteurs calculées pour la gouttière correspondent au texte affiché.
    final style = Theme.of(context).textTheme.titleMedium!.merge(
      TextStyle(
        color: context.sfText,
        fontSize: _fontSize,
        height: _lineHeight,
        fontWeight: FontWeight.w400,
      ),
    );
    final textScaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final textWidth = constraints.maxWidth - _gutterWidth - _gap;

        return GestureDetector(
          // Toucher sous le texte place le curseur à la fin.
          behavior: HitTestBehavior.translucent,
          onTap: () => focusNode?.requestFocus(),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: _gutterWidth,
                    child: ListenableBuilder(
                      listenable: controller,
                      builder: (context, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (final (index, height) in _lineHeights(
                            controller.text,
                            style: style,
                            strut: strut,
                            width: textWidth - _caretMargin,
                            textScaler: textScaler,
                          ).indexed)
                            SizedBox(
                              height: height,
                              child: Text(
                                '${index + 1}',
                                key: ValueKey('note-line-number-${index + 1}'),
                                strutStyle: strut,
                                textScaler: textScaler,
                                style: lineNumberStyle(context),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: _gap),
                  Expanded(
                    child: TextField(
                      key: fieldKey,
                      controller: controller,
                      focusNode: focusNode,
                      autofocus: autofocus,
                      onChanged: onChanged,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      strutStyle: strut,
                      style: style,
                      // Ni bordure ni marge (le thème en ajoute par défaut) :
                      // le texte commence pile en face du numéro 1.
                      decoration: InputDecoration(
                        hintText: hintText,
                        isCollapsed: true,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Hauteur de chaque ligne du texte une fois mise en page (une ligne longue
  /// peut occuper plusieurs lignes à l'écran).
  static List<double> _lineHeights(
    String text, {
    required TextStyle style,
    required StrutStyle strut,
    required double width,
    required TextScaler textScaler,
  }) {
    return [
      for (final line in text.split('\n'))
        (TextPainter(
          text: TextSpan(text: line.isEmpty ? '​' : line, style: style),
          strutStyle: strut,
          textDirection: TextDirection.ltr,
          textScaler: textScaler,
        )..layout(maxWidth: width <= 0 ? 1 : width)).height,
    ];
  }
}
