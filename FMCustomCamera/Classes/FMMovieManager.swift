//
//  FMMovieManager.swift
//  FMCustomCamera
//
//  Created by Zhouheng on 2020/7/28.
//  Copyright © 2020 tataUFO. All rights reserved.
//

import UIKit
import AVFoundation

class FMMovieManager: NSObject {
    var referenceOrientation: AVCaptureVideoOrientation = .portrait
    var currentOrientation: AVCaptureVideoOrientation = .portrait
    var currentDevice: AVCaptureDevice?
    
    var readyToRecordVideo: Bool = false
    var readyToRecordAudio: Bool = false
    var movieWritingQueue: DispatchQueue = DispatchQueue(label: "Movie.Writing.Queue")
    var movieURL: URL = URL(fileURLWithPath: String(format: "%@%@", NSTemporaryDirectory(), "movie.mov"))
    var movieWriter: AVAssetWriter?
    var movieAudioInput: AVAssetWriterInput?
    var movieVideoInput: AVAssetWriterInput?
    
    /// MARK: --- open interface
    func start(_ hander: @escaping ((Error?) -> ())) {
        removeFile(fileURL: movieURL)
        movieWritingQueue.async {
            if let _ = self.movieWriter {
            } else {
                do {
                    self.movieWriter = try AVAssetWriter(url: self.movieURL, fileType: AVFileType.mov)
                } catch(let error) {
                    hander(error)
                }
            }
        }
    }
    
    func stop(_ hander: @escaping ((Error?, URL?) -> ())) {
        readyToRecordAudio = false
        readyToRecordVideo = false
        movieWritingQueue.async {
            self.movieWriter?.finishWriting(completionHandler: {
                if self.movieWriter?.status == .completed {
                    DispatchQueue.main.sync {
                        hander(nil, self.movieURL)
                    }
                } else {
                    hander(self.movieWriter?.error, nil)
                }
                self.movieWriter = nil
            })
        }
    }
    
    func writeData(connection: AVCaptureConnection, video: AVCaptureConnection, audio: AVCaptureConnection, buffer: CMSampleBuffer) {
        movieWritingQueue.async {
            if connection == video {
                if !self.readyToRecordVideo {
                    
                    if let sample = CMSampleBufferGetFormatDescription(buffer) {
                        self.readyToRecordVideo = (self.setupAssetWriterVideoInput(sample)) == nil
                    }
                    
                }
                if self.inputsReadyToRecord() {
                    self.writeSampleBuffer(sampleBuffer: buffer, mediaType: .video)
                }
            } else if connection == audio {
                if !self.readyToRecordAudio {
                    
                    if let sample = CMSampleBufferGetFormatDescription(buffer) {
                        self.readyToRecordAudio = (self.setupAssetWriterAudioInput(sample)) == nil
                    }
                    
                }
                if self.inputsReadyToRecord() {
                    self.writeSampleBuffer(sampleBuffer: buffer, mediaType: .audio)
                }
            }
        }
    }
    
    func writeSampleBuffer(sampleBuffer: CMSampleBuffer, mediaType: AVMediaType) {
        if movieWriter?.status == .unknown {
            if let mw = movieWriter, mw.startWriting() {
                mw.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            } else {
                FMLog(" --- \(String(describing: movieWriter?.error)) --- ")
            }
        }
        
        if movieWriter?.status == .writing {
            if mediaType == .video {
                guard let mvi = movieVideoInput else { return }
                if !mvi.isReadyForMoreMediaData {
                    return
                }
                if !mvi.append(sampleBuffer) {
                    FMLog(" --- \(String(describing: movieWriter?.error)) --- ")
                }
            } else if mediaType == .audio {
                guard let mai = movieAudioInput else { return }
                if !mai.isReadyForMoreMediaData {
                    return
                }
                if !mai.append(sampleBuffer) {
                    FMLog(" --- \(String(describing: movieWriter?.error)) --- ")
                }
            }
        }
    }
    
    func inputsReadyToRecord() -> Bool {
        return readyToRecordVideo && readyToRecordAudio
    }
    
