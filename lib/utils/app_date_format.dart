import 'package:intl/intl.dart';

/// Formatação das datas exibidas nos cartões de nota.
///
/// As datas são guardadas em UTC (ISO 8601) para que a comparação
/// `updatedAt` usada na sincronização funcione entre fusos diferentes, e
/// convertidas para a hora local só na hora de mostrar.
class AppDateFormat {
  const AppDateFormat._();

  static final _dayMonthYear = DateFormat('dd/MM/yyyy');
  static final _dayMonthYearHour = DateFormat("dd/MM/yyyy 'às' HH:mm");
  static final _hour = DateFormat('HH:mm');

  /// "Hoje às 14:32", "Ontem às 09:10" ou "12/03/2026 às 08:05".
  static String friendly(DateTime utcDate) {
    final date = utcDate.toLocal();
    final now = DateTime.now();

    final day = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);

    final difference = today.difference(day).inDays;

    if (difference == 0) return 'Hoje às ${_hour.format(date)}';
    if (difference == 1) return 'Ontem às ${_hour.format(date)}';

    return _dayMonthYearHour.format(date);
  }

  static String short(DateTime utcDate) =>
      _dayMonthYear.format(utcDate.toLocal());
}
