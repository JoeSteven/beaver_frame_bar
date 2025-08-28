import Flutter
import UIKit
import AVFoundation

public class BeaverFrameBarPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.mimao.beaver.frames/frame_extractor", binaryMessenger: registrar.messenger())
    let instance = BeaverFrameBarPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "getKeyFrames" {
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid argument", details: nil))
        return
      }
      let frameCount = args["frameCount"] as? Int
      let frameInterval = args["frameInterval"] as? Int
      let skipFirstFrame = args["skipFirstFrame"] as? Bool ?? false
      VideoFrameExtractor.extractKeyFrames(from: path, frameCount: frameCount, frameInterval: frameInterval, skipFirstFrame: skipFirstFrame) { images in
        result(images)
      }
    } else if call.method == "getFirstFrame" {
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid argument", details: nil))
        return
      }
      VideoFrameExtractor.extractFirstFrame(from: path) { images in
        result(images)
      }
    } else {
      result(FlutterMethodNotImplemented)
    }
  }
}

class VideoFrameExtractor: NSObject {
    static func extractKeyFrames(from videoPath: String, frameCount: Int?, frameInterval: Int?, skipFirstFrame: Bool, completion: @escaping ([FlutterStandardTypedData]?) -> Void) {
        let startTime = Date()
        let asset = AVAsset(url: URL(fileURLWithPath: videoPath))
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        generator.maximumSize = CGSize(width: 640, height: 360) // 限制图像最大尺寸

        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            completion(nil)
            return
        }

        let reader = try! AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: nil)
        reader.add(output)
        reader.startReading()

        var keyFrameTimes = [NSValue]()
        while let sampleBuffer = output.copyNextSampleBuffer() {
            if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[String: Any]],
               let dependsOnOthers = attachments.first?[kCMSampleAttachmentKey_DependsOnOthers as String] as? Bool {
                let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                if !dependsOnOthers {
                        keyFrameTimes.append(NSValue(time: time))
                }
            }
        }

        // 计算目标帧数
        var targetFrameCount = keyFrameTimes.count
        
        // 如果指定了frameInterval，根据视频时长计算帧数
        if let frameInterval = frameInterval, frameInterval > 0 {
            let duration = asset.duration
            let durationInSeconds = CMTimeGetSeconds(duration)
            let durationInMilliseconds = durationInSeconds * 1000
            let calculatedFrameCount = Int(durationInMilliseconds / Double(frameInterval))
            targetFrameCount = calculatedFrameCount
        }
        
        // 如果指定了frameCount，则使用较小的值作为限制
        if let frameCount = frameCount, frameCount > 0 {
            targetFrameCount = min(targetFrameCount, frameCount)
        }
        
        // 如果目标帧数小于等于0，则使用所有关键帧
        if targetFrameCount <= 0 {
            targetFrameCount = keyFrameTimes.count
        }
        
        // 平均选择帧
        var selectedFrameTimes = keyFrameTimes
        if targetFrameCount < keyFrameTimes.count {
            selectedFrameTimes = []
            let step = Double(keyFrameTimes.count - 1) / Double(targetFrameCount - 1)
            
            for i in 0..<targetFrameCount {
                let index = Int(Double(i) * step)
                if index < keyFrameTimes.count {
                    selectedFrameTimes.append(keyFrameTimes[index])
                }
            }
        }

        // 如果需要跳过第一帧，则移除第一个时间点
        if skipFirstFrame && !selectedFrameTimes.isEmpty {
            selectedFrameTimes.removeFirst()
        }

        var images = [FlutterStandardTypedData]()
        var imageDict = [CMTime: FlutterStandardTypedData]()
        let queue = DispatchQueue(label: "imageConversionQueue", attributes: .concurrent)
        let group = DispatchGroup()

        for time in selectedFrameTimes {
            group.enter()
            queue.async {
                generator.generateCGImagesAsynchronously(forTimes: [time]) { _, image, _, result, error in
                    if let image = image, result == .succeeded {
                        let uiImage = UIImage(cgImage: image)
                        if let imageData = uiImage.jpegData(compressionQuality: 0.05) { // 调整图像质量
                            imageDict[time.timeValue] = FlutterStandardTypedData(bytes: imageData)
                        }
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) {
            // 按时间顺序排序关键帧
            let sortedTimes = selectedFrameTimes.map { $0.timeValue }.sorted { CMTimeCompare($0, $1) < 0 }
            for time in sortedTimes {
                if let imageData = imageDict[time] {
                    images.append(imageData)
                }
            }
            completion(images)
        }
    }
    
    static func extractFirstFrame(from videoPath: String, completion: @escaping ([FlutterStandardTypedData]?) -> Void) {
        let asset = AVAsset(url: URL(fileURLWithPath: videoPath))
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        generator.maximumSize = CGSize(width: 640, height: 360) // 限制图像最大尺寸

        // 获取视频的第一帧（时间戳为0）
        let firstFrameTime = CMTime.zero
        generator.generateCGImagesAsynchronously(forTimes: [NSValue(time: firstFrameTime)]) { _, image, _, result, error in
            if let image = image, result == .succeeded {
                let uiImage = UIImage(cgImage: image)
                if let imageData = uiImage.jpegData(compressionQuality: 0.05) {
                    completion([FlutterStandardTypedData(bytes: imageData)])
                } else {
                    completion(nil)
                }
            } else {
                print("Failed to extract first frame: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
            }
        }
    }
}