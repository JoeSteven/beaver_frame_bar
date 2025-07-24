# beaver_frame_bar

A video progress bar with video frame preview

usage:

```dart
                _progressController = BeaverFrameBarController(videoPath: video!);

                BeaverFrameBar(
                    controller: _progressController,
                    height: 50, 
                    width: MediaQuery.of(context).size.width - 32,
                    progressBarColor: Colors.white,
                    backgroundColor: Colors.black,
                    progressBarWidth: 3.0,
                    progress: _currentProgress,// progress should be come from video player (0 - 1)
                    onProgressChanged: (progress) {
                      // turn progress into video time position and call video player seekTo
                    },
                  ),
```

