//
//  FMCustomCameraViewController.swift
//  TestCode
//
//  Created by Zhouheng on 2020/6/28.
//  Copyright © 2020 tataUFO. All rights reserved.
//

import UIKit
import AVFoundation
import Photos
import AssetsLibrary
import CoreMedia

class FMCustomCameraViewController: UIViewController {

    let motionManager: FMMotionManager = WBMotionManager()
    let movieManager: FMMovieManager = WBMovieManager()
    let cameraManager: FMCameraManager = WBCameraManager()
    // 录制
    var recording: Bool = false
    
    // 会话
    var session: AVCaptureSession?
    
    // 输入
    var deviceInput: AVCaptureDeviceInput?
        
    // 输出
    var videoConnection: AVCaptureConnection?
    var audioConnection: AVCaptureConnection?
    var videoOutput: AVCaptureVideoDataOutput?
    var imageOutput: AVCaptureStillImageOutput?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .gray
        
        // 使用
        self.cameraPermissions(authorizedBlock: { [weak self] in
            guard let self = self else { return }
            print("打开相机")
            DispatchQueue.main.async {
                self.setupUI()
            }
            
        }, deniedBlock: {
            print("没有权限使用相机")
        })
        
    }

    // 相机权限
    func cameraPermissions(authorizedBlock: @escaping () -> Void, deniedBlock: @escaping () -> Void) {
        let authStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        
        // .notDetermined  .authorized  .restricted  .denied
        if authStatus == .notDetermined {
            // 第一次触发授权 alert
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) in
                self.cameraPermissions(authorizedBlock: authorizedBlock, deniedBlock: deniedBlock)
            })
        } else if authStatus == .authorized {
            authorizedBlock()
        } else {
            deniedBlock()
        }
    }
    
    private func setupUI() {
        view.addSubview(self.cameraView)
        
        setupSession()
        cameraView.previewView.captureSessionsion = self.session
        startCaptureSession()
        view.addSubview(previewImageView)
    }
    
    /// MARK: --- 输入设备
    func cameraWithPosition(position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let devices = AVCaptureDevice.devices(for: .video)
        for device in devices {
            if device.position == position {
                return device
            }
        }
        return nil
    }
    
    func activeCamera() -> AVCaptureDevice? {
        deviceInput?.device
    }
    
    func inactiveCamera() -> AVCaptureDevice? {
        var device: AVCaptureDevice?
        if AVCaptureDevice.devices(for: .video).count > 1 {
            if activeCamera()?.position == .back {
                device = cameraWithPosition(position: .front)
            } else {
                device = cameraWithPosition(position: .back)
            }
        }
        return device
    }
    
    /// MARK: --- 会话配置相关
    /// 配置会话
    func setupSession() {
        session = AVCaptureSession()
        session?.sessionPreset = .high
        setupSessionInputs()
        setupSessionOutputs()
    }
    
    /// 输入
    func setupSessionInputs() {
        // 视频
        if let videoDevice = AVCaptureDevice.default(for: .video) {
            do {
                let videoInput = try AVCaptureDeviceInput.init(device: videoDevice)
                if let s = session, s.canAddInput(videoInput) {
                    s.addInput(videoInput)
                }
                self.deviceInput = videoInput
            } catch (let error) {
                print(" --- 设置视频输入错误 --- \(error)")
            }
        }
        // 音频
//        if let audioDevice = AVCaptureDevice.default(for: .audio) {
//            do {
//                let audioInput = try AVCaptureDeviceInput.init(device: audioDevice)
//                if let s = session, s.canAddInput(audioInput) {
//                    s.addInput(audioInput)
//                }
//            } catch (let error) {
//                print(" --- 设置音频输入错误 --- \(error)")
//            }
//        }
        
    }
    
    /// 输出
    func setupSessionOutputs() {
        let captureQueue = DispatchQueue(label: "com.wb.captureQueue")
        // 视频
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [String(kCVPixelBufferPixelFormatTypeKey): NSNumber(integerLiteral: Int(kCVPixelFormatType_32BGRA))]
        videoOutput.setSampleBufferDelegate(self, queue: captureQueue)
        if let s = session, s.canAddOutput(videoOutput) {
            s.addOutput(videoOutput)
        }
        self.videoOutput = videoOutput
        self.videoConnection = videoOutput.connection(with: .video)
        
        // 音频
//        let audioOutput = AVCaptureAudioDataOutput()
//        audioOutput.setSampleBufferDelegate(self, queue: captureQueue)
//        if let s = session, s.canAddOutput(audioOutput) {
//            s.addOutput(audioOutput)
//        }
//        self.audioConnection = audioOutput.connection(with: .audio)
        
        // 静态图片输出
        let imageOutput = AVCaptureStillImageOutput()
        imageOutput.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
        if let s = session, s.canAddOutput(imageOutput) {
            s.addOutput(imageOutput)
        }
        self.imageOutput = imageOutput
    }
    
    /// MARK: --- 会话控制相关
    // 开启捕捉
    func startCaptureSession() {
        if let s = session, !s.isRunning {
            s.startRunning()
        }
    }

    // 停止捕捉
    func stopCaptureSession() {
        if let s = session, s.isRunning {
            s.stopRunning()
        }
    }
    
    /// MARK: --- lazy loading
    lazy var cameraView: WBCameraView = {
        let view = WBCameraView(frame: CGRect(x: 0, y: 88, width: screenWidth, height: screenHeight - 88 - 31))
        view.delegate = self
        return view
    }()
    
    lazy var previewImageView: UIImageView = {
        let iv = UIImageView(frame: CGRect(x: (screenWidth - 200) / 2.0, y: 200, width: 200, height: 200))
        return iv
    }()
    
    // 当前设备取向
    func currentVideoOrientation() -> AVCaptureVideoOrientation {
        var orientation: AVCaptureVideoOrientation = .portrait
        switch motionManager.deviceOrientation {
        case .portrait:
            orientation = .portrait
        case .portraitUpsideDown:
            orientation = .portraitUpsideDown
        case .landscapeLeft:
            orientation = .landscapeLeft
        case .landscapeRight:
            orientation = .landscapeRight
        default:
            orientation = .portrait
        }
        return orientation
    }
    
    deinit {
        print(" --- 相机界面销毁了 --- ")
    }
    
}

