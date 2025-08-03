import 'package:beaver_frame_bar/plugin/beaver_frame_bar_cache.dart';

export 'beaver_frame_bar.dart';

class BeaverFrameBarCacheControl {
  /// 设置缓存开关
  static void setCacheEnabled(bool enabled) {
    BeaverFrameBarCache().setCacheEnabled(enabled);
  }

  /// 清除指定视频的缓存
  static Future<void> clearCache(String videoPath) async {
    BeaverFrameBarCache().clearCache(videoPath);
  }

  /// 清除所有缓存
  static Future<void> clearAllCache() async {
    BeaverFrameBarCache().clearAllCache();
  }

  /// 获取缓存大小（字节）
  static Future<int> getCacheSize() async {
    return BeaverFrameBarCache().getCacheSize();
  }

  /// 获取缓存文件数量
  static Future<int> getCacheFileCount() async {
    return BeaverFrameBarCache().getCacheFileCount();
  }
}
