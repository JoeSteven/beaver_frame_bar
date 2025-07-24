import 'dart:typed_data';

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'beaver_frame_bar_method_channel.dart';

abstract class BeaverFrameBarPlatform extends PlatformInterface {
  /// Constructs a BeaverFrameBarPlatform.
  BeaverFrameBarPlatform() : super(token: _token);

  static final Object _token = Object();

  static BeaverFrameBarPlatform _instance = MethodChannelBeaverFrameBar();

  /// The default instance of [BeaverFrameBarPlatform] to use.
  ///
  /// Defaults to [MethodChannelBeaverFrameBar].
  static BeaverFrameBarPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [BeaverFrameBarPlatform] when
  /// they register themselves.
  static set instance(BeaverFrameBarPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<List<Uint8List>> getKeyFrames(String videoPath);

  Future<Uint8List?> getFirstFrame(String videoPath);

  Stream<Uint8List> getKeyFramesStream(
    String videoPath, {
    int? frameCount,
    bool skipFirstFrame = false,
  });
}
