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
    
    var confirmUserPhoto: ((UIImage) -> ())?
    
    var isPresent: Bool = false
    
    let motionManager: FMMotionManager = FMMotionManager()
    let movieManager: FMMovieManager = FMMovieManager()
    let cameraManager: FMCameraManager = FMCameraManager()
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
    
    var cameraAuthorized: Bool = false
    
    /// 默认摄像头选择: 1-前置摄像头, 2-后置摄像头
    var cameraChoice: Int32 = 2
    /// 蒙层的url
    var maskURL: String?
    /// 相机取景宽
    var cameraFramingWidth: Int32 = 3
    /// 相机取景高
    var cameraFramingHeight: Int32 = 4
    /// 相机取景框的高宽比
    private var cameraScale: CGFloat = 4.0 / 3.0
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBar.shadowImage = UIImage()
        navigationController?.navigationBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        navigationController?.navigationBar.isHidden = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.appPureBlack
        
        self.cameraScale = CGFloat(cameraFramingHeight) / CGFloat(cameraFramingWidth)
        
        checkCameraAuthorized()
        addObsever()
        
    }
    
    func addObsever() {
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    @objc func appDidBecomeActive(_ noti: Notification) {
        if !cameraAuthorized {
            checkCameraAuthorized()
        }
    }
    
    // 检查相册权限
    func checkCameraAuthorized() {
        self.cameraPermissions(authorizedBlock: { [weak self] in
            guard let self = self else { return }
            self.cameraAuthorized = true
            FMLog(" --- 打开相机 --- ")
            DispatchQueue.main.async {
                self.setupUI()
            }
            
            }, deniedBlock: {[weak self] in
                guard let self = self else { return }
                FMLog(" --- 没有权限使用相机 --- ")
                self.cameraAuthorized = false
                DispatchQueue.main.async {
                    self.view.addSubview(self.closeButton)
                    self.view.addSubview(self.notAuthorizedView)
                }
                
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
        if let _ = self.maskURL {
            view.addSubview(maskImageView)
        }
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
        let position: AVCaptureDevice.Position = cameraChoice == 1 ? .front : .back
        if let videoDevice = cameraWithPosition(position: position) {
            do {
                let videoInput = try AVCaptureDeviceInput.init(device: videoDevice)
                if let s = session, s.canAddInput(videoInput) {
                    s.addInput(videoInput)
                }
                self.deviceInput = videoInput
            } catch (let error) {
                FMLog(" --- 设置视频输入错误 --- \(error)")
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
        //                FMLog(" --- 设置音频输入错误 --- \(error)")
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
    
    // 关闭
    @objc func close(_ sender: UIButton) {
        if isPresent {
            self.dismiss(animated: true, completion: nil)
        } else {
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    /// MARK: --- lazy loading
    lazy var closeButton: UIButton = {
        let button = UIButton(frame: CGRect(x: 8, y: Constants.statusBarHeight + 8, width: 40, height: 40))
        button.setImage(UIImage(named: "v1_common_close_white_normal"), for: .normal)
        button.addTarget(self, action: #selector(close(_:)), for: .touchUpInside)
        return button
    }()
    
    lazy var cameraView: FMCameraView = {
        let view = FMCameraView(frame: CGRect(x: 0, y: 0, width: screenWidth, height: screenHeight - Constants.bottomSafeMargin), cameraScale: self.cameraScale)
        view.delegate = self
        return view
    }()
    
    lazy var maskImageView: UIImageView = {
        let iv = UIImageView(frame: CGRect(x: 0, y: Constants.statusBarHeight + 56, width:screenWidth, height: screenWidth * cameraScale))
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        if let url = self.maskURL {
//            iv.kf.setImage(with: URL(string: url))
        }
        return iv
    }()
    
    lazy var previewImageView: UIImageView = {
        let iv = UIImageView(frame: CGRect(x: 0, y: Constants.statusBarHeight + 56, width: screenWidth, height: screenWidth * cameraScale))
        return iv
    }()
    
    lazy var notAuthorizedView: FMCameraNotAuthorizedView = {
        let view = FMCameraNotAuthorizedView(frame: CGRect(x: 0, y: Constants.statusBarHeight + 56, width: screenWidth, height: screenWidth), title: LocalizedString("wb_unableCamera", value: "无法启动相机", comment: "无法启动相机"), subTitle: LocalizedString("wb_unableCameraNoti", value: "请在设置中允许AcornBox访问你的相机", comment: "请在设置中允许AcornBox访问你的相机"))
        view.toSettings = { [weak self] in
            guard let self = self else { return }
            
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.openURL(url)
            }
            
        }
        return view
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
        FMLog(" --- ”相机“界面销毁了 --- ")
    }
    
}

extension FMCustomCameraViewController: FMCameraViewDelegate {
    
    // 关闭
    func closeAction(_ cameraView: FMCameraView) {
        if isPresent {
            self.dismiss(animated: true, completion: nil)
        } else {
            self.navigationController?.popViewController(animated: true)
        }
    }
    
    // 闪光灯
    func flashLightAction(_ cameraView: FMCameraView, handler: ((Error?) -> ())) {
        guard let device = activeCamera() else { return }
        let on = cameraManager.flashMode(device: device) == .on
        let mode: AVCaptureDevice.FlashMode = on ? .off : .on
        let error = cameraManager.changeFlash(device: device, mode: mode)
        handler(error)
    }
    // 手电筒
    func torchLightAction(_ cameraView: FMCameraView, handler: ((Error?) -> ())) {
        guard let device = activeCamera() else { return }
        let on = cameraManager.torchMode(device: device) == .on
        let mode: AVCaptureDevice.TorchMode = on ? .off : .on
        let error = cameraManager.changeTorch(device: device, mode: mode)
        handler(error)
    }
    // 转换摄像头
    func swicthCameraAction(_ cameraView: FMCameraView, handler: ((Error?) -> ())) {
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
    func autoFocusAndExposureAction(_ cameraView: FMCameraView, handler: ((Error?) -> ())) {
        guard let device = activeCamera() else { return }
        let error = cameraManager.resetFocusAndExposure(device: device)
        handler(error)
    }
    // 聚焦
    func focusAction(_ cameraView: FMCameraView, point: CGPoint, handler: ((Error?) -> ())) {
        guard let device = activeCamera() else { return }
        
        if let error = cameraManager.focus(device: device, point: point) {
            FMLog(" --- 聚焦出现错误 --- \(String(describing: error))")
        }
        
    }
    // 曝光
    func exposAction(_ cameraView: FMCameraView, point: CGPoint, handler: ((Error?) -> ())) {
        guard let device = activeCamera() else { return }
        let error = cameraManager.expose(device: device, point: point)
        handler(error)
    }
    // 缩放
    func zoomAction(_ cameraView: FMCameraView, factor: CGFloat) {
        guard let device = activeCamera() else { return }
        
        if let error = cameraManager.zoom(device: device, factor: factor) {
            FMLog(" --- 缩放出现错误 --- \(String(describing: error))")
        }
        
    }
    /// MARK: --- 拍摄照片
    func takePhotoAction(_ cameraView: FMCameraView, handler: @escaping ((Error?) -> ())) {
        if let connection = self.imageOutput?.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait//self.currentVideoOrientation()
            }
            // 设置前置摄像头拍照不镜像
            /*if let ad = activeCamera(), ad.position == .front,  connection.isVideoMirroringSupported {
             connection.isVideoMirrored = true
             }*/
            self.imageOutput?.captureStillImageAsynchronously(from: connection, completionHandler: { (buffer, error) in
                if let err = error {
                    handler(err)
                    return
                }
                if let b = buffer {
                    
                    if let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(b) {
                        
                        if let image = UIImage(data: imageData) {
                            self.previewImageView.isHidden = false
                            self.previewImageView.image = self.captureFinishWithImage(image)
                            handler(nil)
                        }
                        
                    }
                }
                
            })
        }
    }
    
    func captureFinishWithImage(_ image: UIImage) -> UIImage? {
        //因为拍照后的imageOrientation与实际不一致(旋转了90°)，所以调整回来
        guard let upImage = image.fixOrientation() else { return nil }
        
        let oSize = upImage.size
        
        let x: CGFloat = 0 * screenScale
        let w = oSize.width
        let y: CGFloat = (oSize.height - w * cameraScale) / 2.0
        let h = w * cameraScale
        
        let rect = CGRect(x: x, y: y, width: w, height: h)
        if let cgRef0 = upImage.cgImage {
            
            if let cgRef1 = cgRef0.cropping(to: rect) {
                let scaleImage = UIImage(cgImage: cgRef1, scale: screenScale, orientation: upImage.imageOrientation)
                return scaleImage
            }
            
        }
        return nil
    }
    
    private func savePhotoToAlbum(_ image: UIImage) {
        if FMTool.canAccessPhotoLib() {
            DispatchQueue.main.async {
                UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.saveImage(image:didFinishSavingWithError:contextInfo:)), nil)
            }
        } else {
            FMTool.requestAuthorizationForPhotoAccess(authorized: { [weak self] in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.saveImage(image:didFinishSavingWithError:contextInfo:)), nil)
                }
                }, rejected: {
                    DispatchQueue.main.async {
                        FMLog(" --- 保存失败 --- ")
                    }
            })
        }
    }
    
    @objc func saveImage(image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: AnyObject) {
        
        if error != nil{
            FMLog(" --- 保存失败 --- ")
        } else {
            FMLog(" --- 保存成功 --- ")
        }
        
    }
    
    // 取消 使用照片
    func cancelAction(_ cameraView: FMCameraView) {
        self.previewImageView.isHidden = true
        self.previewImageView.image = nil
    }
    
    // 确认使用照片
    func confirmAction(_ cameraView: FMCameraView) {
        if let image = previewImageView.image {
            self.confirmUserPhoto?(image)
            //            self.savePhotoToAlbum(image)
        }
        
        if isPresent {
            self.dismiss(animated: true, completion: nil)
        } else {
            self.navigationController?.popViewController(animated: true)
        }
        
    }
    
    /// MARK: --- 录制视频
    // 开始录像
    func startRecordVideoAction(_ cameraView: FMCameraView) {
        recording = true
        movieManager.currentDevice = activeCamera()
        movieManager.currentOrientation = currentVideoOrientation()
        movieManager.start { (error) in
            if let err = error {
                FMLog(" --- 录制视频开始失败 --- \(err)")
            }
        }
    }
    
    // 停止录像
    func stopRecordVideoAction(_ cameraView: FMCameraView) {
        recording = false
        movieManager.stop {[weak self] (error, url) in
            if let err = error {
                FMLog(" --- 录制视频结束失败 --- \(err)")
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
                    FMLog(" --- 保存失败 ---")
                } else {
                    FMLog(" --- 保存成功 ---")
                }
            }
        }
    }
    // 改变拍照模式
    func didChangeTypeAction(_ cameraView: FMCameraView, type: FMCameraType) {
    }
    
}

extension FMCustomCameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if recording, let video = videoConnection, let audio = audioConnection {
            movieManager.writeData(connection: connection, video: video, audio: audio, buffer: sampleBuffer)
        }
    }
}
