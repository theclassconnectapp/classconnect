import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/animation/motion.dart';
import '../../domain/entities/user_role.dart';
import '../../domain/usecases/verify_role_code.dart';
import '../cubit/role_code_cubit.dart';
import '../cubit/role_code_state.dart';

class RoleCodeScreen extends StatelessWidget {
  const RoleCodeScreen({
    super.key,
    required this.role,
    required this.verifyRoleCode,
    required this.onRoleVerified,
    required this.onBack,
  });

  final UserRole role;
  final VerifyRoleCode verifyRoleCode;
  final void Function(UserRole role) onRoleVerified;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RoleCodeCubit>(
      create: (_) => RoleCodeCubit(verifyRoleCode: verifyRoleCode),
      child: _RoleCodeContent(
        role: role,
        onRoleVerified: onRoleVerified,
        onBack: onBack,
      ),
    );
  }
}

class _RoleCodeContent extends StatefulWidget {
  const _RoleCodeContent({
    required this.role,
    required this.onRoleVerified,
    required this.onBack,
  });

  final UserRole role;
  final void Function(UserRole role) onRoleVerified;
  final VoidCallback onBack;

  @override
  State<_RoleCodeContent> createState() => _RoleCodeContentState();
}

class _RoleCodeContentState extends State<_RoleCodeContent> {
  final TextEditingController _controller = TextEditingController();
  bool _obscure = true;

  void _submit() {
    context.read<RoleCodeCubit>().verifyCode(_controller.text.trim());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return BlocConsumer<RoleCodeCubit, RoleCodeState>(
      listener: (context, state) {
        if (state is RoleCodeVerified) {
          widget.onRoleVerified(state.role);
        } else if (state is RoleCodeError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        final bool loading = state is RoleCodeLoading;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Enter access code'),
            leading: PressableScale(
              onTap: widget.onBack,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter the code for ${widget.role.label}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Contact your administrator if you don\'t have a code.',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurface.withValues(alpha: 0.54),
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _controller,
                  enabled: !loading,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Access code',
                    border: const OutlineInputBorder(),
                    suffixIcon: loading
                        ? IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: null,
                          )
                        : PressableScale(
                            onTap: () => setState(() => _obscure = !_obscure),
                            child: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                  ),
                  onSubmitted: loading ? null : (_) => _submit(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: loading ? null : _submit,
                    child: loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Continue'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
