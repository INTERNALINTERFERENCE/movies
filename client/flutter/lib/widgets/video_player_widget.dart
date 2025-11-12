import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final Function(String, double?)? onVideoAction;
  final Function(VideoPlayerWidgetState)? onStateCreated;
  final bool isPortrait;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.onVideoAction,
    this.onStateCreated,
    this.isPortrait = false,
  });

  @override
  State<VideoPlayerWidget> createState() => VideoPlayerWidgetState();
}

class VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _ignoreNextAction = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    // Request focus after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _focusNode.dispose();
    _controller.removeListener(_onVideoStateChanged);
    _controller.removeListener(_onPositionChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleKeyPress(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        // Space bar toggles play/pause
        if (_controller.value.isPlaying) {
          _controller.pause();
        } else {
          _controller.play();
        }
        _showControlsTemporarily();
      }
    }
  }

  void _initializeVideo() {
    print('Initializing video with URL: ${widget.videoUrl}');
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );
    
    _controller.initialize().then((_) {
      print('Video initialized successfully');
      print('Video size: ${_controller.value.size}');
      print('Video duration: ${_controller.value.duration}');
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _controller.addListener(_onVideoStateChanged);
        _controller.addListener(_onPositionChanged);
        // Notify parent about state creation
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onStateCreated?.call(this);
        });
      }
    }).catchError((error, stackTrace) {
      print('Error initializing video: $error');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isInitialized = true; // Show error state
        });
      }
    });
  }

  Duration _lastPosition = Duration.zero;
  
  void _onPositionChanged() {
    final currentPosition = _controller.value.position;
    // Detect significant position change (seek)
    if ((currentPosition - _lastPosition).inSeconds.abs() > 1) {
      if (_ignoreNextAction) {
        print('[SYNC] Position change ignored (muted).');
        _lastPosition = currentPosition;
        return;
      }
      print('[SYNC] Detected user SEEK. Sending to server.');
      final time = currentPosition.inSeconds.toDouble();
      widget.onVideoAction?.call('seek', time);
    }
    _lastPosition = currentPosition;
  }

  void _onVideoStateChanged() {
    final bool isCurrentlyPlaying = _controller.value.isPlaying;

    // If the visual state and the internal state are already the same, do nothing.
    if (isCurrentlyPlaying == _isPlaying) return;

    print('[SYNC] Video state changed. New state: ${isCurrentlyPlaying ? "PLAYING" : "PAUSED"}');

    // Update the internal state immediately.
    _isPlaying = isCurrentlyPlaying;

    // Now, decide if we need to broadcast this change.
    // If we are in the "ignore" window, it means this change was caused by a server command.
    // So, we just update the state locally and don't send anything back.
    if (_ignoreNextAction) {
      print('[SYNC] State change was programmatic. Not sending to server.');
      return;
    }

    // If we are not ignoring, it means the user initiated this action. Broadcast it.
    if (isCurrentlyPlaying) {
      print('[SYNC] Detected user PLAY. Sending to server.');
      widget.onVideoAction?.call('play', null);
      _startHideControlsTimer();
    } else {
      print('[SYNC] Detected user PAUSE. Sending to server.');
      widget.onVideoAction?.call('pause', null);
      _showControlsPermanently();
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _showControlsPermanently() {
    _hideControlsTimer?.cancel();
    if (mounted) {
      setState(() {
        _showControls = true;
      });
    }
  }

  void _showControlsTemporarily() {
    _hideControlsTimer?.cancel();
    if (mounted) {
      setState(() {
        _showControls = true;
      });
      if (_controller.value.isPlaying) {
        _startHideControlsTimer();
      }
    }
  }

  void handlePlay() {
    print('[SYNC] Received PLAY from server. Muting outgoing events.');
    _ignoreNextAction = true;
    _controller.play();
    Future.delayed(const Duration(milliseconds: 200), () {
      _ignoreNextAction = false;
    });
  }

  void handlePause() {
    print('[SYNC] Received PAUSE from server. Muting outgoing events.');
    _ignoreNextAction = true;
    _controller.pause();
    Future.delayed(const Duration(milliseconds: 200), () {
      _ignoreNextAction = false;
    });
  }

  void handleSeek(double time) {
    print('[SYNC] Received SEEK from server. Muting outgoing events.');
    _ignoreNextAction = true;
    _controller.seekTo(Duration(milliseconds: (time * 1000).toInt()));
    Future.delayed(const Duration(milliseconds: 200), () {
      _ignoreNextAction = false;
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || !_controller.value.isInitialized) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF6366F1).withOpacity(0.1),
              const Color(0xFFEC4899).withOpacity(0.1),
            ],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Загрузка видео...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyPress,
      child: GestureDetector(
        onTap: () {
          _focusNode.requestFocus();
          setState(() {
            _showControls = !_showControls;
          });
          if (_controller.value.isPlaying) {
            _startHideControlsTimer();
          }
        },
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            SizedBox.expand(
              child: FittedBox(
                fit: widget.isPortrait ? BoxFit.cover : BoxFit.contain,
                alignment: Alignment.center,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            ),
            ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, value, child) {
                return AnimatedOpacity(
                  opacity: _showControls ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Stack(
                    children: [
                      // Center play/pause button
                      if (!value.isPlaying)
                        Center(
                          child: GestureDetector(
                            onTap: () {
                              _controller.play();
                              _showControlsTemporarily();
                            },
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                              ),
                              child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
                            ),
                          ),
                        ),

                      // Bottom controls bar
                      if (!widget.isPortrait)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            ignoring: !_showControls,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    child: Row(
                                      children: [
                                        Text(_formatDuration(value.position), style: const TextStyle(color: Colors.white)),
                                        Expanded(
                                          child: Slider(
                                            value: value.position.inSeconds.toDouble().clamp(0.0, value.duration.inSeconds.toDouble()),
                                            min: 0.0,
                                            max: value.duration.inSeconds.toDouble(),
                                            onChanged: (v) {
                                              // This can be used to show seek time while dragging
                                            },
                                            onChangeEnd: (v) {
                                              _controller.seekTo(Duration(seconds: v.toInt()));
                                            },
                                            activeColor: Colors.white,
                                            inactiveColor: Colors.white.withOpacity(0.3),
                                          ),
                                        ),
                                        Text(_formatDuration(value.duration), style: const TextStyle(color: Colors.white)),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        onPressed: () {
                                          _showControlsTemporarily();
                                          final newPosition = value.position - const Duration(seconds: 10);
                                          _controller.seekTo(newPosition < Duration.zero ? Duration.zero : newPosition);
                                        },
                                        icon: const Icon(Icons.replay_10, color: Colors.white, size: 28),
                                      ),
                                      const SizedBox(width: 20),
                                      IconButton(
                                        onPressed: () {
                                          _showControlsTemporarily();
                                          value.isPlaying ? _controller.pause() : _controller.play();
                                        },
                                        icon: Icon(
                                          value.isPlaying ? Icons.pause : Icons.play_arrow,
                                          color: Colors.white,
                                          size: 36,
                                        ),
                                        iconSize: 36,
                                      ),
                                      const SizedBox(width: 20),
                                      IconButton(
                                        onPressed: () {
                                          _showControlsTemporarily();
                                          final newPosition = value.position + const Duration(seconds: 10);
                                          _controller.seekTo(newPosition > value.duration ? value.duration : newPosition);
                                        },
                                        icon: const Icon(Icons.forward_10, color: Colors.white, size: 28),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