    /// 音频源数据写入配置
    func setupAssetWriterAudioInput(_ currentFormatDescription: CMFormatDescription) -> Error? {
        let aclSize = UnsafeMutablePointer<Int>.allocate(capacity: 0)
        guard let currentASBD = CMAudioFormatDescriptionGetStreamBasicDescription(currentFormatDescription) else {
            return nil
        }
        let channelLayout = CMAudioFormatDescriptionGetChannelLayout(currentFormatDescription, sizeOut: aclSize)
        let dataLayout = aclSize.pointee > 0 ? NSData(bytes: channelLayout, length: aclSize.pointee) : NSData()
        let settings = [AVFormatIDKey: NSNumber(integerLiteral: Int(kAudioFormatMPEG4AAC)), AVSampleRateKey: NSNumber(floatLiteral: currentASBD.pointee.mSampleRate), AVChannelLayoutKey: dataLayout, AVNumberOfChannelsKey: NSNumber(integerLiteral: Int(currentASBD.pointee.mChannelsPerFrame)), AVEncoderBitRatePerChannelKey: NSNumber(integerLiteral: 64000)]
        if let mw = movieWriter, mw.canApply(outputSettings: settings, forMediaType: .audio) {
            movieAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: settings)
            movieAudioInput?.expectsMediaDataInRealTime = true
            if let mai = movieAudioInput, mw.canAdd(mai) {
                mw.add(mai)
            } else {
                return mw.error
            }
        } else {
            return movieWriter?.error
        }
        return nil
    }
    
    /// 视频源数据写入配置
    func setupAssetWriterVideoInput(_ currentFormatDescription: CMFormatDescription) -> Error? {
        let dimensions = CMVideoFormatDescriptionGetDimensions(currentFormatDescription)
        let numPixels = dimensions.width * dimensions.height
        let bitsPerPixels = numPixels < (640 * 480) ? 4.05 : 11.0
        let compression = [AVVideoAverageBitRateKey: NSNumber(integerLiteral: Int(numPixels) * Int(bitsPerPixels)), AVVideoMaxKeyFrameIntervalKey: NSNumber(integerLiteral: 30)]
        let setttings = [AVVideoCodecKey: AVVideoCodecH264, AVVideoWidthKey: NSNumber(integerLiteral: Int(dimensions.width)), AVVideoHeightKey: NSNumber(integerLiteral: Int(dimensions.height)), AVVideoCompressionPropertiesKey: compression] as [String : Any]
        if let mw = movieWriter, mw.canApply(outputSettings: setttings, forMediaType: .video) {
            movieVideoInput = AVAssetWriterInput(mediaType: .video, outputSettings: setttings)
            movieVideoInput?.expectsMediaDataInRealTime = true
            movieVideoInput?.transform = transformFromCurrentVideoOrientationToOrientation(orientation: referenceOrientation)
            if let mvi = movieVideoInput, mw.canAdd(mvi) {
                mw.add(mvi)
            } else {
               return mw.error
            }
        } else {
            return movieWriter?.error
        }
        
        return nil
    }
    
    // 获取视频旋转矩阵
    func transformFromCurrentVideoOrientationToOrientation(orientation: AVCaptureVideoOrientation) -> CGAffineTransform{
        let orientationAngleOffset = angleOffsetFromPortraitOrientationToOrientation(orientation)
        let videoOrientationAngleOffset = angleOffsetFromPortraitOrientationToOrientation(currentOrientation)
        var angleOffset: CGFloat = 0.0
        if currentDevice?.position == .back {
            angleOffset = videoOrientationAngleOffset - orientationAngleOffset + CGFloat.pi / 2.0
        } else {
            angleOffset = orientationAngleOffset - videoOrientationAngleOffset + CGFloat.pi / 2.0
        }
        return CGAffineTransform(rotationAngle: angleOffset)
    }
    
    // 获取视频旋转角度
    func angleOffsetFromPortraitOrientationToOrientation(_ orientation: AVCaptureVideoOrientation) -> CGFloat {
        var angle: CGFloat = 0.0
        switch orientation {
        case .portrait:
            angle = 0.0
        case .portraitUpsideDown:
            angle = CGFloat.pi
        case .landscapeRight:
            angle = -CGFloat.pi / 2.0
        case .landscapeLeft:
            angle = CGFloat.pi / 2.0
        default:
            break
        }
        return angle
    }
    
    // 移除文件
    func removeFile(fileURL: URL) {
        let fileManager = FileManager.default
        let filePath = fileURL.path
        if fileManager.fileExists(atPath: filePath) {
            do {
                try fileManager.removeItem(atPath: filePath)
                FMLog(" --- 删除视频文件成功 --- ")
            } catch(let error) {
                FMLog(" --- 删除视频文件失败 --- \(error)")
            }
        }
    }
}
