//
//  FaceTracker.swift
//  FaceTracker
//
//  Created by Zh on 2021/11/23.
//

import UIKit
import AVFoundation

public protocol FaceTrackerDelegate: AnyObject {
    func faceIsTracked(faceRect: CGRect, withOffsetWidth offsetWidth: CGFloat, andOffsetHeight offsetHeight: CGFloat, andDistance distance: CGFloat)
    func fluentUpdateDistance(distance: CGFloat)
    func hasNoFace()
}

enum ExifOrientationType: Int {
    case PHOTOS_EXIF_0ROW_TOP_0COL_LEFT = 1 //   1  =  0th row is at the top, and 0th column is on the left (THE DEFAULT).
    case PHOTOS_EXIF_0ROW_TOP_0COL_RIGHT = 2 //   2  =  0th row is at the top, and 0th column is on the right.
    case PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT = 3 //   3  =  0th row is at the bottom, and 0th column is on the right.
    case PHOTOS_EXIF_0ROW_BOTTOM_0COL_LEFT = 4 //   4  =  0th row is at the bottom, and 0th column is on the left.
    case PHOTOS_EXIF_0ROW_LEFT_0COL_TOP = 5 //   5  =  0th row is on the left, and 0th column is the top.
    case PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP = 6 //   6  =  0th row is on the right, and 0th column is the top.
    case PHOTOS_EXIF_0ROW_RIGHT_0COL_BOTTOM = 7 //   7  =  0th row is on the right, and 0th column is the bottom.
    case PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM = 8  //   8  =  0th row is on the left, and 0th column is the bottom.
}

public class FaceTracker: NSObject {
    public weak var delegate: FaceTrackerDelegate?
    public var faceRect: CGRect = .zero
    public var reactionFactor: CGFloat = 0.0
    public var updateInterval: CGFloat = 0.0
    public var previewLayer: AVCaptureVideoPreviewLayer?
    
    private var previousDistance: CGFloat = 0.0
    private var distance: CGFloat = 0.0
    private var photoOutput: AVCapturePhotoOutput?
    private var videoDataOutputQueue: DispatchQueue?
    private var faceDetector: CIDetector?
    
    public init(delegate: FaceTrackerDelegate) {
        super.init()
        if setupAVCapture() {
            self.delegate = delegate
        } else {
            print("AVCapture init failure !!!")
        }
    }
    
    public func fluidUpdateInterval(interval: CGFloat, withReactionFactor factor: CGFloat) {
        if factor <= 0 || factor > 1 {
            fatalError("Error! fluidUpdateInterval factor should be between 0 and 1")
        }
        
        self.reactionFactor = factor
        self.updateInterval = interval
        self.perform(#selector(setDistance), with: nil, afterDelay: TimeInterval(interval))
    }
    
    @objc func setDistance() {
        // The size of the recognized face does not change fluid.
        // In order to still animate it fluient we do some calculations.
        previousDistance = (1.0 - reactionFactor) * previousDistance +  reactionFactor * distance;
        
        delegate?.fluentUpdateDistance(distance: previousDistance)
        
        // Make sure we do a recalculation 10 times every second in order to make sure we animate to the final position.
        self.perform(#selector(setDistance), with: nil, afterDelay: TimeInterval(updateInterval))
    }
    
    private func setupAVCapture() -> Bool {
        let session = AVCaptureSession()
        /*if UIDevice.current.userInterfaceIdiom == .phone {
            session.canSetSessionPreset(.medium)
        } else {
            session.canSetSessionPreset(.photo)
        }*/
        session.canSetSessionPreset(.medium)
        
        guard let device = AVCaptureDevice.default(for: .video) else { return false }
        guard let deviceInput = try? AVCaptureDeviceInput(device: device) else { return false}

        if session.canAddInput(deviceInput) {
            session.addInput(deviceInput)
        }
        
        // Make a still image output
        /*stillImageOutput = [AVCaptureStillImageOutput new];
        [stillImageOutput addObserver:self forKeyPath:@"capturingStillImage" options:NSKeyValueObservingOptionNew context:@"AVCaptureStillImageIsCapturingStillImageContext"];
        if ([session canAddOutput:stillImageOutput]) {
            [session addOutput:stillImageOutput];
        }*/
        /*
        let photoOutput = AVCapturePhotoOutput()
        let photoSettings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: photoSettings, delegate: self)*/
        
        let videoDataOutput = AVCaptureVideoDataOutput()
        let rgbOutputSettings = [String(kCVPixelBufferPixelFormatTypeKey): NSNumber(integerLiteral: Int(kCMPixelFormat_32BGRA))]
        videoDataOutput.videoSettings = rgbOutputSettings
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue")
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        
        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.backgroundColor = UIColor.black.cgColor
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width, height: UIScreen.main.bounds.size.height)
        
        if UIDevice.current.orientation == .landscapeLeft {
            previewLayer.connection?.videoOrientation = .landscapeRight
        } else {
            previewLayer.connection?.videoOrientation = .landscapeLeft
        }
                
        session.startRunning()
        
        // connect the front camara to the preview layer
        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else { return false }
        previewLayer.session?.beginConfiguration()
        if let input = try? AVCaptureDeviceInput(device: frontCamera) {
            if let inputs = previewLayer.session?.inputs {
                for oldInput in inputs {
                    previewLayer.session?.removeInput(oldInput)
                }
            }
            previewLayer.session?.addInput(input)
            previewLayer.session?.commitConfiguration()
        }
        
        videoDataOutput.connection(with: .video)?.isEnabled = true
        
        let detectorOptions = [CIDetectorAccuracy: CIDetectorAccuracyHigh, CIDetectorTracking: true] as [String : Any]
        faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: detectorOptions)
        
        self.previewLayer = previewLayer
        return true
    }
}

