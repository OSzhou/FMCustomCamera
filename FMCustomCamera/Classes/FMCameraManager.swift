//
//  FMCameraManager.swift
//  FMCustomCamera
//
//  Created by Zhouheng on 2020/7/28.
//  Copyright © 2020 tataUFO. All rights reserved.
//

import UIKit
import AVFoundation

class FMCameraManager: NSObject {

    static let exposeObserverKey = "adjustingExposure"
    var CameraAdjustingExposureContext = 0
    var device: AVCaptureDevice?
    var isObserverRemoved: Bool = true
    /// 转换摄像头
    func switchCamera(session: AVCaptureSession, oldinput: AVCaptureDeviceInput, newinput: AVCaptureDeviceInput) -> AVCaptureDeviceInput {
        session.beginConfiguration()
        session.removeInput(oldinput)
        if session.canAddInput(newinput) {
            session.addInput(newinput)
            session.commitConfiguration()
            return newinput
        } else {
            session.addInput(oldinput)
            session.commitConfiguration()
            return oldinput
        }
    }
    
    /// 缩放
    func zoom(device: AVCaptureDevice, factor: CGFloat) -> NSError? {
        if device.activeFormat.videoMaxZoomFactor > factor, factor >= 1.0 {
            do {
                try device.lockForConfiguration()
                device.ramp(toVideoZoomFactor: factor, withRate: 4.0)
                device.unlockForConfiguration()
                return nil
            } catch (let error) {
                return error as NSError
            }
        }
        return error(text: "不支持的缩放倍数", code: 20000)
    }
    
    /// 聚焦
    func focus(device: AVCaptureDevice, point: CGPoint) -> NSError? {
        let supported = device.isFocusPointOfInterestSupported && device.isFocusModeSupported(.autoFocus)
        if supported {
            do {
                try device.lockForConfiguration()
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
                device.unlockForConfiguration()
                return nil
            } catch (let error) {
                return error as NSError
            }
        }
        return error(text: "设备不支持对焦", code: 20001)
    }
    
    /// 曝光
    func expose(device: AVCaptureDevice, point: CGPoint) -> NSError? {
        self.device = device
        let supported = device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose)
        if supported {
            do {
                try device.lockForConfiguration()
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
                if device.isExposureModeSupported(.locked) {
                    device.addObserver(self, forKeyPath: WBCameraManager.exposeObserverKey, options: .new, context: &CameraAdjustingExposureContext)
                    isObserverRemoved = false
                    print("++++++++++++++++++++++")
                }
                device.unlockForConfiguration()
                return nil
            } catch (let error) {
                return error as NSError
            }
        }
        return error(text: "设备不支持曝光", code: 20002)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &CameraAdjustingExposureContext {
            if let device = object as? AVCaptureDevice {
                if device.isAdjustingExposure, device.isExposureModeSupported(.locked) {
                    device.removeObserver(self, forKeyPath: WBCameraManager.exposeObserverKey, context: &CameraAdjustingExposureContext)
                    isObserverRemoved = true
                    print("--------------------")
                    DispatchQueue.main.async {
                        do {
                            try device.lockForConfiguration()
                            device.exposureMode = .locked
                            device.unlockForConfiguration()
                        } catch (let error) {
                            print(" --- 曝光监听出现错误 --- \(error)")
                        }
                    }
                }
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    /// 自动聚焦、曝光
    func resetFocusAndExposure(device: AVCaptureDevice) -> NSError? {
        let canResetFocus = device.isFocusPointOfInterestSupported && device.isFlashModeSupported(.auto)
        let canResetExposure = device.isExposurePointOfInterestSupported && device.isExposureModeSupported(.autoExpose)
        let centerPoint = CGPoint(x: 0.5, y: 0.5)
        do {
            try device.lockForConfiguration()
            if canResetFocus {
                device.focusMode = .autoFocus
                device.focusPointOfInterest = centerPoint
            }
            if canResetExposure {
                device.exposureMode = .autoExpose
                device.exposurePointOfInterest = centerPoint
            }
            device.unlockForConfiguration()
        } catch (let error) {
            return error as NSError
        }
        return nil
    }
    
    /// 闪光灯
    func flashMode(device: AVCaptureDevice) -> AVCaptureDevice.FlashMode {
        return device.flashMode
    }
    
    func changeFlash(device: AVCaptureDevice, mode: AVCaptureDevice.FlashMode) -> NSError? {
        if !device.hasFlash {
           return error(text: "不支持闪光灯", code: 20003)
        }
        if torchMode(device: device) == .on {
            let _ = self.setTorch(device: device, mode: .off)
        }
        return setFlash(device: device, mode: mode)
    }
    
    func setFlash(device: AVCaptureDevice, mode: AVCaptureDevice.FlashMode) -> NSError? {
        if device.isFlashModeSupported(mode) {
            do {
                try device.lockForConfiguration()
                device.flashMode = mode
                device.unlockForConfiguration()
                return nil
            } catch (let error) {
                return error as NSError
            }
        }
        return error(text: "不支持闪光灯", code: 20003)
    }
    
    /// 手电筒
    func torchMode(device: AVCaptureDevice) -> AVCaptureDevice.TorchMode {
        return device.torchMode
    }
    
    func changeTorch(device: AVCaptureDevice, mode: AVCaptureDevice.TorchMode) -> NSError? {
        if !device.hasTorch {
           return error(text: "不支持手电筒", code: 20004)
        }
        if flashMode(device: device) == .on {
            let _ = setFlash(device: device, mode: .off)
        }
        return setTorch(device: device, mode: mode)
    }
    
    func setTorch(device: AVCaptureDevice, mode: AVCaptureDevice.TorchMode) -> NSError? {
        
        if device.isTorchModeSupported(mode) {
            do {
                try device.lockForConfiguration()
                device.torchMode = mode
                device.unlockForConfiguration()
                return nil
            } catch (let error) {
                return error as NSError
            }
        }
        
        return error(text: "不支持手电筒", code: 20004)
    }
    
    private func error(text: String, code: Int) -> NSError {
        let desc = [NSLocalizedDescriptionKey: text]
        return NSError(domain: "com.wb.camera", code: code, userInfo: desc)
    }
    
    deinit {
        if !isObserverRemoved, let device = self.device {
            print("========================")
            device.removeObserver(self, forKeyPath: WBCameraManager.exposeObserverKey, context: &CameraAdjustingExposureContext)
        }
    }
}
