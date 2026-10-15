import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../app/theme/app_theme.dart';

class LocalVideoPlayer extends StatefulWidget {
  const LocalVideoPlayer({super.key, required this.filePath});

  final String filePath;

  @override
  State<LocalVideoPlayer> createState() => _LocalVideoPlayerState();
}

class _LocalVideoPlayerState extends State<LocalVideoPlayer> {
  VideoPlayerController? _controller;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final controller = VideoPlayerController.file(File(widget.filePath));
    _controller = controller;
    try {
      await controller.initialize();
      controller.addListener(_onControllerChanged);
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not open this video: $error';
      });
    }
  }

  @override
  void didUpdateWidget(covariant LocalVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      final oldController = _controller;
      oldController?.removeListener(_onControllerChanged);
      oldController?.dispose();
      _controller = null;
      _loading = true;
      _error = null;
      _initialize();
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_onControllerChanged);
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.teal),
      );
    }
    final controller = _controller;
    if (_error != null ||
        controller == null ||
        !controller.value.isInitialized) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error ?? 'Video playback is unavailable for this file.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.ivory),
          ),
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio > 0
                  ? controller.value.aspectRatio
                  : 16 / 9,
              child: VideoPlayer(controller),
            ),
          ),
        ),
        Row(
          children: [
            IconButton(
              tooltip: controller.value.isPlaying
                  ? 'Pause video'
                  : 'Play video',
              onPressed: () => setState(() {
                controller.value.isPlaying
                    ? controller.pause()
                    : controller.play();
              }),
              icon: Icon(
                controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                color: AppTheme.ivory,
              ),
            ),
            Expanded(
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: AppTheme.teal,
                  bufferedColor: AppTheme.mutedText,
                  backgroundColor: AppTheme.secondarySurface,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _format(controller.value.position),
              style: const TextStyle(color: AppTheme.ivory, fontSize: 12),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ],
    );
  }

  String _format(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
