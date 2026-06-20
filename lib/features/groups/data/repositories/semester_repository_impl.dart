class SemesterService {
  /// Parses the start year from a batch string like "2025-2029"
  static int? _startYear(String batch) {
    final parts = batch.split('-');
    if (parts.isEmpty) return null;
    return int.tryParse(parts[0].trim());
  }

  /// Returns the current semester number (1–8) for a given batch string.
  /// Returns null if the batch hasn't started yet or has already ended.
  static int? currentSemesterNumber(String batch) {
    final int? startYear = _startYear(batch);
    if (startYear == null) return null;

    final DateTime now = DateTime.now();
    final int currentYear = now.year;
    final int month = now.month;

    // How many full academic years have passed since batch started
    // Academic year starts in June (month 6)
    final int yearsElapsed = month >= 6
        ? currentYear - startYear
        : currentYear - startYear - 1;

    if (yearsElapsed < 0) return null; // batch hasn't started
    if (yearsElapsed > 3) return null; // batch has graduated

    // Within the year: June–Nov = odd semester, Dec–May = even semester
    final bool isOddHalf = month >= 6 && month <= 11;

    final int semNumber = (yearsElapsed * 2) + (isOddHalf ? 1 : 2);

    if (semNumber < 1 || semNumber > 8) return null;
    return semNumber;
  }

  /// Returns the semester label e.g. "S3" for a given batch string.
  static String? currentSemesterLabel(String batch) {
    final int? num = currentSemesterNumber(batch);
    if (num == null) return null;
    return 'S$num';
  }

  /// Returns all semester labels for a 4-year batch: S1 through S8
  static List<String> allSemesters() {
    return List.generate(8, (i) => 'S${i + 1}');
  }

  /// Returns true if the given semester label is the current one
  /// for the given batch string.
  static bool isCurrentSemester(String batch, String semesterLabel) {
    return currentSemesterLabel(batch) == semesterLabel;
  }

  /// Returns the current academic year label e.g. "2026-27"
  static String currentAcademicYear() {
    final DateTime now = DateTime.now();
    final int year = now.month >= 6 ? now.year : now.year - 1;
    return '$year-${(year + 1).toString().substring(2)}';
  }
}