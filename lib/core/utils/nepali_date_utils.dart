/// Nepali BS/AD date utilities.
/// BS (Bikram Sambat) is ~56 years 8 months ahead of AD.
class NepaliDateUtils {
  NepaliDateUtils._();

  // ── BS month data: days per month per year ────────────────────────────────
  // Source: Official Nepal Government BS calendar data 2000–2090 BS
  static const Map<int, List<int>> _bsCalendar = {
    2070: [31,32,31,32,31,30,30,30,29,29,30,30],
    2071: [31,31,32,31,31,31,30,29,30,29,30,30],
    2072: [31,32,31,32,31,30,30,30,29,30,29,31],
    2073: [30,32,31,32,31,30,30,30,29,30,29,31],
    2074: [31,31,32,31,31,31,30,29,30,29,30,30],
    2075: [31,31,32,32,31,30,30,29,30,29,30,30],
    2076: [31,32,31,32,31,30,30,30,29,29,30,31],
    2077: [30,32,31,32,31,30,30,30,29,30,29,31],
    2078: [31,31,32,31,31,31,30,29,30,29,30,30],
    2079: [31,31,32,32,31,30,30,29,30,29,30,30],
    2080: [31,32,31,32,31,30,30,30,29,29,30,30],
    2081: [31,31,32,31,31,31,30,29,30,29,30,30],
    2082: [31,31,32,32,31,30,30,29,29,30,30,30],
    2083: [31,32,31,32,31,30,30,30,29,29,30,30],
    2084: [31,31,32,31,31,31,30,29,30,29,30,30],
    2085: [31,31,32,32,31,30,30,29,30,29,30,30],
    2086: [31,32,31,32,31,30,30,30,29,29,30,31],
    2087: [30,32,31,32,31,30,30,30,29,30,29,31],
    2088: [31,31,32,31,31,31,30,29,30,29,30,30],
    2089: [31,31,32,32,31,30,30,29,30,29,30,30],
    2090: [31,32,31,32,31,30,30,30,29,29,30,30],
  };

  static const _adEpochYear  = 1943;
  static const _adEpochMonth = 4;
  static const _adEpochDay   = 14;
  static const _bsEpochYear  = 2000;
  static const _bsEpochMonth = 1;
  static const _bsEpochDay   = 1;

  /// Convert AD DateTime to BS date string "YYYY-MM-DD"
  static String adToBs(DateTime ad) {
    int totalAdDays = _daysBetween(
      DateTime(_adEpochYear, _adEpochMonth, _adEpochDay),
      ad,
    );

    int bsYear  = _bsEpochYear;
    int bsMonth = _bsEpochMonth;
    int bsDay   = _bsEpochDay;

    while (totalAdDays > 0) {
      final daysInMonth = _bsCalendar[bsYear]?[bsMonth - 1] ?? 30;
      if (totalAdDays < daysInMonth - bsDay + 1) {
        bsDay += totalAdDays;
        totalAdDays = 0;
      } else {
        totalAdDays -= daysInMonth - bsDay + 1;
        bsDay = 1;
        bsMonth++;
        if (bsMonth > 12) {
          bsMonth = 1;
          bsYear++;
        }
      }
    }

    return '${bsYear.toString().padLeft(4, '0')}-'
        '${bsMonth.toString().padLeft(2, '0')}-'
        '${bsDay.toString().padLeft(2, '0')}';
  }

  /// Convert BS date string "YYYY-MM-DD" to AD DateTime
  static DateTime bsToAd(String bsDate) {
    final parts = bsDate.split('-');
    final bsYear  = int.parse(parts[0]);
    final bsMonth = int.parse(parts[1]);
    final bsDay   = int.parse(parts[2]);

    var ad = DateTime(_adEpochYear, _adEpochMonth, _adEpochDay);

    for (int y = _bsEpochYear; y < bsYear; y++) {
      final days = _bsCalendar[y]?.fold(0, (a, b) => a + b) ?? 365;
      ad = ad.add(Duration(days: days));
    }
    for (int m = 1; m < bsMonth; m++) {
      final days = _bsCalendar[bsYear]?[m - 1] ?? 30;
      ad = ad.add(Duration(days: days));
    }
    ad = ad.add(Duration(days: bsDay - 1));
    return ad;
  }

  /// Get today's BS date string
  static String todayBs() => adToBs(DateTime.now());

  /// Get current Nepal fiscal year label e.g. "2081/82"
  static String currentFiscalYear() {
    final today = DateTime.now();
    final bsStr = adToBs(today);
    final bsYear = int.parse(bsStr.substring(0, 4));
    final bsMonth = int.parse(bsStr.substring(5, 7));
    // Nepal fiscal year starts Shrawan 1 (month 4)
    if (bsMonth >= 4) {
      return '$bsYear/${(bsYear + 1).toString().substring(2)}';
    } else {
      return '${bsYear - 1}/${bsYear.toString().substring(2)}';
    }
  }

  /// Format BS date for display: "2081 Baisakh 15"
  static String formatBsDisplay(String bsDate) {
    final parts = bsDate.split('-');
    final year  = parts[0];
    final month = int.parse(parts[1]);
    final day   = parts[2];
    return '$year ${_bsMonths[month - 1]} $day';
  }

  /// Format BS date in Nepali: "२०८१ बैशाख १५"
  static String formatBsNepali(String bsDate) {
    final parts = bsDate.split('-');
    final year  = _toNepaliDigits(parts[0]);
    final month = int.parse(parts[1]);
    final day   = _toNepaliDigits(parts[2]);
    return '$year ${_bsMonthsNp[month - 1]} $day';
  }

  static int _daysBetween(DateTime from, DateTime to) =>
      to.difference(from).inDays;

  static final List<String> _bsMonths = [
    'Baisakh','Jestha','Ashadh','Shrawan','Bhadra','Ashwin',
    'Kartik','Mangsir','Poush','Magh','Falgun','Chaitra',
  ];

  static final List<String> _bsMonthsNp = [
    'बैशाख','जेठ','असार','साउन','भदौ','असोज',
    'कार्तिक','मंसिर','पुष','माघ','फागुन','चैत',
  ];

  static String _toNepaliDigits(String s) {
    const np = ['०','१','२','३','४','५','६','७','८','९'];
    return s.split('').map((c) {
      final d = int.tryParse(c);
      return d != null ? np[d] : c;
    }).join();
  }
}
