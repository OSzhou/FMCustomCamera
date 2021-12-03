//
//  FaceTracker.swift
//  FaceTracker
//
//  Created by Zh on 2021/11/23.
//

import UIKit
import AVFoundation
import Vision
// 参考: https://medium.com/onfido-tech/live-face-tracking-on-ios-using-vision-framework-adf8a1799233
public protocol FaceTrackerDelegate: AnyObject {
    func faceIsTracked(faceRect: CGRect, withOffsetWidth offsetWidth: CGFloat, andOffsetHeight offsetHeight: CGFloat, andDistance distance: CGFloat, isCIDetector: Bool)
    func fluentUpdateDistance(distance: CGFloat, isCIDetector: Bool)
    func hasNoFace(isCIDetector: Bool)
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
    private var isCIDetector: Bool = false
    
    public init(delegate: FaceTrackerDelegate) {
        super.init()
        if setupAVCapture() {
            self.delegate = delegate
        } else {
            print("AVCapture init failure !!!")
        }
    }
    
    public func startRunning() {
        previewLayer?.session?.startRunning()
    }
    
    public func stopRunning() {
        previewLayer?.session?.stopRunning()
    }
    
    public func fluidUpdateInterval(interval: CGFloat, withReactionFactor factor: CGFloat) {
        if factor <= 0 || factor > 1 {
            fatalError("Error! fluidUpdateInterval factor should be between 0 and 1")
        }
        
        self.reactionFactor = factor
        self.updateInterval = interval
        self.perform(#selector(setDistance), with: nil, afterDelay: TimeInterval(interval), inModes: [.common])
    }
    
    @objc func setDistance() {
        // The size of the recognized face does not change fluid.
        // In order to still animate it fluient we do some calculations.
        previousDistance = (1.0 - reactionFactor) * previousDistance +  reactionFactor * distance;
        
        delegate?.fluentUpdateDistance(distance: previousDistance, isCIDetector: isCIDetector)
        
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
        
        let connection = previewLayer.connection
        if UIDevice.current.orientation == .landscapeLeft {
            connection?.videoOrientation = .landscapeRight
        } else {
            connection?.videoOrientation = .landscapeLeft
        }
        
        connection?.videoScaleAndCropFactor = 1.0
        
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
        if #available(iOS 11.0, *) {
            isCIDetector = false
            VisionDetectFace(in: pixelBuffer)
        } else {
            isCIDetector = true
            CIDetectorDetectFace(sampleBuffer: sampleBuffer, pixelBuffer: pixelBuffer)
        }
    }
    /*
     编码的图像数据与图像的预期显示方向相匹配。
     case up = 1 // 0th row at top,    0th column on left   - default orientation
     
     编码的图像数据从图像的预期显示方向水平翻转。
     case upMirrored = 2 // 0th row at top,    0th column on right  - horizontal flip
     
     编码的图像数据从图像的预期显示方向旋转 180°。
     case down = 3 // 0th row at bottom, 0th column on right  - 180 deg rotation
     
     编码的图像数据从图像的预期显示方向垂直翻转
     case downMirrored = 4 // 0th row at bottom, 0th column on left   - vertical flip
     
     编码的图像数据从图像的预期显示方向水平翻转并逆时针旋转 90°。
     case leftMirrored = 5 // 0th row on left,   0th column at top
     
     编码的图像数据从图像的预期显示方向顺时针旋转 90°。
     case right = 6 // 0th row on right,  0th column at top    - 90 deg CW
     
     编码的图像数据从图像的预期显示方向水平翻转并顺时针旋转 90°。
     case rightMirrored = 7 // 0th row on right,  0th column on bottom
     
     编码的图像数据从图像的预期显示方向顺时针旋转 90°。
     case left = 8 // 0th row on left,   0th column at bottom - 90 deg CCW
     */
    private func CIDetectorDetectFace(sampleBuffer: CMSampleBuffer, pixelBuffer: CVPixelBuffer) {
        let attachments = CMCopyDictionaryOfAttachments(allocator: kCFAllocatorDefault, target: sampleBuffer, attachmentMode: kCMAttachmentMode_ShouldPropagate)
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer, options: attachments as? [CIImageOption : Any])
        
