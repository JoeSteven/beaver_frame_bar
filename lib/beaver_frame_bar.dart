import 'dart:async';
import 'dart:typed_data';
import 'package:beaver_frame_bar/plugin/beaver_frame_bar_platform_interface.dart';
import 'package:beaver_frame_bar/plugin/pair.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class BeaverFrameBar extends StatelessWidget {
  final BeaverFrameBarController controller;
  final double height;
  final Color progressBarColor;
  final double progressBarWidth;
  // color before frame isloaded
  final Color backgroundColor;

  final Widget Function(BuildContext context)? customProgressBar;

  const BeaverFrameBar({
    super.key,
    required this.controller,
    this.height = 40.0,
    this.progressBarColor = Colors.white70,
    this.progressBarWidth = 2.0,
    this.backgroundColor = Colors.black87,
    this.customProgressBar,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final actualWidth = constraints.maxWidth;
        return Stack(
          children: [
            Listener(
              onPointerDown: (event) {
                controller._userScrollStart();
              },
              onPointerUp: (event) {
                controller._userScrollEnd();
              },
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: ClampingScrollPhysics(),
                controller: controller._scrollController,
                child: SizedBox(
                  height: height,
                  child: ValueListenableBuilder(
                    valueListenable: controller.firstFrame,
                    builder: (context, firstFrame, child) {
                      return ValueListenableBuilder(
                        valueListenable: controller.frames,
                        builder: (context, frames, child) {
                          return Row(
                            children: [
                              SizedBox(width: actualWidth / 2),
                              Stack(
                                children: [
                                  if (firstFrame.first == null &&
                                      frames.isEmpty)
                                    SizedBox.shrink(),
                                  Stack(
                                    children: [
                                      SizedBox(
                                        width: actualWidth / 2,
                                        child: _buildBackgroundWidget(),
                                      ),
                                      if (firstFrame.first != null)
                                        _buildFramesWidget(
                                          List.filled(
                                            firstFrame.second,
                                            firstFrame.first!,
                                          ),
                                        ),
                                      if (frames.isNotEmpty)
                                        _buildFramesWidget(frames),
                                    ],
                                  ),
                                ],
                              ),
                              if (firstFrame.first != null || frames.isNotEmpty)
                                SizedBox(width: actualWidth / 2),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
            SizedBox(
              height: height,
              child: Center(
                child: customProgressBar?.call(context) ?? _buildProgressBar(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBackgroundWidget() {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildFramesWidget(List<Uint8List> frames) {
    return Row(
      children: List.generate(frames.length, (index) {
        final frame = frames[index];
        return SizedBox(
          height: height,
          child: Image.memory(frame, fit: BoxFit.fitHeight),
        );
      }),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      width: progressBarWidth,
      decoration: BoxDecoration(
        color: progressBarColor,
        borderRadius: BorderRadius.circular(progressBarWidth / 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
    );
  }
}

class BeaverFrameBarController {
  final String videoPath;
  // max frame count to load
  final int maxFrameCount;
  // frame interval in milliseconds
  final int? frameInterval;
  // inorder to display first frame, we need to wait for the first frame to be loaded
  final int delayAfterFirstFrame;
  final Function(double)? onProgressChanged;

  final _firstFrame = ValueNotifier<Pair<Uint8List?, int>>(Pair(null, 0));
  final _frames = ValueNotifier<List<Uint8List>>([]);

  ValueNotifier<Pair<Uint8List?, int>> get firstFrame => _firstFrame;
  ValueNotifier<List<Uint8List>> get frames => _frames;
  final _subscriptions = <StreamSubscription<Uint8List>>[];
  late final ScrollController _scrollController;
  late final Function() _scrollListener;

  BeaverFrameBarController({
    required this.videoPath,
    this.maxFrameCount = 30,
    this.frameInterval = 500,
    this.delayAfterFirstFrame = 16,
    required this.onProgressChanged,
  }) {
    _scrollListener = _onScrollUpdate;
    _scrollController = ScrollController(
      onAttach: (position) {
        if (_pendingProgress != null) {
          Future.delayed(Duration(milliseconds: 30), () {
            seekTo(_pendingProgress!);
            _pendingProgress = null;
          });
        }
      },
    );
    _scrollController.addListener(_scrollListener);
    _loadFrame();
  }

  void _onScrollUpdate() {
    if (_scrollController.position.userScrollDirection !=
        ScrollDirection.idle) {
      _dispatchProgress();
    }
  }

  bool _isFrameCountUpdated = false;
  bool _isInFrameUpdate = false;

  void _loadFrame() async {
    if (_isFrameCountUpdated || _isInFrameUpdate) {
      return;
    }
    _isInFrameUpdate = true;
    final firstFrame = await BeaverFrameBarPlatform.instance.getFirstFrame(
      videoPath,
    );
    if (firstFrame == null) {
      return;
    }
    _isFrameCountUpdated = true;
    _firstFrame.value = Pair(firstFrame, (maxFrameCount / 2).toInt());
    await Future.delayed(Duration(milliseconds: delayAfterFirstFrame));
    // 获取所有关键帧
    final frames = BeaverFrameBarPlatform.instance.getKeyFramesStream(
      videoPath,
      frameCount: maxFrameCount,
      frameInterval: frameInterval,
    );

    _subscriptions.add(
      frames.listen((frame) {
        if (frame.isEmpty) {
          _frames.value = [];
          return;
        }
        _frames.value = [..._frames.value, frame];
      }),
    );
    _isInFrameUpdate = false;
  }

  /// 释放资源
  void dispose() {
    _firstFrame.dispose();
    _frames.dispose();
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
  }

  bool _isUserTakeOver = false;
  double? _pendingProgress;
  void seekTo(double progress) {
    if (_isUserTakeOver) {
      return;
    }
    final realProgress = progress.clamp(0.0, 1.0);
    try {
      _scrollController.animateTo(
        realProgress * _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 100),
        curve: Curves.linear,
      );
    } catch (e) {
      _pendingProgress = realProgress;
    }
  }

  _dispatchProgress() {
    final progress =
        _scrollController.position.pixels /
        _scrollController.position.maxScrollExtent;
    onProgressChanged?.call(progress.clamp(0.0, 1.0));
  }

  void _userScrollStart() {
    _isUserTakeOver = true;
    _dispatchProgress();
  }

  void _userScrollEnd() {
    _isUserTakeOver = false;
  }
}
