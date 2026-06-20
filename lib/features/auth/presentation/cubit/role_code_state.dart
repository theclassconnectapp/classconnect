import '../../domain/entities/user_role.dart';

abstract class RoleCodeState {
  const RoleCodeState();
}

class RoleCodeInitial extends RoleCodeState {
  const RoleCodeInitial();
}

class RoleCodeLoading extends RoleCodeState {
  const RoleCodeLoading();
}

class RoleCodeVerified extends RoleCodeState {
  const RoleCodeVerified(this.role);

  final UserRole role;
}

class RoleCodeError extends RoleCodeState {
  const RoleCodeError(this.message);

  final String message;
}
