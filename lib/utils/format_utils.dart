/// Number and text formatting utilities.
String formatCompactCount(num value) {
  final double v = value.toDouble();
  if (v >= 1000000000) {
    final d = v / 1000000000.0;
    return d.toStringAsFixed(d >= 10 ? 0 : 1).replaceAll(RegExp(r'\.0$'), '') + 'B';
  }
  if (v >= 1000000) {
    final d = v / 1000000.0;
    return d.toStringAsFixed(d >= 10 ? 0 : 1).replaceAll(RegExp(r'\.0$'), '') + 'M';
  }
  if (v >= 1000) {
    final d = v / 1000.0;
    return d.toStringAsFixed(d >= 10 ? 0 : 1).replaceAll(RegExp(r'\.0$'), '') + 'K';
  }
  return v.toStringAsFixed(0);
}
