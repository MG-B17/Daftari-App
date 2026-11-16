extension StringExtensions on String {
  String get toWesternDigits => String.fromCharCodes(
    runes.map((rune) {
      if (rune >= 0x0660 && rune <= 0x0669) return rune - 0x0660 + 0x30;
      return rune;
    }),
  );

  String? get nullIfBlank {
    final value = trim();
    return value.isEmpty ? null : value;
  }
}
