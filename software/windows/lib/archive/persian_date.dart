// الگوریتم ابتدای سال برگرفته از jalaali-js با مجوز MIT موجود در پروژه.
class PersianDate {
  static DateTime start(int y) {
    const b = [
      -61,
      9,
      38,
      199,
      426,
      686,
      756,
      818,
      1111,
      1181,
      1210,
      1635,
      2060,
      2097,
      2192,
      2262,
      2324,
      2394,
      2456,
      3178,
    ];
    if (y < 1 || y > 3176) throw const FormatException('سال نامعتبر');
    var jp = b.first, l = -14, jump = 0;
    for (final m in b.skip(1)) {
      jump = m - jp;
      if (y < m) break;
      l += (jump ~/ 33) * 8 + (jump % 33) ~/ 4;
      jp = m;
    }
    final n = y - jp, g = y + 621;
    l += (n ~/ 33) * 8 + ((n % 33) + 3) ~/ 4;
    if (jump % 33 == 4 && jump - n == 4) l++;
    return DateTime.utc(
      g,
      3,
      20 + l - (g ~/ 4 - (((g ~/ 100) + 1) * 3) ~/ 4 - 150),
    );
  }

  static List<int> parts(DateTime v) {
    var y = v.year - 621;
    final d = DateTime.utc(v.year, v.month, v.day);
    if (d.isBefore(start(y))) y--;
    final n = d.difference(start(y)).inDays;
    return n < 186
        ? [y, n ~/ 31 + 1, n % 31 + 1]
        : [y, (n - 186) ~/ 30 + 7, (n - 186) % 30 + 1];
  }

  static String format(DateTime v) {
    final p = parts(v);
    return '${p[0]}/${p[1].toString().padLeft(2, '0')}/${p[2].toString().padLeft(2, '0')}';
  }

  static String latin(String s) {
    const f = '۰۱۲۳۴۵۶۷۸۹', a = '٠١٢٣٤٥٦٧٨٩';
    for (var i = 0; i < 10; i++) {
      s = s.replaceAll(f[i], '$i').replaceAll(a[i], '$i');
    }
    return s;
  }

  static DateTime parse(String s) {
    final p = latin(s).trim().split('/').map(int.tryParse).toList();
    if (p.length != 3 || p.any((n) => n == null)) {
      throw const FormatException('تاریخ مانند ۱۴۰۵/۰۷/۳۰ باشد');
    }
    final y = p[0]!, m = p[1]!, d = p[2]!;
    if (m < 1 || m > 12 || d < 1 || d > 31) {
      throw const FormatException('تاریخ نامعتبر');
    }
    final result = start(
      y,
    ).add(Duration(days: (m <= 7 ? (m - 1) * 31 : 186 + (m - 7) * 30) + d - 1));
    if (parts(result).join('/') != [y, m, d].join('/')) {
      throw const FormatException('روز ماه نامعتبر');
    }
    return result;
  }

  static DateTime tehran(DateTime v) =>
      v.toUtc().add(const Duration(hours: 3, minutes: 30));
  static DateTime boundary(String s, {bool end = false}) =>
      parse(s)
          .subtract(const Duration(hours: 3, minutes: 30))
          .add(end ? const Duration(days: 1) : Duration.zero);
}
