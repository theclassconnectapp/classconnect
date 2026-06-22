import 'dart:async';

import 'package:flutter/material.dart';

class UploadProgressSheet extends StatefulWidget {
  const UploadProgressSheet({
    super.key,
    required this.fileName,
    required this.fileSize,
    required this.progressStream,
    required this.onCancel,
    this.onRetry,
    required this.uploadTask,
  });

  final String fileName;
  final String fileSize;
  final Stream<double> progressStream;
  final VoidCallback onCancel;
  final VoidCallback? onRetry;
  final Future<void> Function() uploadTask;

  @override
  State<UploadProgressSheet> createState() => _UploadProgressSheetState();
}

enum _UploadState { uploading, failed, success }

class _UploadProgressSheetState extends State<UploadProgressSheet> {
  StreamSubscription<double>? _progressSub;
  double _progress = 0;
  _UploadState _state = _UploadState.uploading;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _listenForProgress();
    _startUpload();
  }

  @override
  void dispose() {
    _progressSub?.cancel();
    super.dispose();
  }

  void _listenForProgress() {
    _progressSub = widget.progressStream.listen((double progress) {
      if (!mounted) return;
      setState(() => _progress = progress.clamp(0, 1).toDouble());
    });
  }

  Future<void> _startUpload() async {
    setState(() {
      _state = _UploadState.uploading;
      _errorMessage = null;
      _progress = 0;
    });
    try {
      await widget.uploadTask();
      if (!mounted) return;
      setState(() {
        _state = _UploadState.success;
        _progress = 1;
      });
      Timer(const Duration(milliseconds: 1500), () {
        if (mounted) Navigator.of(context).pop(true);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _UploadState.failed;
        _errorMessage = e.toString();
      });
    }
  }

  void _retry() {
    widget.onRetry?.call();
    _startUpload();
  }

  void _cancel() {
    widget.onCancel();
    Navigator.of(context).pop(false);
  }

  IconData get _fileIcon {
    final String lower = widget.fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.description_outlined;
    if (lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v')) {
      return Icons.video_file_outlined;
    }
    return Icons.photo_outlined;
  }

  String get _statusText {
    if (_progress >= 0.95) return 'Saving to group...';
    if (_progress >= 0.85) return 'Finalising...';
    if (_progress >= 0.60) return 'Almost there...';
    if (_progress >= 0.20) return 'Uploading...';
    return 'Preparing file...';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: switch (_state) {
            _UploadState.uploading => _UploadingView(
              key: const ValueKey<String>('uploading'),
              icon: _fileIcon,
              fileName: widget.fileName,
              fileSize: widget.fileSize,
              progress: _progress,
              statusText: _statusText,
              onCancel: _cancel,
            ),
            _UploadState.failed => _FailedView(
              key: const ValueKey<String>('failed'),
              errorMessage: _errorMessage ?? 'Something went wrong.',
              onRetry: _retry,
            ),
            _UploadState.success => const _SuccessView(
              key: ValueKey<String>('success'),
            ),
          },
        ),
      ),
    );
  }
}

class _UploadingView extends StatelessWidget {
  const _UploadingView({
    super.key,
    required this.icon,
    required this.fileName,
    required this.fileSize,
    required this.progress,
    required this.statusText,
    required this.onCancel,
  });

  final IconData icon;
  final String fileName;
  final String fileSize;
  final double progress;
  final String statusText;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final int percent = (progress * 100).round().clamp(0, 100);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fileSize,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                statusText,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Text(
              '$percent%',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: colorScheme.primary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: progress),
          duration: const Duration(milliseconds: 240),
          builder: (BuildContext context, double value, Widget? child) {
            return LinearProgressIndicator(
              value: value,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
            );
          },
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: onCancel, child: const Text('Cancel')),
        ),
      ],
    );
  }
}

class _FailedView extends StatelessWidget {
  const _FailedView({
    super.key,
    required this.errorMessage,
    required this.onRetry,
  });

  final String errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.error_outline, color: colorScheme.error, size: 44),
        const SizedBox(height: 12),
        Text('Upload failed', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(
          errorMessage,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 18),
        FilledButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          Icons.check_circle_outline,
          color: Colors.green.shade600,
          size: 48,
        ),
        const SizedBox(height: 12),
        Text(
          'Uploaded successfully',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }
}
