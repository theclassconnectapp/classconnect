import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const String _keyOnboardingComplete = 'onboarding_complete';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyCollegeId = 'college_id';
  static const String _keyAccessCode = 'access_code';

  Future<void> setOnboardingComplete(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingComplete, value);
  }

  Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboardingComplete) ?? false;
  }

  Future<void> setThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyThemeMode, mode);
  }

  Future<String?> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyThemeMode);
  }

  Future<void> saveCollegeId(String collegeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCollegeId, collegeId);
  }

  Future<String?> getCollegeId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCollegeId);
  }

  Future<void> saveAccessCode(String accessCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccessCode, accessCode);
  }

  Future<String?> getAccessCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccessCode);
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
