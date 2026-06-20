import '../../domain/entities/batch.dart';
import '../../domain/entities/department.dart';

abstract class CollegeState {
  const CollegeState();
}

class CollegeInitial extends CollegeState {
  const CollegeInitial();
}

class CollegeLoading extends CollegeState {
  const CollegeLoading();
}

class CollegeDepartmentsLoaded extends CollegeState {
  const CollegeDepartmentsLoaded(this.departments);

  final List<Department> departments;
}

class CollegeBatchesLoaded extends CollegeState {
  const CollegeBatchesLoaded(this.departments, this.batches);

  final List<Department> departments;
  final List<Batch> batches;
}

class CollegeError extends CollegeState {
  const CollegeError(this.message);

  final String message;
}

class CollegeScopeAssigned extends CollegeState {
  const CollegeScopeAssigned();
}
