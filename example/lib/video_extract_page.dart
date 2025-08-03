import 'dart:io';
import 'dart:typed_data';
import 'package:beaver_frame_bar/frame.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

class VideoExtractPage extends StatefulWidget {
  const VideoExtractPage({super.key});

  @override
  State<VideoExtractPage> createState() => _VideoExtractPageState();
}

class _VideoExtractPageState extends State<VideoExtractPage> {
  final ImagePicker _picker = ImagePicker();
  List<Uint8List> _frames = [];
  String? _selectedVideoPath;
  bool _showTimeline = false;
  BeaverFrameBarController? _progressController;
  VideoPlayerController? _videoController;
  double _currentProgress = 0.0;
  bool showControls = true;

  @override
  void dispose() {
    _progressController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo({String? path}) async {
    // 获取应用目录
    String? video;
    if (path == null) {
      final XFile? videofile = await _picker.pickVideo(
        source: ImageSource.gallery,
      );
      video = videofile?.path;
      if (video == null) {
        return;
      }
    } else {
      final documentDir = await getApplicationDocumentsDirectory();
      video = '${documentDir.path}/$path';
    }

    setState(() {
      _selectedVideoPath = video;
      _showTimeline = true;
      _frames = []; // 清空之前的帧
      _currentProgress = 0.0;

      // 创建新的进度控制器
      _progressController?.dispose();
      _progressController = BeaverFrameBarController(
        videoPath: video!,
        onProgressChanged: (progress) {
          setState(() {
            _currentProgress = progress;
            if (_videoController?.value.isPlaying == true) {
              _videoController?.pause();
            }
            final newPosition =
                _videoController!.value.duration.inMilliseconds * progress;
            _videoController?.seekTo(
              Duration(milliseconds: newPosition.toInt()),
            );
          });
        },
      );
      _videoController?.dispose();
      _videoController = VideoPlayerController.file(File(video));
      _videoController?.initialize().then((_) {
        setState(() {});
      });
      _videoController?.play();
      _videoController?.addListener(() {
        if (_videoController?.value.isPlaying == true) {
          setState(() {
            final duration = _videoController!.value.duration;
            final position = _videoController!.value.position;
            if (duration.inMilliseconds > 0) {
              _currentProgress =
                  position.inMilliseconds / duration.inMilliseconds;
              _progressController?.seekTo(_currentProgress);
            }
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Video Frame Extractor')),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    showControls = !showControls;
                  });
                },
                child: Text('controller'),
              ),
              ElevatedButton(
                onPressed: () => _pickVideo(path: null),
                child: Text('选择'),
              ),
              ElevatedButton(
                onPressed: () => _pickVideo(path: "1.MOV"),
                child: Text('视频1'),
              ),
              // ElevatedButton(
              //   onPressed: () => _pickVideo(path: "5.MOV"),
              //   child: Text('视频2'),
              // ),
              // ElevatedButton(
              //   onPressed: () => _pickVideo(path: "6.mov"),
              //   child: Text('视频3'),
              // ),
              ElevatedButton(
                onPressed: () => _videoController?.value.isPlaying == true
                    ? _videoController?.pause()
                    : _videoController?.play(),
                child: Text(
                  _videoController?.value.isPlaying == true ? '暂停' : '播放',
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // 视频播放器
          if (_videoController != null)
            Flexible(
              flex: 1,
              fit: FlexFit.loose,
              child: _videoController!.value.isInitialized
                  ? Container(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      ),
                    )
                  : Container(),
            ),

          SizedBox(height: 8),

          // 当前进度显示
          if (_progressController != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '当前进度: ${(_currentProgress * 100).toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

          SizedBox(height: 16),

          // 视频预览进度条
          if (_progressController != null)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 8),
                  Visibility(
                    visible: showControls,
                    maintainState: true,
                    child: BeaverFrameBar(
                      controller: _progressController!,
                      height: 50,
                      progressBarColor: Colors.white,
                      backgroundColor: Colors.black,
                      progressBarWidth: 3.0,
                    ),
                  ),
                ],
              ),
            ),

          SizedBox(height: 16),

          // 传统方式显示所有帧
          if (_frames.isNotEmpty)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '所有提取的帧 (${_frames.length} 张)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _frames.length,
                        itemBuilder: (context, index) {
                          return Container(
                            margin: EdgeInsets.only(right: 4),
                            child: Image.memory(_frames[index]),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (_selectedVideoPath == null)
            Expanded(child: Center(child: Text('请先选择视频文件'))),
        ],
      ),
    );
  }
}
