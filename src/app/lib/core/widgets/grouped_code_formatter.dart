import 'package:flutter/services.dart';

/// Code en majuscules découpé par un tiret : « abcdefgh » devient « ABCD-EFGH »
/// pendant la frappe. Le tiret apparaît dès le 4e caractère ; un retour
/// arrière juste après l'efface (« ABCD- » devient « ABCD »).
class GroupedCodeFormatter extends TextInputFormatter {
  const GroupedCodeFormatter({this.length = 8, this.groupSize = 4});

  final int length;
  final int groupSize;

  static final _notAlphanumeric = RegExp('[^A-Z0-9]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var raw = _clean(newValue.text);
    final isDeleting = newValue.text.length < oldValue.text.length;
    if (raw.length > length) raw = raw.substring(0, length);

    final buffer = StringBuffer();
    for (var index = 0; index < raw.length; index++) {
      if (index > 0 && index % groupSize == 0) buffer.write('-');
      buffer.write(raw[index]);
    }
    final reachedGroupEnd =
        raw.isNotEmpty && raw.length % groupSize == 0 && raw.length < length;
    if (reachedGroupEnd && !isDeleting) buffer.write('-');

    final text = buffer.toString();
    final cursorAtEnd = newValue.selection.end >= newValue.text.length;
    final offset = cursorAtEnd
        ? text.length
        : _offsetAfter(
            _clean(
              newValue.text.substring(0, newValue.selection.end),
            ).length.clamp(0, raw.length),
          ).clamp(0, text.length);

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  /// Position dans le texte formaté après [characters] caractères utiles.
  int _offsetAfter(int characters) =>
      characters == 0 ? 0 : characters + (characters - 1) ~/ groupSize;

  String _clean(String value) =>
      value.toUpperCase().replaceAll(_notAlphanumeric, '');
}