        let curDeviceOrientation = UIDevice.current.orientation
        var exifOrientation: CGImagePropertyOrientation = .up // 1
        switch curDeviceOrientation {
        // Device oriented vertically, home button on the top
        case .portraitUpsideDown:
            exifOrientation = .left // 8
        // Device oriented horizontally, home button on the right
        case .landscapeLeft:
            exifOrientation = .down // 3
        // Device oriented horizontally, home button on the left
        case .landscapeRight:
            exifOrientation = .up // 1
        // Device oriented vertically, home button on the bottom
        case .portrait:
            exifOrientation = .rightMirrored // 7
        case .faceUp:
            exifOrientation = .up
        default:
            exifOrientation = .right // 6
        }
        
        let imageOptions = [CIDetectorImageOrientation: NSNumber(integerLiteral: Int(exifOrientation.rawValue))]
        let features = faceDetector?.features(in: ciImage, options: imageOptions) as? [CIFaceFeature]
        
        // get the clean aperture
        // the clean aperture is a rectangle that defines the portion of the encoded pixel dimensions
        // that represents image data valid for display.
        guard let fdesc = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
        let clap = CMVideoFormatDescriptionGetCleanAperture(fdesc, originIsAtTopLeft: false /*originIsTopLeft == false*/)
        
        calculateFaceBoxesForFeatures(features: features, forVideoBox: clap, deviceOrientation: curDeviceOrientation)
    }
    
    @available(iOS 11.0, *)
    private func VisionDetectFace(in image: CVPixelBuffer) {
        let faceDetectionRequest = VNDetectFaceLandmarksRequest(completionHandler: { (request: VNRequest, error: Error?) in
            DispatchQueue.main.async {
                if let results = request.results as? [VNFaceObservation], results.count > 0 {
                    #if DEBUG
                    print("did detect \(results.count) face(s)")
                    #endif
                    self.handleFaceDetectionResults(results)
                } else {
                    #if DEBUG
                    print("did not detect any face")
                    #endif
                    self.delegate?.hasNoFace(isCIDetector: self.isCIDetector)
                }
            }
        })
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: image, orientation: .up, options: [:])
        try? imageRequestHandler.perform([faceDetectionRequest])
    }
    
    @available(iOS 11.0, *)
    private func handleFaceDetectionResults(_ observedFaces: [VNFaceObservation]) {
        guard let observedFace = observedFaces.first else { return }
        
        let originBounds = observedFace.boundingBox
        
        let screenW = UIScreen.main.bounds.size.width
        let screenH = UIScreen.main.bounds.size.height
        
        let rectWidth = screenW * originBounds.size.width
        let rectHeight = screenH * originBounds.size.height
                                    
        let boundingBoxY = screenH * (1 - originBounds.origin.y - originBounds.size.height)
        
        // 前置摄像头坐标转换
        let boundingX = screenW - originBounds.origin.x * screenW - rectWidth
        
        let leftEye = observedFace.landmarks?.leftEye
        let hasLeftEye = (leftEye != nil)

        var lefEyePosition = leftEye?.normalizedPoints.first ?? .zero
        lefEyePosition = CGPoint(x: lefEyePosition.x * rectWidth + boundingX, y: boundingBoxY + (1 - lefEyePosition.y) * rectHeight)
        
        let rightEye = observedFace.landmarks?.rightEye
        let hasRightEye = (rightEye != nil)
        var rightEyePosition = rightEye?.normalizedPoints.first ?? .zero
        rightEyePosition = CGPoint(x: rightEyePosition.x * rectWidth + boundingX, y: boundingBoxY + (1 - rightEyePosition.y) * rectHeight)
        
        /*
        let w = originBounds.size.width * screenW
        let h = originBounds.size.height * screenH
        let x = originBounds.origin.x * screenW
        let y = screenH - (originBounds.origin.y * screenH) - h*/
        
        var facePointRect = convertRect(boundingBox: originBounds, imageSize: UIScreen.main.bounds.size)
        
        //前置摄像头的时候 记得转换
        facePointRect.origin.x = screenW - facePointRect.origin.x - facePointRect.size.width
        
//        print("face rect --- \(facePointRect)")
//        print("left eye position --- \(lefEyePosition)")
//        print("right eye position --- \(rightEyePosition)")
        calculateDistanceWith(
            originBounds: facePointRect,
            faceRect: facePointRect,
            hasLeftEye: hasLeftEye,
            leftEyePosition: lefEyePosition,
            hasRightEye: hasRightEye,
            hasRightEyePosition: rightEyePosition)
    }
    
    private func convertRect(boundingBox: CGRect, imageSize: CGSize) -> CGRect {
        let w = boundingBox.size.width * imageSize.width
        let h = boundingBox.size.height * imageSize.height
        let x = boundingBox.origin.x * imageSize.width
        let y = imageSize.height * (1 - boundingBox.origin.y - boundingBox.size.height) //- (boundingBox.origin.y * imageSize.height) - h
        return CGRect(x: x, y: y, width: w, height: h)
    }
    
    // called asynchronously as the capture output is capturing sample buffers, this method asks the face detector (if on)
    // to detect features and for each draw the red square in a layer and set appropriate orientation
    private func calculateFaceBoxesForFeatures(features: [CIFaceFeature]?, forVideoBox clap: CGRect, deviceOrientation orientation: UIDeviceOrientation) {
        guard let faces = features, !faces.isEmpty else {
            delegate?.hasNoFace(isCIDetector: isCIDetector)
            return }
        guard let preview = previewLayer else { return }
        let parentFrameSize = preview.frame.size
        let gravity = preview.videoGravity
        let isMirrored = preview.connection?.isVideoMirrored
        
        let previewBox = FaceTracker.videoPreviewBoxForGravity(gravity: gravity, frameSize: parentFrameSize, apertureSize: clap.size)
        var originBounds: CGRect = .zero
        for ff in faces {
            // find the correct position for the square layer within the previewLayer
            // the feature box originates in the bottom left of the video frame.
            // (Bottom right if mirroring is turned on)
            faceRect = ff.bounds
//            print("face bounds --- \(faceRect)")
            originBounds = ff.bounds
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
            
            calculateDistanceWith(
                originBounds: originBounds,
                faceRect: faceRect,
                hasLeftEye: ff.hasLeftEyePosition,
                leftEyePosition: ff.leftEyePosition,
                hasRightEye: ff.hasRightEyePosition,
                hasRightEyePosition: ff.rightEyePosition)
        }
        
        CATransaction.commit()
    }
    
    private func calculateDistanceWith(originBounds: CGRect, faceRect: CGRect, hasLeftEye: Bool, leftEyePosition: CGPoint, hasRightEye: Bool, hasRightEyePosition: CGPoint) {
        DispatchQueue.main.async {
            let offsetWidth = (self.faceRect.origin.x - (160 - (self.faceRect.size.width / 2)))
            let offsetHeight = (self.faceRect.origin.y  - ( 240 - (self.faceRect.origin.y / 2 )))
            
            if UIDevice.current.userInterfaceIdiom == .phone {
                // This is the current recongized distance. See the setDistance method for usages
                self.distance = (800.0 - (self.faceRect.size.width + self.faceRect.size.height)) / 10.0
            } else {

                let minM = min(UIScreen.main.bounds.size.height, UIScreen.main.bounds.size.width) * 3.0 / 4.0
//                    print("face height --- \(originBounds.height)")
//                    print("face width --- \(originBounds.width)")
//                    print("minM --- \(minM)")
                let faceH = CGFloat(Int(originBounds.height / 10)) * 10
                let faceW = CGFloat(Int(originBounds.width / 10)) * 10
//                print("face height --- \(faceH)")
//                print("face width --- \(faceW)")
                if faceH > minM || faceW > minM ||
                    (!hasLeftEye && hasRightEye) ||
                    (hasRightEye && !hasLeftEye) {
                    self.distance = 17.0
                } else {
                    // Pref 与 Dref为参考值在手机成像的距离与离屏幕的距离，Psf为双眼的间距
                    // dsf = (pref / psf) * dref
                    // 1pt ≈ 0.016cm
                    let pref = 3.7 * (UIScreen.main.bounds.size.width / 1024.0)
                    self.distance = (pref / (abs(hasRightEyePosition.x - leftEyePosition.x) * 0.016)) * 25.0
                }
            }
            var originD = floor(self.distance)
            if originD == 24 || originD == 25 {
                originD = 23
            }
            if originD == 26 || originD == 27 {
                originD = 28
            }
            #if DEBUG
            print("distance --- \(originD)")
            #endif
            self.delegate?.faceIsTracked(faceRect: self.faceRect, withOffsetWidth: offsetWidth, andOffsetHeight: offsetHeight, andDistance: originD, isCIDetector: self.isCIDetector)
        }
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
