//
//  FMCameraView.swift
//  FMCustomCamera
//
//  Created by Zhouheng on 2020/7/28.
//  Copyright © 2020 tataUFO. All rights reserved.
//

import UIKit

enum FMCameraType {
    case photo
    case video
}

protocol FMCameraViewDelegate: class {
    /// 闪光灯
    func flashLightAction(_ cameraView: FMCameraView, handler: ((Error?) -> ()))
    /// 补光
    func torchLightAction(_ cameraView: FMCameraView, handler: ((Error?) -> ()))
    /// 转换摄像头
    func swicthCameraAction(_ cameraView: FMCameraView, handler: ((Error?) -> ()))
    /// 自动聚焦曝光
    func autoFocusAndExposureAction(_ cameraView: FMCameraView, handler: ((Error?) -> ()))
    /// 聚焦
    func focusAction(_ cameraView: FMCameraView, point: CGPoint, handler: ((Error?) -> ()))
    /// 曝光
    func exposAction(_ cameraView: FMCameraView, point: CGPoint, handler: ((Error?) -> ()))
    /// 缩放
    func zoomAction(_ cameraView: FMCameraView, factor: CGFloat)

    /// 关闭
    func closeAction(_ cameraView: FMCameraView)
    /// 取消
    func cancelAction(_ cameraView: FMCameraView)
    /// 确定
    func confirmAction(_ cameraView: FMCameraView)
    /// 拍照
    func takePhotoAction(_ cameraView: FMCameraView, handler: @escaping ((Error?) -> ()))
    /// 停止录制视频
    func stopRecordVideoAction(_ cameraView: FMCameraView)
    /// 开始录制视频
    func startRecordVideoAction(_ cameraView: FMCameraView)
    /// 改变拍摄类型 photo：拍照 video：视频
    func didChangeTypeAction(_ cameraView: FMCameraView, type: FMCameraType)
}

class FMCameraView: UIView {

    weak var delegate: FMCameraViewDelegate?

    fileprivate(set) var type: FMCameraType = .photo
    
    let topContentH: CGFloat = 56.0
    var scale: CGFloat = 4.0 / 3.0
    
    init(frame: CGRect, cameraScale: CGFloat) {
        super.init(frame: frame)
        self.scale = cameraScale
        setupUI()
    }
    
