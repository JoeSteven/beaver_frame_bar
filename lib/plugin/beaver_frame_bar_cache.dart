import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

/// 视频帧缓存管理类
/// 使用单例模式，支持异步缓存操作，不会阻塞主线程
class BeaverFrameBarCache {
  static final BeaverFrameBarCache _instance = BeaverFrameBarCache._internal();
  factory BeaverFrameBarCache() => _instance;
  BeaverFrameBarCache._internal();

  /// 缓存开关
  bool _isEnabled = false;

  /// 缓存目录
  Directory? _cacheDir;

  /// 获取缓存目录
  Future<Directory> get _getCacheDir async {
    if (_cacheDir != null) return _cacheDir!;

    final appDir = await _getApplicationDocumentsDirectory();
    _cacheDir = Directory(path.join(appDir.path, 'beaver_frame_bar_cache'));
    print('cacheDir: ${_cacheDir!.path}');

    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }

    return _cacheDir!;
  }

  /// 获取应用文档目录
  Future<Directory> _getApplicationDocumentsDirectory() async {
    if (Platform.isIOS || Platform.isAndroid) {
      return Directory(
        path.join(Directory.systemTemp.path, 'beaver_frame_bar_cache'),
      );
    } else if (Platform.isMacOS) {
      return Directory(
        path.join(Directory.systemTemp.path, 'beaver_frame_bar_cache'),
      );
    } else {
      return Directory.systemTemp;
    }
  }

  /// 生成缓存键
  String _generateCacheKey(String videoPath, {String? suffix}) {
    final key = suffix != null ? '$videoPath:$suffix' : videoPath;
    final bytes = utf8.encode(key);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// 获取缓存文件路径
  Future<String> _getCacheFilePath(String videoPath, {String? suffix}) async {
    final cacheDir = await _getCacheDir;
    final cacheKey = _generateCacheKey(videoPath, suffix: suffix);
    return path.join(cacheDir.path, '$cacheKey.bin');
  }

  /// 检查是否有缓存
  Future<bool> hasCache(String videoPath, {String? suffix}) async {
    if (!_isEnabled) return false;

    try {
      final cachePath = await _getCacheFilePath(videoPath, suffix: suffix);
      return await File(cachePath).exists();
    } catch (e) {
      print('Error checking cache: $e');
      return false;
    }
  }

  /// 获取缓存数据
  Future<Uint8List?> getCache(String videoPath, {String? suffix}) async {
    if (!_isEnabled) return null;

    try {
      final cachePath = await _getCacheFilePath(videoPath, suffix: suffix);
      final file = File(cachePath);

      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      print('Error reading cache: $e');
    }

    return null;
  }

  /// 异步缓存数据（不阻塞主线程）
  void cacheData(String videoPath, Uint8List data, {String? suffix}) {
    if (!_isEnabled) return;

    // 使用 isolate 进行异步缓存，不阻塞主线程
    _cacheDataInIsolate(videoPath, data, suffix: suffix);
  }

  /// 在 isolate 中缓存数据
  void _cacheDataInIsolate(String videoPath, Uint8List data, {String? suffix}) {
    Isolate.spawn(_cacheWorker, {
      'videoPath': videoPath,
      'data': data,
      'suffix': suffix,
    });
  }

  /// 缓存工作函数（在 isolate 中运行）
  static void _cacheWorker(Map<String, dynamic> params) async {
    try {
      final videoPath = params['videoPath'] as String;
      final data = params['data'] as Uint8List;
      final suffix = params['suffix'] as String?;

      final cache = BeaverFrameBarCache();
      final cachePath = await cache._getCacheFilePath(
        videoPath,
        suffix: suffix,
      );
      final file = File(cachePath);

      await file.writeAsBytes(data);
      print('Cache saved: $cachePath');
    } catch (e) {
      print('Error caching data in isolate: $e');
    }
  }

  /// 缓存多个帧数据
  void cacheFrames(
    String videoPath,
    List<Uint8List> frames, {
    bool skipFirstFrame = false,
  }) {
    if (!_isEnabled) return;

    // 缓存第一帧
    if (!skipFirstFrame && frames.isNotEmpty) {
      cacheData(videoPath, frames.first, suffix: 'first_frame');
    }

    // 缓存所有关键帧
    if (frames.length > 1) {
      final keyFrames = skipFirstFrame ? frames : frames.skip(1).toList();
      if (keyFrames.isNotEmpty) {
        cacheData(videoPath, _combineFrames(keyFrames), suffix: 'key_frames');
      }
    }
  }

  /// 合并多个帧数据
  Uint8List _combineFrames(List<Uint8List> frames) {
    // 简单的合并方式：将每个帧的长度和内容连接
    final buffer = <int>[];

    for (final frame in frames) {
      // 写入帧长度（4字节）
      final length = frame.length;
      buffer.addAll([
        (length >> 24) & 0xFF,
        (length >> 16) & 0xFF,
        (length >> 8) & 0xFF,
        length & 0xFF,
      ]);
      // 写入帧数据
      buffer.addAll(frame);
    }

    return Uint8List.fromList(buffer);
  }

  /// 解析合并的帧数据
  List<Uint8List> _parseCombinedFrames(Uint8List combinedData) {
    final frames = <Uint8List>[];
    int offset = 0;

    while (offset < combinedData.length) {
      if (offset + 4 > combinedData.length) break;

      // 读取帧长度
      final length =
          (combinedData[offset] << 24) |
          (combinedData[offset + 1] << 16) |
          (combinedData[offset + 2] << 8) |
          combinedData[offset + 3];

      offset += 4;

      if (offset + length > combinedData.length) break;

      // 读取帧数据
      final frame = combinedData.sublist(offset, offset + length);
      frames.add(frame);
      offset += length;
    }

    return frames;
  }

  /// 获取缓存的关键帧列表
  Future<List<Uint8List>> getCachedKeyFrames(
    String videoPath, {
    bool skipFirstFrame = false,
  }) async {
    if (!_isEnabled) return [];

    try {
      final combinedData = await getCache(videoPath, suffix: 'key_frames');
      if (combinedData != null) {
        return _parseCombinedFrames(combinedData);
      }
    } catch (e) {
      print('Error reading cached key frames: $e');
    }

    return [];
  }

  /// 设置缓存开关
  void setCacheEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  /// 获取缓存开关状态
  bool get isCacheEnabled => _isEnabled;

  /// 清除指定视频的缓存
  Future<void> clearCache(String videoPath) async {
    if (!_isEnabled) return;

    try {
      final cacheDir = await _getCacheDir;
      final cacheKey = _generateCacheKey(videoPath);
      final pattern = RegExp('^$cacheKey.*\.bin\$');

      await for (final file in cacheDir.list()) {
        if (file is File && pattern.hasMatch(path.basename(file.path))) {
          await file.delete();
        }
      }
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  /// 清除所有缓存
  Future<void> clearAllCache() async {
    if (!_isEnabled) return;

    try {
      final cacheDir = await _getCacheDir;
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create();
      }
    } catch (e) {
      print('Error clearing all cache: $e');
    }
  }

  /// 获取缓存大小（字节）
  Future<int> getCacheSize() async {
    if (!_isEnabled) return 0;

    try {
      final cacheDir = await _getCacheDir;
      int totalSize = 0;

      await for (final file in cacheDir.list(recursive: true)) {
        if (file is File) {
          totalSize += await file.length();
        }
      }

      return totalSize;
    } catch (e) {
      print('Error getting cache size: $e');
      return 0;
    }
  }

  /// 获取缓存文件数量
  Future<int> getCacheFileCount() async {
    if (!_isEnabled) return 0;

    try {
      final cacheDir = await _getCacheDir;
      int count = 0;

      await for (final file in cacheDir.list()) {
        if (file is File) {
          count++;
        }
      }

      return count;
    } catch (e) {
      print('Error getting cache file count: $e');
      return 0;
    }
  }
}
