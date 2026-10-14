// Formatação de valores para exibição (pt-BR), sem depender de `intl`.

/// "13/10/2026"
String formatDateBr(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year.toString().padLeft(4, '0')}';
}

/// "60" para 60.0, "62,5" para 62.5 — sem casas decimais inúteis.
String formatNumber(double value) {
  final isWhole = value == value.truncateToDouble();
  final text = isWhole ? value.toInt().toString() : value.toString();
  return text.replaceAll('.', ',');
}

/// "1.250 kg" — carga/volume com separador de milhar.
String formatKg(double value) {
  final rounded = double.parse(value.toStringAsFixed(1));
  final text = formatNumber(rounded);
  final parts = text.split(',');
  final integer = parts.first.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  final decimal = parts.length > 1 ? ',${parts[1]}' : '';
  return '$integer$decimal kg';
}
