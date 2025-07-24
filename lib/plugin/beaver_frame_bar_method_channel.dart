import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'beaver_frame_bar_platform_interface.dart';

/// An implementation of [BeaverFrameBarPlatform] that uses method channels.
class MethodChannelBeaverFrameBar extends BeaverFrameBarPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel(
    'com.mimao.beaver.frames/frame_extractor',
  );

  /// 获取视频的关键帧（批量方式）
  @override
  Future<List<Uint8List>> getKeyFrames(String videoPath) async {
    try {
      final List<dynamic> frames = await methodChannel.invokeMethod(
        'getKeyFrames',
        {'path': videoPath},
      );

      return frames.cast<Uint8List>();
    } on PlatformException catch (e) {
      print("Failed to get key frames: '$e'");
      return [];
    }
  }

  /// 获取视频的第一帧
  @override
  Future<Uint8List?> getFirstFrame(String videoPath) async {
    try {
      final List<dynamic> frames = await methodChannel.invokeMethod(
        'getFirstFrame',
        {'path': videoPath},
      );

      return frames.isNotEmpty ? frames.first as Uint8List : null;
    } on PlatformException catch (e) {
      print("Failed to get first frame: '$e'");
      return null;
    }
  }

  /// 流式获取视频的关键帧（渐进式加载）
  @override
  Stream<Uint8List> getKeyFramesStream(
    String videoPath, {
    int? frameCount,
    bool skipFirstFrame = false,
  }) async* {
    try {
      // 然后流式获取所有关键帧
      final List<dynamic> frames = await methodChannel.invokeMethod(
        'getKeyFrames',
        {
          'path': videoPath,
          'frameCount': frameCount,
          'skipFirstFrame': skipFirstFrame,
        },
      );

      // 跳过第一帧（如果已经yield过了或者需要跳过）
      int startIndex = skipFirstFrame ? 0 : 1;
      yield Uint8List(0);
      for (int i = startIndex; i < frames.length; i++) {
        yield frames[i] as Uint8List;
        // 添加小延迟，让UI有时间更新
        await Future.delayed(Duration(milliseconds: 10));
      }
    } on PlatformException catch (e) {
      print("Failed to get key frames stream: '$e'");
    }
  }
}
