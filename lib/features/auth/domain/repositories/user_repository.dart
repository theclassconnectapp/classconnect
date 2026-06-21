import '../entities/app_user.dart';

abstract class UserRepository {
  Future<AppUser?> getUser(String uid);
  Future<void> saveUser(AppUser user);
  Future<void> saveFcmToken({required String uid, required String token});
}