extension FMCustomCameraViewController: WBCameraViewDelegate {
    // 闪光灯
    func flashLightAction(_ cameraView: WBCameraView, handler: ((Error?) -> ())) {
        guard let device = activeCamera() else { return }
        let on = cameraManager.flashMode(device: device) == .on
        let mode: AVCaptureDevice.FlashMode = on ? .off : .on
        let error = cameraManager.changeFlash(device: device, mode: mode)
        handler(error)
    }
    // 手电筒
    func torchLightAction(_ cameraView: WBCameraView, handler: ((Error?) -> ())) {
        guard let device = activeCamera() else { return }
        let on = cameraManager.torchMode(device: device) == .on
        let mode: AVCaptureDevice.TorchMode = on ? .off : .on
        let error = cameraManager.changeTorch(device: device, mode: mode)
        handler(error)
    }
    // 转换摄像头
    func swicthCameraAction(_ cameraView: WBCameraView, handler: ((Error?) -> ())) {
        guard let videoDevice = inactiveCamera(), let device = activeCamera(), let s = self.session, let deviceInput = self.deviceInput else { return }
        do {
            let videoInput = try AVCaptureDeviceInput.init(device: videoDevice)
            // 动画效果
            let animation = CATransition()
            animation.type = CATransitionType(rawValue: "oglFlip")
            animation.subtype = .fromLeft
            animation.duration = 0.5
            cameraView.previewView.layer.add(animation, forKey: "flip")
            // 当前闪光灯状态
            let mode = cameraManager.flashMode(device: device)
            // 转换摄像头
            self.deviceInput = cameraManager.switchCamera(session: s, oldinput: deviceInput, newinput: videoInput)
            // 重新设置视频输出链接
            self.videoConnection = self.videoOutput?.connection(with:.video)
            // 如果后置转前置，系统会自动关闭手电筒(如果之前打开的，需要更新UI)
            if videoDevice.position == .front {
                cameraView.changeTorch(false)
            }
            // 前后摄像头的闪光灯不是同步的，所以在转换摄像头后需要重新设置闪光灯
            let _ = cameraManager.changeFlash(device: videoDevice, mode: mode)
        } catch (let error) {
            handler(error)
        }
    }
    // 自动聚焦、曝光
    func autoFocusAndExposureAction(_ cameraView: WBCameraView, handler: ((Error?) -> ())) {
        guard let device = activeCamera() else { return }
        let error = cameraManager.resetFocusAndExposure(device: device)
        handler(error)
    }
    
