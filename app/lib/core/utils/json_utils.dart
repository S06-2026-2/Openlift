// Leitura tolerante de JSON vindo da API.
//
// O backend serializa `Decimal` (carga, RPE) como string ("60.00") e datas
// como "yyyy-MM-dd"; estes helpers aceitam número OU string sem quebrar.

double? asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.replaceAll(',', '.'));
  return null;
}

int? asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

/// Converte "yyyy-MM-dd" (ou ISO completo) em [DateTime] local à meia-noite.
DateTime? parseApiDate(Object? value) {
  if (value is! String || value.length < 10) return null;
  final year = int.tryParse(value.substring(0, 4));
  final month = int.tryParse(value.substring(5, 7));
  final day = int.tryParse(value.substring(8, 10));
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

/// "yyyy-MM-dd" — formato de data da API.
String toApiDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}-$month-$day';
}
