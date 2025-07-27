import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'beaver_frame_bar_platform_interface.dart';
import 'beaver_frame_bar_cache.dart';

/// An implementation of [BeaverFrameBarPlatform] that uses method channels.
class MethodChannelBeaverFrameBar extends BeaverFrameBarPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel(
    'com.mimao.beaver.frames/frame_extractor',
  );

  /// 获取视频的第一帧
  @override
  Future<Uint8List?> getFirstFrame(String videoPath) async {
    // 先尝试从缓存获取
    final cache = BeaverFrameBarCache();
    final cachedFrame = await cache.getCache(videoPath, suffix: 'first_frame');
    if (cachedFrame != null) {
      return cachedFrame;
    }

    try {
      final List<dynamic> frames = await methodChannel.invokeMethod(
        'getFirstFrame',
        {'path': videoPath},
      );

      final result = frames.isNotEmpty ? frames.first as Uint8List : null;

      // 异步缓存结果（不阻塞返回）
      if (result != null) {
        cache.cacheData(videoPath, result, suffix: 'first_frame');
      }

      return result;
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
    int? frameInterval,
    bool skipFirstFrame = false,
  }) async* {
    // 先尝试从缓存获取
    final cache = BeaverFrameBarCache();
    final cachedFrames = await cache.getCachedKeyFrames(
      videoPath,
      skipFirstFrame: skipFirstFrame,
      frameInterval: frameInterval,
    );

    if (cachedFrames.isNotEmpty) {
      // 从缓存返回
      yield Uint8List(0); // 开始标记
      for (final frame in cachedFrames) {
        yield frame;
        await Future.delayed(Duration(milliseconds: 10));
      }
      return;
    }

    try {
      // 然后流式获取所有关键帧
      final List<dynamic> frames = await methodChannel
          .invokeMethod('getKeyFrames', {
            'path': videoPath,
            'frameCount': frameCount,
            'frameInterval': frameInterval,
            'skipFirstFrame': skipFirstFrame,
          });

      // 收集所有帧用于缓存
      final frameList = <Uint8List>[];

      // 跳过第一帧（如果已经yield过了或者需要跳过）
      int startIndex = skipFirstFrame ? 0 : 1;
      yield Uint8List(0);
      for (int i = startIndex; i < frames.length; i++) {
        final frame = frames[i] as Uint8List;
        frameList.add(frame);
        yield frame;
        // 添加小延迟，让UI有时间更新
        await Future.delayed(Duration(milliseconds: 10));
      }

      // 异步缓存所有帧（不阻塞返回）
      if (frameList.isNotEmpty) {
        cache.cacheFrames(
          videoPath,
          frameList,
          skipFirstFrame: skipFirstFrame,
          frameInterval: frameInterval,
        );
      }
    } on PlatformException catch (e) {
      print("Failed to get key frames stream: '$e'");
    }
  }
}