    // 聚焦
    func focusAction(_ cameraView: WBCameraView, point: CGPoint, handler: ((Error?) -> ())) {
        guard let device = activeCamera() else { return }
        
        if let error = cameraManager.focus(device: device, point: point) {
            print(" --- 聚焦出现错误 --- \(String(describing: error))")
        }
        
    }
    // 曝光
    func exposAction(_ cameraView: WBCameraView, point: CGPoint, handler: ((Error?) -> ())) {
        guard let device = activeCamera() else { return }
        let error = cameraManager.expose(device: device, point: point)
        handler(error)
    }
    // 缩放
    func zoomAction(_ cameraView: WBCameraView, factor: CGFloat) {
        guard let device = activeCamera() else { return }
        
        if let error = cameraManager.zoom(device: device, factor: factor) {
            print(" --- 缩放出现错误 --- \(String(describing: error))")
        }
        
    }
    
    /// MARK: --- 拍摄照片
    func takePhotoAction(_ cameraView: WBCameraView) {
        if let connection = self.imageOutput?.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = self.currentVideoOrientation()
            }
            self.imageOutput?.captureStillImageAsynchronously(from: connection, completionHandler: { (buffer, error) in
                if let _ = error {
                    print(" --- 拍摄照片时发生错误 --- \(String(describing: error))")
                    return
                }
                if let b = buffer {
                    
                    if let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(b) {
                        
                        if let image = UIImage(data: imageData) {
                            self.previewImageView.image = self.captureFinishWithImage(image)
                        }
                        
                    }
                    
                }
                
            })
        }
        
    }
    
    func captureFinishWithImage(_ image: UIImage) -> UIImage? {
        let size0 = image.size
        var size1 = CGSize(width: screenWidth, height: screenWidth * 4.0 / 3.0)
        let height = (size1.height + size0.width) / size1.width
        size1.height = height
        size1.width = size0.width
        let rect = CGRect(x: (size0.height - size1.height) / 2.0, y: 0, width: size1.height, height: size1.width)
        if let cgRef0 = image.cgImage {
            
            if let cgRef1 = cgRef0.cropping(to: rect) {
                let scaleImage = UIImage(cgImage: cgRef1, scale: UIScreen.main.scale, orientation: image.imageOrientation)
                return scaleImage
            }
            
        }
        return nil
    }
    
    /// MARK: --- 录制视频
    // 开始录像
    func startRecordVideoAction(_ cameraView: WBCameraView) {
        recording = true
        movieManager.currentDevice = activeCamera()
        movieManager.currentOrientation = currentVideoOrientation()
        movieManager.start { (error) in
            if let err = error {
                print(" --- 录制视频开始失败 --- \(err)")
            }
        }
    }
    
    // 停止录像
    func stopRecordVideoAction(_ cameraView: WBCameraView) {
        recording = false
        movieManager.stop {[weak self] (error, url) in
            if let err = error {
                print(" --- 录制视频结束失败 --- \(err)")
            } else {
                self?.saveMovieToCameraRoll(url: url)
            }
        }
    }
    
    func saveMovieToCameraRoll(url: URL?) {
        guard let u = url else { return }
        PHPhotoLibrary.requestAuthorization { (status) in
            if status != .authorized { return }
            PHPhotoLibrary.shared().performChanges({
                let videoRequest = PHAssetCreationRequest.forAsset()
                videoRequest.addResource(with: .video, fileURL: u, options: nil)
            }) { (success, error) in
                DispatchQueue.main.sync {
                    
                }
                if !success {
                    print(" --- 保存失败 ---")
                } else {
                    print(" --- 保存成功 ---")
                }
            }
        }
    }
    // 改变拍照模式
    func didChangeTypeAction(_ cameraView: WBCameraView, type: WBCameraType) {
    }
    // 取消
    func cancelAction(_ cameraView: WBCameraView) {
        self.navigationController?.popViewController(animated: true)
    }
}

extension FMCustomCameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if recording, let video = videoConnection, let audio = audioConnection {
            movieManager.writeData(connection: connection, video: video, audio: audio, buffer: sampleBuffer)
        }
    }
}
