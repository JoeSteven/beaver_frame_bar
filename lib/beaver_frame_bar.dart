import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:beaver_frame_bar/plugin/beaver_frame_bar_platform_interface.dart';
import 'package:beaver_frame_bar/plugin/pair.dart';
import 'package:flutter/material.dart';

class BeaverFrameBar extends StatelessWidget {
  final BeaverFrameBarController controller;
  final double height;
  final double? width;
  final Color progressBarColor;
  final double progressBarWidth;
  // color before frame isloaded
  final Color backgroundColor;
  // 0.0 - 1.0
  final double progress;
  final Function(double)? onProgressChanged;

  const BeaverFrameBar({
    super.key,
    required this.controller,
    required this.progress,
    required this.onProgressChanged,
    this.height = 40.0,
    this.width,
    this.progressBarColor = Colors.white70,
    this.progressBarWidth = 2.0,
    this.backgroundColor = Colors.black87,
  });

  void dragging(double dx, double width) {
    // 计算点击位置对应的进度
    final localPosition = dx;
    final progress = localPosition / width;
    onProgressChanged?.call(progress.clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final actualWidth = width ?? MediaQuery.of(context).size.width;
    final maxWidth = MediaQuery.of(context).size.width;
    final finalWidth = actualWidth > maxWidth ? maxWidth : actualWidth;
    controller._updateFrameWidth(finalWidth, height);

    return Listener(
      onPointerDown: (details) {
        dragging(details.localPosition.dx, finalWidth);
      },
      onPointerMove: (details) {
        dragging(details.localPosition.dx, finalWidth);
      },
      child: SizedBox(
        width: finalWidth,
        height: height,
        child: Stack(
          children: [
            _buildBackgroundWidget(),
            ValueListenableBuilder(
              valueListenable: controller.firstFrame,
              builder: (context, firstFrame, child) {
                return ValueListenableBuilder<List<Uint8List>>(
                  valueListenable: controller.frames,
                  builder: (context, frames, child) {
                    if (firstFrame.first == null && frames.isEmpty) {
                      return SizedBox.shrink();
                    }
                    return Stack(
                      children: [
                        if (firstFrame.first != null)
                          _buildFramesWidget(
                            finalWidth,
                            List.filled(firstFrame.second, firstFrame.first!),
                          ),
                        if (frames.isNotEmpty)
                          _buildFramesWidget(
                            finalWidth,
                            frames,
                            frameCount: firstFrame.second,
                          ),
                      ],
                    );
                  },
                );
              },
            ),
            _buildProgressBar(finalWidth),
          ],
        ),
      ),
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

  Widget _buildFramesWidget(
    double width,
    List<Uint8List> frames, {
    int? frameCount,
  }) {
    final frameWidth = width / (frameCount ?? frames.length);
    return Row(
      children: List.generate(frames.length, (index) {
        final frame = frames[index];
        return SizedBox(
          height: height,
          width: frameWidth,
          child: Image.memory(frame, fit: BoxFit.fill),
        );
      }),
    );
  }

  Widget _buildProgressBar(double width) {
    final progressPosition = progress * width;
    return Positioned(
      left: progressPosition - progressBarWidth / 2,
      top: 0,
      bottom: 0,
      child: Container(
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
      ),
    );
  }
}

class BeaverFrameBarController {
  final String videoPath;
  // max frame count to load
  final int maxFrameCount;
  // inorder to display first frame, we need to wait for the first frame to be loaded
  final int delayAfterFirstFrame;

  final _firstFrame = ValueNotifier<Pair<Uint8List?, int>>(Pair(null, 0));
  final _frames = ValueNotifier<List<Uint8List>>([]);

  ValueNotifier<Pair<Uint8List?, int>> get firstFrame => _firstFrame;
  ValueNotifier<List<Uint8List>> get frames => _frames;
  final _subscriptions = <StreamSubscription<Uint8List>>[];

  BeaverFrameBarController({
    required this.videoPath,
    this.maxFrameCount = 20,
    this.delayAfterFirstFrame = 16,
  });

  bool _isFrameCountUpdated = false;
  bool _isInFrameUpdate = false;

  void _updateFrameWidth(double width, double height) async {
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
    final imageSize = await _getImageSize(firstFrame);
    int frameCount = maxFrameCount;
    if (imageSize != null) {
      final realWidth = imageSize.width * height / imageSize.height;
      frameCount = (width / realWidth).ceil();
    }
    _firstFrame.value = Pair(firstFrame, frameCount);
    await Future.delayed(Duration(milliseconds: delayAfterFirstFrame));
    // 获取所有关键帧
    final frames = BeaverFrameBarPlatform.instance.getKeyFramesStream(
      videoPath,
      frameCount: frameCount,
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
  }

  Future<ui.Size?> _getImageSize(Uint8List imageData) async {
    try {
      final codec = await ui.instantiateImageCodec(imageData);
      final frame = await codec.getNextFrame();
      return frame.image.width > 0 && frame.image.height > 0
          ? ui.Size(frame.image.width.toDouble(), frame.image.height.toDouble())
          : null;
    } catch (e) {
      print('Failed to get image size: $e');
      return null;
    }
  }
}
