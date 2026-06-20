import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/usecases/verify_role_code.dart';
import 'role_code_state.dart';

class RoleCodeCubit extends Cubit<RoleCodeState> {
  RoleCodeCubit({required VerifyRoleCode verifyRoleCode})
    : _verifyRoleCode = verifyRoleCode,
      super(const RoleCodeInitial());

  final VerifyRoleCode _verifyRoleCode;

  Future<void> verifyCode(String code) async {
    emit(const RoleCodeLoading());
    try {
      final UserRole role = await _verifyRoleCode(code);
      emit(RoleCodeVerified(role));
    } on ApiException catch (error) {
      emit(RoleCodeError(error.message));
    } catch (_) {
      emit(const RoleCodeError('Invalid or expired code'));
    }
  }
}