extension FaceTracker: AVCaptureVideoDataOutputSampleBufferDelegate {
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // got an image
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let attachments = CMCopyDictionaryOfAttachments(allocator: kCFAllocatorDefault, target: sampleBuffer, attachmentMode: kCMAttachmentMode_ShouldPropagate)
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer, options: attachments as? [CIImageOption : Any])
        let curDeviceOrientation = UIDevice.current.orientation
        var exifOrientation: ExifOrientationType = .PHOTOS_EXIF_0ROW_TOP_0COL_LEFT
        switch curDeviceOrientation {
        // Device oriented vertically, home button on the top
        case .portraitUpsideDown:
            exifOrientation = .PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM
        // Device oriented horizontally, home button on the right
        case .landscapeLeft:
            exifOrientation = .PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT
        // Device oriented horizontally, home button on the left
        case .landscapeRight:
            exifOrientation = .PHOTOS_EXIF_0ROW_TOP_0COL_LEFT
        // Device oriented vertically, home button on the bottom
        case .portrait:
            exifOrientation = .PHOTOS_EXIF_0ROW_RIGHT_0COL_BOTTOM
        default:
            exifOrientation = .PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP
        }
        
        let imageOptions = [CIDetectorImageOrientation: NSNumber(integerLiteral: exifOrientation.rawValue)]
        let features = faceDetector?.features(in: ciImage, options: imageOptions) as? [CIFaceFeature]
        
        // get the clean aperture
        // the clean aperture is a rectangle that defines the portion of the encoded pixel dimensions
        // that represents image data valid for display.
        guard let fdesc = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
        let clap = CMVideoFormatDescriptionGetCleanAperture(fdesc, originIsAtTopLeft: false /*originIsTopLeft == false*/)
        
        calculateFaceBoxesForFeatures(features: features, forVideoBox: clap, deviceOrientation: curDeviceOrientation)
    }
    
    // called asynchronously as the capture output is capturing sample buffers, this method asks the face detector (if on)
    // to detect features and for each draw the red square in a layer and set appropriate orientation
    private func calculateFaceBoxesForFeatures(features: [CIFaceFeature]?, forVideoBox clap: CGRect, deviceOrientation orientation: UIDeviceOrientation) {
        guard let faces = features else {
            delegate?.hasNoFace()
            return }
        guard let preview = previewLayer else { return }
        let parentFrameSize = preview.frame.size
        let gravity = preview.videoGravity
        let isMirrored = preview.connection?.isVideoMirrored
        
        let previewBox = FaceTracker.videoPreviewBoxForGravity(gravity: gravity, frameSize: parentFrameSize, apertureSize: clap.size)
        
        for ff in faces {
            // find the correct position for the square layer within the previewLayer
            // the feature box originates in the bottom left of the video frame.
            // (Bottom right if mirroring is turned on)
            faceRect = ff.bounds
            
            // flip preview width and height
            var temp = faceRect.size.width
            faceRect.size.width = faceRect.size.height
            faceRect.size.height = temp
            temp = faceRect.origin.x
            faceRect.origin.x = faceRect.origin.y
            faceRect.origin.y = temp
            
            // scale coordinates so they fit in the preview box, which may be scaled
            let widthScaleBy = previewBox.size.width / clap.size.height
            let heightScaleBy = previewBox.size.height / clap.size.width
            faceRect.size.width *= widthScaleBy
            faceRect.size.height *= heightScaleBy
            faceRect.origin.x *= widthScaleBy
            faceRect.origin.y *= heightScaleBy
            
            if isMirrored ?? false {
                faceRect = faceRect.offsetBy(dx: previewBox.origin.x + previewBox.size.width - faceRect.size.width - (faceRect.origin.x * 2), dy: previewBox.origin.y)
            } else {
                faceRect = faceRect.offsetBy(dx: previewBox.origin.x, dy: previewBox.origin.y)
            }
            
            DispatchQueue.main.async {
                let offsetWidth = (self.faceRect.origin.x - (160 - (self.faceRect.size.width / 2)))
                let offsetHeight = (self.faceRect.origin.y  - ( 240 - (self.faceRect.origin.y / 2 )))
                
                if UIDevice.current.userInterfaceIdiom == .phone {
                    // This is the current recongized distance. See the setDistance method for usages
                    self.distance = (800.0 - (self.faceRect.size.width + self.faceRect.size.height)) / 10.0
                } else {
                    let minM = min(UIScreen.main.bounds.size.height, UIScreen.main.bounds.size.width)
                    if self.faceRect.height > minM ||
                        (!ff.hasLeftEyePosition && ff.hasRightEyePosition) ||
                        (ff.hasLeftEyePosition && !ff.hasRightEyePosition) {
                        self.distance = 15.0
                    } else {
                        // Pref 与 Dref为参考值在手机成像的距离与离屏幕的距离，Psf为双眼的间距
                        // dsf = (pref / psf) * dref
                        // 1pt ≈ 0.016cm
                        let pref = 3.5 * (UIScreen.main.bounds.size.width / 1024.0)
                        self.distance = (pref / (abs(ff.rightEyePosition.x - ff.leftEyePosition.x) * 0.016)) * 25.0
                    }
                }
                
                self.delegate?.faceIsTracked(faceRect: self.faceRect, withOffsetWidth: offsetWidth, andOffsetHeight: offsetHeight, andDistance: self.distance)
            }
        }
        
        CATransaction.commit()
    }
    
    // find where the video box is positioned within the preview layer based on the video size and gravity
    private static func videoPreviewBoxForGravity(gravity: AVLayerVideoGravity, frameSize: CGSize, apertureSize: CGSize) -> CGRect {
        let apertureRatio: CGFloat = apertureSize.height / apertureSize.width
        let viewRatio: CGFloat = frameSize.width / frameSize.height
        
        var size: CGSize = .zero
        if gravity == .resizeAspectFill {
            if (viewRatio > apertureRatio) {
                size.width = frameSize.width
                size.height = apertureSize.width * (frameSize.width / apertureSize.height)
            } else {
                size.width = apertureSize.height * (frameSize.height / apertureSize.width)
                size.height = frameSize.height
            }
        } else if gravity == .resizeAspect {
            if (viewRatio > apertureRatio) {
                size.width = apertureSize.height * (frameSize.height / apertureSize.width)
                size.height = frameSize.height
            } else {
                size.width = frameSize.width
                size.height = apertureSize.width * (frameSize.width / apertureSize.height)
            }
        } else if gravity == .resize {
            size.width = frameSize.width
            size.height = frameSize.height
        }
        
        var videoBox: CGRect = .zero
        videoBox.size = size
        if size.width < frameSize.width {
            videoBox.origin.x = (frameSize.width - size.width) / 2
        } else {
            videoBox.origin.x = (size.width - frameSize.width) / 2
        }
        
        if size.height < frameSize.height {
            videoBox.origin.y = (frameSize.height - size.height) / 2
        } else {
            videoBox.origin.y = (size.height - frameSize.height) / 2
        }
        
        return videoBox
    }
}
