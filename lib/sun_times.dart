import 'dart:math';

class SunTimes {
  const SunTimes({this.sunrise, this.sunset, this.status});
  final DateTime? sunrise, sunset;
  final String? status;
}

/// NOAA general solar equations, zenith 90.833 degrees (refraction + solar disc).
/// https://gml.noaa.gov/grad/solcalc/solareqns.PDF
/// Uses the device's local calendar/time zone, not a longitude-derived zone.
SunTimes calculateSunTimes(DateTime date, double latitude, double longitude) {
  if (!latitude.isFinite ||
      !longitude.isFinite ||
      latitude.abs() > 90 ||
      longitude.abs() > 180) {
    return const SunTimes(status: '位置无效');
  }
  final day = DateTime.utc(date.year, date.month, date.day);
  final ordinal = day.difference(DateTime.utc(date.year)).inDays + 1;
  final days = DateTime.utc(date.year + 1)
      .difference(DateTime.utc(date.year))
      .inDays;
  final gamma = 2 * pi / days * (ordinal - 1);
  final equation =
      229.18 *
      (.000075 +
          .001868 * cos(gamma) -
          .032077 * sin(gamma) -
          .014615 * cos(2 * gamma) -
          .040849 * sin(2 * gamma));
  final declination =
      .006918 -
      .399912 * cos(gamma) +
      .070257 * sin(gamma) -
      .006758 * cos(2 * gamma) +
      .000907 * sin(2 * gamma) -
      .002697 * cos(3 * gamma) +
      .00148 * sin(3 * gamma);
  final lat = latitude * pi / 180;
  final denominator = cos(lat) * cos(declination);
  final numerator = cos(90.833 * pi / 180) - sin(lat) * sin(declination);
  if (denominator.abs() < 1e-12) {
    return SunTimes(status: numerator < 0 ? '极昼 · 今日无日出日落' : '极夜 · 今日无日出日落');
  }
  final cosine = numerator / denominator;
  if (cosine < -1) return const SunTimes(status: '极昼 · 今日无日出日落');
  if (cosine > 1) return const SunTimes(status: '极夜 · 今日无日出日落');
  final angle = acos(cosine) * 180 / pi;
  // Align each UTC event with the requested local day, including date-line zones.
  DateTime event(double minutes) {
    var result = day.add(Duration(seconds: (minutes * 60).round())).toLocal();
    final wanted = DateTime.utc(date.year, date.month, date.day);
    final actual = DateTime.utc(result.year, result.month, result.day);
    result = result.add(Duration(days: wanted.difference(actual).inDays));
    return result;
  }

  return SunTimes(
    sunrise: event(720 - 4 * (longitude + angle) - equation),
    sunset: event(720 - 4 * (longitude - angle) - equation),
  );
}
