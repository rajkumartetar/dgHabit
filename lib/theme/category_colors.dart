import 'package:flutter/material.dart';

Color categoryColor(BuildContext context, String category) {
  final c = category.toLowerCase().trim();
  final isDark = Theme.of(context).brightness == Brightness.dark;
  switch (c) {
    case 'personal':
      return isDark ? const Color(0xFFFFB300) : const Color(0xFFFFA000); // amber
    case 'hygiene':
      return isDark ? const Color(0xFF26A69A) : const Color(0xFF00897B); // teal
    case 'travel':
      return isDark ? const Color(0xFF5C6BC0) : const Color(0xFF3F51B5); // indigo
    case 'work':
      return isDark ? const Color(0xFF546E7A) : const Color(0xFF455A64); // blueGrey
    case 'fun':
      return isDark ? const Color(0xFFF06292) : const Color(0xFFE91E63); // pink
    case 'productivity':
      return isDark ? const Color(0xFF66BB6A) : const Color(0xFF43A047); // green
    case 'growth':
      return isDark ? const Color(0xFFBA68C8) : const Color(0xFF8E24AA); // purple
    default:
      return Theme.of(context).colorScheme.outlineVariant;
  }
}
