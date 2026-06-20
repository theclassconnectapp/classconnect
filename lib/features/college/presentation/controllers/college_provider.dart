import 'package:flutter/material.dart';

import '../../domain/entities/college.dart';

class CollegeProvider extends ChangeNotifier {
  College? _selected;

  College? get selected => _selected;

  void select(College college) {
    _selected = college;
    notifyListeners();
  }

  void clear() {
    _selected = null;
    notifyListeners();
  }
}
