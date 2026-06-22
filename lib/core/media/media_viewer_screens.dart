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

class _VideoViewerScreenState extends State<VideoViewerScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    _disposeVideoControllers();
    setState(() => _error = null);

    try {
      final VideoPlayerController controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
      await controller.initialize();
      if (!mounted) return;

      final Color primaryColor = Theme.of(context).colorScheme.primary;
      setState(() {
        _videoController = controller;
        _chewieController = ChewieController(
          videoPlayerController: controller,
          autoPlay: true,
          looping: false,
          allowFullScreen: true,
          allowMuting: true,
          allowPlaybackSpeedChanging: true,
          showControlsOnInitialize: true,
          aspectRatio: _videoAspectRatio(controller),
          placeholder: Container(color: Colors.black),
          materialProgressColors: ChewieProgressColors(
            playedColor: primaryColor,
            handleColor: primaryColor,
            backgroundColor: Colors.white24,
            bufferedColor: Colors.white38,
          ),
          errorBuilder: (context, errorMessage) =>
              _buildErrorView(context, errorMessage),
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  double _videoAspectRatio(VideoPlayerController controller) {
    final Size size = controller.value.size;
    if (size.width > 0 && size.height > 0) {
      return size.width / size.height;
    }
    return controller.value.aspectRatio;
  }

  void _disposeVideoControllers() {
    _chewieController?.dispose();
    _videoController?.dispose();
    _chewieController = null;
    _videoController = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _videoController?.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeVideoControllers();
    super.dispose();
  }

  Widget _buildLoadingView() {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading video…',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, String errorMessage) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off_outlined,
                color: Colors.white70,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                "Couldn't load video",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _init,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.title ?? 'Video'),
      ),
      body: Center(
        child: _error != null
            ? _buildErrorView(context, _error!)
            : _chewieController == null
            ? _buildLoadingView()
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
