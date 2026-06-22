import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';

/// Full-screen in-app image is very far from the centre
class ImageViewerScreen extends StatelessWidget {
  const ImageViewerScreen({super.key, required this.imageUrl, this.title});

  final String imageUrl;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        title: Text(title ?? 'Image'),
      ),
      body: PhotoView(
        imageProvider: NetworkImage(imageUrl),
        backgroundDecoration: BoxDecoration(color: colorScheme.surface),
        loadingBuilder: (_, _) =>
            const Center(child: CircularProgressIndicator()),
        errorBuilder: (_, _, _) => Center(
          child: Text(
            'Failed to load image',
            style: TextStyle(color: colorScheme.onSurface),
          ),
        ),
      ),
    );
  }
}

/// Full-screen in-app video player.
class VideoViewerScreen extends StatefulWidget {
  const VideoViewerScreen({super.key, required this.videoUrl, this.title});

  final String videoUrl;
  final String? title;

  @override
  State<VideoViewerScreen> createState() => _VideoViewerScreenState();
}

class _VideoViewerScreenState extends State<VideoViewerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final VideoPlayerController controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _videoController = controller;
        _chewieController = ChewieController(
          videoPlayerController: controller,
          autoPlay: true,
          looping: false,
          allowFullScreen: true,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load video: $e');
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        title: Text(widget.title ?? 'Video'),
      ),
      body: Center(
        child: _error != null
            ? Text(_error!, style: TextStyle(color: colorScheme.onSurface))
            : _chewieController == null
            ? const CircularProgressIndicator()
            : Chewie(controller: _chewieController!),
      ),
    );
  }
}

/// Full-screen in-app PDF viewer. Downloads the PDF locally then renders it.
class PdfViewerScreen extends StatefulWidget {
  const PdfViewerScreen({super.key, required this.pdfUrl, this.title});

  final String pdfUrl;
  final String? title;

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  String? _localPath;
  String? _error;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    try {
      final http.Response response = await http.get(Uri.parse(widget.pdfUrl));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('PDF download failed: ${response.statusCode}');
        debugPrint('PDF response headers: ${response.headers}');
        throw Exception('HTTP ${response.statusCode}');
      }
      final Directory dir = await getTemporaryDirectory();
      final String name = widget.pdfUrl.split('/').last.split('?').first;
      final File file = File('${dir.path}/$name');
      await file.writeAsBytes(response.bodyBytes);
      if (!mounted) return;
      setState(() => _localPath = file.path);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load PDF: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title ?? 'Document')),
      body: _error != null
          ? Center(child: Text(_error!))
          : _localPath == null
          ? const Center(child: CircularProgressIndicator())
          : PDFView(filePath: _localPath!),
    );
  }
}
