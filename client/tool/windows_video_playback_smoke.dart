import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

const _videoPath = String.fromEnvironment('SIGNBRIDGE_SMOKE_VIDEO_PATH');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VideoPlaybackSmokeApp());
}

class VideoPlaybackSmokeApp extends StatelessWidget {
  const VideoPlaybackSmokeApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SignBridge video playback smoke check',
    theme: ThemeData.dark(),
    home: const VideoPlaybackSmokeScreen(),
  );
}

class VideoPlaybackSmokeScreen extends StatefulWidget {
  const VideoPlaybackSmokeScreen({super.key});

  @override
  State<VideoPlaybackSmokeScreen> createState() =>
      _VideoPlaybackSmokeScreenState();
}

class _VideoPlaybackSmokeScreenState extends State<VideoPlaybackSmokeScreen> {
  VideoPlayerController? _controller;
  String _status = 'Ready';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_runAllChecks());
    });
  }

  Future<void> _runAllChecks() async {
    setState(() => _busy = true);
    try {
      await _initialize();
      await _runChecks();
      await _disposePlayer();
    } catch (error) {
      debugPrint('PLAYBACK_SMOKE FAIL: $error');
      if (mounted) {
        setState(() => _status = 'FAIL: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _initialize() async {
    if (_videoPath.isEmpty) {
      throw StateError('Pass --dart-define=SIGNBRIDGE_SMOKE_VIDEO_PATH=<mp4>.');
    }
    final videoFile = File(_videoPath);
    if (!await videoFile.exists()) {
      throw FileSystemException('Smoke-test MP4 does not exist', _videoPath);
    }

    final controller = VideoPlayerController.file(videoFile);
    _controller = controller;
    await controller.initialize();
    if (!mounted) return;
    setState(() {
      _status = 'Initialized: ${controller.value.duration}';
    });
    debugPrint('PLAYBACK_SMOKE initialize PASS: ${controller.value.duration}');
  }

  Future<void> _runChecks() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    setState(() => _busy = true);

    try {
      await controller.seekTo(Duration.zero);
      await controller.play();
      await Future<void>.delayed(const Duration(milliseconds: 900));
      final playedPosition = controller.value.position;
      if (controller.value.hasError) {
        throw StateError(controller.value.errorDescription ?? 'Playback error');
      }
      if (playedPosition <= Duration.zero &&
          controller.value.duration > const Duration(seconds: 1)) {
        throw StateError('Playback position did not advance.');
      }
      debugPrint('PLAYBACK_SMOKE play PASS: $playedPosition');

      await controller.pause();
      if (controller.value.isPlaying) {
        throw StateError('Player remained active after pause.');
      }
      debugPrint('PLAYBACK_SMOKE pause PASS');

      final duration = controller.value.duration;
      if (duration > const Duration(milliseconds: 500)) {
        final target = Duration(milliseconds: duration.inMilliseconds ~/ 2);
        await controller.seekTo(target);
        await Future<void>.delayed(const Duration(milliseconds: 250));
        final actual = controller.value.position;
        if ((actual - target).abs() > const Duration(seconds: 1)) {
          throw StateError('Seek mismatch: target $target, got $actual.');
        }
        debugPrint('PLAYBACK_SMOKE seek PASS: $target -> $actual');
      } else {
        debugPrint('PLAYBACK_SMOKE seek SKIP: video is too short');
      }

      if (mounted) setState(() => _status = 'PASS: play, pause, seek');
    } catch (error) {
      debugPrint('PLAYBACK_SMOKE FAIL: $error');
      if (mounted) setState(() => _status = 'FAIL: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disposePlayer() async {
    final controller = _controller;
    if (controller == null) return;
    setState(() => _controller = null);
    await WidgetsBinding.instance.endOfFrame;
    await controller.dispose();
    if (!mounted) return;
    setState(() {
      _status = 'PASS: player disposed';
    });
    debugPrint('PLAYBACK_SMOKE dispose PASS');
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      unawaited(controller.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Windows MP4 playback smoke check')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText('File: $_videoPath'),
            const SizedBox(height: 12),
            Text('Status: $_status'),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: controller?.value.isInitialized == true
                    ? AspectRatio(
                        aspectRatio: controller!.value.aspectRatio,
                        child: VideoPlayer(controller),
                      )
                    : const Text('Initialize the selected SignBridge MP4.'),
              ),
            ),
            if (controller?.value.isInitialized == true)
              VideoProgressIndicator(controller!, allowScrubbing: true),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _busy || controller != null
                      ? null
                      : () async {
                          setState(() => _busy = true);
                          try {
                            await _initialize();
                          } catch (error) {
                            if (mounted)
                              setState(() => _status = 'FAIL: $error');
                            debugPrint(
                              'PLAYBACK_SMOKE initialize FAIL: $error',
                            );
                          } finally {
                            if (mounted) setState(() => _busy = false);
                          }
                        },
                  child: const Text('Initialize'),
                ),
                ElevatedButton(
                  onPressed: _busy || controller?.value.isInitialized != true
                      ? null
                      : _runChecks,
                  child: const Text('Run play / pause / seek checks'),
                ),
                ElevatedButton(
                  onPressed: _busy || controller == null
                      ? null
                      : _disposePlayer,
                  child: const Text('Dispose player'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