    private func setupUI() {
        
        self.addSubview(previewView)
        
        self.addSubview(topView)
        topView.addSubview(topContentView)
        
        topContentView.addSubview(closeButton)
        closeButton.snp.makeConstraints { (make) in
            make.left.equalTo(7)
            make.centerY.equalTo(topContentView)
            make.height.width.equalTo(50)
        }
        topContentView.addSubview(switchButton)
        switchButton.snp.makeConstraints { (make) in
            make.right.equalTo(-10)
            make.centerY.equalTo(topContentView)
            make.height.width.equalTo(50)
        }
        topContentView.addSubview(flashButton)
        flashButton.snp.makeConstraints { (make) in
            make.right.equalTo(switchButton.snp.left)
            make.centerY.equalTo(switchButton)
            make.height.width.equalTo(50)
        }
        
        self.addSubview(bottomView)
        
        previewView.addSubview(focusView)
        previewView.addSubview(exposureView)
        previewView.addSubview(slider)
        
        bottomView.addSubview(photoButton)
        photoButton.snp.makeConstraints { (make) in
            make.centerX.equalTo(bottomView)
            make.bottom.equalTo(bottomView)
            make.height.width.equalTo(56)
        }
        
        bottomView.addSubview(bottomCancelOrConfirmView)
        bottomCancelOrConfirmView.snp.makeConstraints { (make) in
            make.edges.equalTo(0)
        }
        bottomCancelOrConfirmView.addSubview(cancelButton)
        bottomCancelOrConfirmView.addSubview(confirmButton)
        cancelButton.snp.makeConstraints { (make) in
            make.left.bottom.equalTo(0)
            make.width.equalTo(120)
            make.height.equalTo(30)
        }
        
        confirmButton.snp.makeConstraints { (make) in
            make.right.bottom.equalTo(0)
            make.width.equalTo(120)
            make.height.equalTo(30)
        }

//        bottomView.addSubview(typeButton)
//        typeButton.center = CGPoint(x: bottomView.frame.width - 60, y: bottomView.frame.height / 2.0)
        
//        topView.addSubview(lightButton)
//        lightButton.center = CGPoint(x: lightButton.frame.width / 2.0 + switchButton.frame.maxX + 10, y: topView.frame.height / 2.0)
        
//        topView.addSubview(focusAndExposureButton)
//        focusAndExposureButton.center = CGPoint(x: focusAndExposureButton.frame.width / 2.0 + flashButton.frame.maxX + 10, y: topView.frame.height / 2.0)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// MARK: --- aciton
    /// 手电筒 开关
    func changeTorch(_ on: Bool) {
        lightButton.isSelected = on
    }
    
    /// 闪光灯 开关
    func changeFlash(_ on: Bool) {
        flashButton.isSelected = on
    }
    // 聚焦
    @objc func previewTapGesture(_ gesture: UITapGestureRecognizer) {
        guard let del = self.delegate else { return }
        let point = gesture.location(in: previewView)
        runFocusAnimation(focusView, point: point)
        del.focusAction(self, point: previewView.captureDevicePointForPoint(point)) { (error) in
            if let err =  error {
                logger.debug(" --- 聚焦时发生错误 --- \(String(describing: err))")
            }
        }
    }
    // 曝光
    @objc func previewDoubleTapGesture(_ gesture: UITapGestureRecognizer) {
        guard let del = self.delegate else { return }
        let point = gesture.location(in: previewView)
        runFocusAnimation(exposureView, point: point)
        del.exposAction(self, point: previewView.captureDevicePointForPoint(point)) { (error) in
            if let err = error {
                 logger.debug(" --- 曝光时发生错误 --- \(String(describing: err))")
            }
        }
    }
    // 缩放
    @objc func previewPinchGesture(_ gesture: UIPinchGestureRecognizer) {
        guard let del = self.delegate else { return }
        if gesture.state == .began {
            UIView.animate(withDuration: 0.1) {
                self.slider.alpha = 1.0
            }
        } else if gesture.state == .changed {
            if gesture.velocity > 0 {
                slider.value += Float(gesture.velocity / 100.0)
            } else {
                slider.value += Float(gesture.velocity / 20.0)
            }
            del.zoomAction(self, factor: pow(5, CGFloat(slider.value)))
        } else {
            UIView.animate(withDuration: 0.1) {
                self.slider.alpha = 0.0
            }
        }
    }
    
    // 自动聚焦和曝光
    @objc func focusAndExposureClick(_ sender: UIButton) {
        guard let del = self.delegate else { return }
        runResetAnimation()
        del.autoFocusAndExposureAction(self) { (error) in
            if let err = error {
                logger.debug(" --- 自动聚焦和曝光时发生错误 --- \(String(describing: err))")
            }
        }
    }
    
    // 拍照、视频
    @objc func takePicture(_ sender: UIButton) {
        if type == .photo {
            self.delegate?.takePhotoAction(self, handler: { [weak self] (error) in
                guard let self = self else { return }
                
                if let err = error {
                    logger.debug(" --- 拍照时发生错误 --- \(err)")
                } else {
                    DispatchQueue.main.async {
                        self.topContentView.isHidden = true
                        self.photoButton.isHidden = true
                        self.bottomCancelOrConfirmView.isHidden = false
                    }
                }
                
            })
            sender.isEnabled = false
        } else {
            if sender.isSelected {
                sender.isSelected = false
//                photoButton.setTitle("开始", for: .normal)
                self.delegate?.stopRecordVideoAction(self)
            } else {
                sender.isSelected = true
//                photoButton.setTitle("结束", for: .selected)
                self.delegate?.startRecordVideoAction(self)
            }
        }
    }
    
    // 关闭
    @objc func close(_ sender: UIButton) {
        self.delegate?.closeAction(self)
    }
    
    // 取消
    @objc func cancel(_ sender: UIButton) {
        self.photoButton.isEnabled = true
        self.delegate?.cancelAction(self)
        self.topContentView.isHidden = false
        self.photoButton.isHidden = false
        self.bottomCancelOrConfirmView.isHidden = true
    }
    
    // 确定
    @objc func confirm(_ sender: UIButton) {
        self.delegate?.confirmAction(self)
    }
    
    // 转换拍照类型
    @objc func changeType(_ sender: UIButton) {
        sender.isSelected = !sender.isSelected
        type = self.type == .photo ? .video : .photo
        if type == .photo {
            photoButton.setTitle("拍照", for: .normal)
        } else {
            photoButton.setTitle("开始", for: .normal)
        }
        self.delegate?.didChangeTypeAction(self, type: type)
    }
    
    // 转换前后摄像头
    @objc func switchCameraClick(_ sender: UIButton) {
        self.delegate?.swicthCameraAction(self, handler: { (error) in
            if let err = error {
                logger.debug(" --- 转换摄像头时发生错误 --- \(String(describing: err))")
            }
        })
    }
    
    // 手电筒
    @objc func torchClick(_ sender: UIButton) {
        self.delegate?.torchLightAction(self, handler: { (error) in
            if let err = error, !err.localizedDescription.isEmpty {
                logger.debug(" --- 打开手电筒时发生错误 --- \(String(describing: error))")
            } else {
                self.flashButton.isSelected = false
                self.lightButton.isSelected = !self.lightButton.isSelected
            }
        })
    }
    
    // 闪光灯
    @objc func flashClick(_ sender: UIButton) {
        self.delegate?.flashLightAction(self, handler: { (error) in
            if let err = error, !err.localizedDescription.isEmpty {
                logger.debug(" --- 打开闪光灯时发生错误 --- \(String(describing: error))")
            } else {
                self.flashButton.isSelected = !self.flashButton.isSelected
                self.lightButton.isSelected = false
            }
        })
    }
    
    // 聚焦、曝光动画
    private func runFocusAnimation(_ view: UIView, point: CGPoint) {
        view.center = point
        view.isHidden = false
        UIView.animate(withDuration: 0.15, delay: 0.0, options: .curveEaseInOut, animations: {
            view.layer.transform = CATransform3DMakeScale(0.5, 0.5, 1.0)
        }) { (_) in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                view.isHidden = true
                view.transform = .identity
            }
        }
    }
    
