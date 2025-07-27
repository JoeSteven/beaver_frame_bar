# Beaver Frame Bar

A Flutter plugin for extracting video frames and displaying them in a progress bar.

## Features

- Extract first frame from video
- Extract key frames from video with customizable interval
- Cache frames for better performance
- Display frames in a progress bar widget
- Support for frame interval and frame count limits

## Usage

### Basic Usage

```dart
import 'package:beaver_frame_bar/beaver_frame_bar.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = BeaverFrameBarController(
      videoPath: '/path/to/your/video.mp4',
      maxFrameCount: 20,
    );

    return BeaverFrameBar(
      controller: controller,
      progress: 0.5,
      onProgressChanged: (progress) {
        print('Progress: $progress');
      },
    );
  }
}
```

### Using Frame Interval

You can specify a frame interval in milliseconds to control how frequently frames are extracted:

```dart
final controller = BeaverFrameBarController(
  videoPath: '/path/to/your/video.mp4',
  maxFrameCount: 50,        // Maximum number of frames
  frameInterval: 500,       // Extract a frame every 500ms
);
```

The `frameInterval` parameter works as follows:
- If `frameInterval` is 500ms and video duration is 10 seconds, it will try to extract 20 frames (10000ms / 500ms)
- If the calculated frame count exceeds `maxFrameCount`, it will use `maxFrameCount` as the limit
- If `frameInterval` is not specified, it will extract all available key frames up to `maxFrameCount`

### Direct API Usage

You can also use the platform interface directly:

```dart
import 'package:beaver_frame_bar/plugin/beaver_frame_bar_platform_interface.dart';

// Get first frame
final firstFrame = await BeaverFrameBarPlatform.instance.getFirstFrame('/path/to/video.mp4');

// Get key frames with interval
final framesStream = BeaverFrameBarPlatform.instance.getKeyFramesStream(
  '/path/to/video.mp4',
  frameCount: 30,        // Maximum frames
  frameInterval: 1000,   // 1 second interval
  skipFirstFrame: false, // Include first frame
);

framesStream.listen((frame) {
  // Handle each frame
  print('Received frame: ${frame.length} bytes');
});
```

### Cache Management

The plugin includes built-in caching for better performance:

```dart
import 'package:beaver_frame_bar/plugin/beaver_frame_bar_cache.dart';

final cache = BeaverFrameBarCache();

// Enable/disable cache
cache.setCacheEnabled(true);

// Check if cache is enabled
print('Cache enabled: ${cache.isCacheEnabled}');

// Get cache size
final size = await cache.getCacheSize();
print('Cache size: $size bytes');

// Get cache file count
final count = await cache.getCacheFileCount();
print('Cache files: $count');

// Clear specific video cache
await cache.clearCache('/path/to/video.mp4');

// Clear all cache
await cache.clearAllCache();
```

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  beaver_frame_bar: ^0.0.1
```

## Platform Support

- iOS
- Android
- macOS

## License

This project is licensed under the MIT License.

