import 'package:flutter/material.dart';

import '../../../../core/services/local_storage_service.dart';
import '../../data/repositories/college_repository.dart';
import '../../domain/entities/college.dart';

class CollegePickScreen extends StatefulWidget {
  const CollegePickScreen({super.key, required this.onPicked});

  final ValueChanged<String> onPicked;

  @override
  State<CollegePickScreen> createState() => _CollegePickScreenState();
}

class _CollegePickScreenState extends State<CollegePickScreen> {
  final CollegeRepository _repo = CollegeRepository();
  List<College> _colleges = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final colleges = await _repo.getColleges();
      setState(() {
        _colleges = colleges;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _select(College college) async {
    await LocalStorageService().saveCollegeId(college.id);
    if (!mounted) return;
    widget.onPicked(college.id);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                'Select your college',
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your data is scoped to your institution.',
                style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.70), fontSize: 14),
              ),
              const SizedBox(height: 32),
              if (_loading)
                Center(child: CircularProgressIndicator(color: colorScheme.primary))
              else if (_error != null)
                Center(child: Text(_error!, style: TextStyle(color: colorScheme.error)))
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: _colleges.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final college = _colleges[index];
                      return _CollegeCard(
                        college: college,
                        onTap: () => _select(college),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollegeCard extends StatelessWidget {
  const _CollegeCard({required this.college, required this.onTap});

  final College college;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            if (college.logoUrl != null)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: CircleAvatar(
                  backgroundImage: NetworkImage(college.logoUrl!),
                  radius: 20,
                ),
              ),
            Expanded(
              child: Text(
                college.name,
                style: TextStyle(color: colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: colorScheme.onSurface.withValues(alpha: 0.38)),
          ]
        ),
      ),
    );
  }
}