    // 自动聚焦、曝光动画
    private func runResetAnimation() {
        focusView.center = CGPoint(x: previewView.frame.width / 2.0, y: previewView.frame.height / 2.0)
        exposureView.center = CGPoint(x: previewView.frame.width / 2.0, y: previewView.frame.height / 2.0)
        exposureView.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        focusView.isHidden = false
        exposureView.isHidden = false
        UIView.animate(withDuration: 0.15, delay: 0.0, options: .curveEaseInOut, animations: {
            self.focusView.layer.transform = CATransform3DMakeScale(0.5, 0.5, 1.0)
            self.exposureView.layer.transform = CATransform3DMakeScale(0.7, 0.7, 1.0)
        }) { (_) in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.focusView.isHidden = true
                self.exposureView.isHidden = true
                self.focusView.transform = .identity
                self.exposureView.transform = .identity
            }
        }
    }
    
    /// MARK: --- lazy loading
    lazy var topView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: screenWidth, height: G.shared.statusBarHeight + topContentH))
        view.backgroundColor = UIColor.appPureBlack
        return view
    }()
    
    lazy var topContentView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: G.shared.statusBarHeight, width: screenWidth, height: topContentH))
        return view
    }()
    
    lazy var closeButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: "v1_common_close_white_normal"), for: .normal)
        button.addTarget(self, action: #selector(close(_:)), for: .touchUpInside)
        return button
    }()
    
    // 转换摄像头
    lazy var switchButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: "FM_switch_camera"), for: .normal)
        button.addTarget(self, action: #selector(switchCameraClick(_:)), for: .touchUpInside)
        return button
    }()
    
    // 闪光灯
    lazy var flashButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: "FM_flash_off"), for: .normal)
        button.setImage(UIImage(named: "FM_flash_on"), for: .selected)
        button.addTarget(self, action: #selector(flashClick(_:)), for: .touchUpInside)
        return button
    }()
    
    lazy var bottomView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: self.frame.height - 60 - G.shared.bottomSafeMargin - 17, width: screenWidth, height: 60))
        view.backgroundColor = .black
        return view
    }()
    
    // 拍照
    lazy var photoButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: "FM_take_photo"), for: .normal)
        button.addTarget(self, action: #selector(takePicture(_:)), for: .touchUpInside)
        return button
    }()
    
    lazy var bottomCancelOrConfirmView: UIView = {
        let view = UIView()
        view.isHidden = true
        return view
    }()
    
    // 取消
    lazy var cancelButton: UIButton = {
        let button = self.buttonFactory(LocalizedString("cancel", value: "取消", comment: "取消"), action: #selector(cancel(_:)))
        return button
    }()
    
    // 确认
    lazy var confirmButton: UIButton = {
        let button = self.buttonFactory(LocalizedString("confirm", value: "确认", comment: "确认"), action: #selector(confirm(_:)))
        return button
    }()
    
    lazy var focusView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 150, height: 150))
        view.backgroundColor = .clear
        view.layer.borderColor = UIColor.clear.cgColor
        view.layer.borderWidth = 5.0
        view.isHidden = true
        return view
    }()
    
    lazy var exposureView: UIView = {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 150, height: 150))
        view.backgroundColor = .clear
        view.layer.borderColor = UIColor.purple.cgColor
        view.layer.borderWidth = 5.0
        view.isHidden = true
        return view
    }()
    
    lazy var slider: UISlider = {
        let slider = UISlider(frame: CGRect(x: screenWidth - 150, y: 130, width: 200, height: 1.0))
        slider.minimumValue = 0.0
        slider.maximumValue = 1.0
        slider.minimumTrackTintColor = .white
        slider.maximumTrackTintColor = .white
        slider.backgroundColor = .white
        slider.alpha = 0.0
        slider.transform = CGAffineTransform(rotationAngle: CGFloat.pi / 2.0)
        return slider
    }()
    
    fileprivate(set) lazy var previewView: FMVideoPreview = {
        let view = FMVideoPreview(frame: CGRect(x: 0, y: G.shared.statusBarHeight + topContentH, width: screenWidth, height: screenWidth * scale))
        // 单指 (聚焦)
        let tap = UITapGestureRecognizer(target: self, action: #selector(previewTapGesture(_:)))
        // 双指 (曝光)
        /*let doubleTap = UITapGestureRecognizer(target: self, action: #selector(previewDoubleTapGesture(_:)))
        doubleTap.numberOfTouchesRequired = 2
        tap.require(toFail: doubleTap)
        view.addGestureRecognizer(doubleTap)*/
        
        view.addGestureRecognizer(tap)
        
        // 捏合
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(previewPinchGesture(_:)))
        view.addGestureRecognizer(pinch)
        
        return view
    }()
    
    private func buttonFactory(_ normolT: String, selectedT: String = "", action: Selector) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(normolT, for: .normal)
        button.setTitle(selectedT, for: .selected)
        button.titleLabel?.font = UIFont.appBoldFont(18.0)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
    
    // 拍摄类型
    lazy var typeButton: UIButton = {
        let button = self.buttonFactory("照片", selectedT: "视频", action: #selector(changeType(_:)))
        return button
    }()
    
    // 补光
    lazy var lightButton: UIButton = {
        let button = self.buttonFactory("补光", action: #selector(torchClick(_:)))
        return button
    }()
    
    // 重置对焦、曝光
    lazy var focusAndExposureButton: UIButton = {
        let button = self.buttonFactory("自动聚焦/曝光", action: #selector(focusAndExposureClick(_:)))
        return button
    }()
}
