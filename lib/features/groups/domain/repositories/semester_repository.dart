abstract class SemesterRepository {
  int? currentSemesterNumber(String batch);
  String? currentSemesterLabel(String batch);
  List<String> allSemesters();
  bool isCurrentSemester(String batch, String semesterLabel);
  String currentAcademicYear();
}