//
//  FMMotionManager.swift
//  FMCustomCamera
//
//  Created by Zhouheng on 2020/7/28.
//  Copyright © 2020 tataUFO. All rights reserved.
//

import UIKit
import CoreMotion
import AVFoundation

class FMMotionManager: NSObject {

    var motionManager: CMMotionManager?
    var deviceOrientation: UIDeviceOrientation = .portraitUpsideDown
    var videoOrientation: AVCaptureVideoOrientation = .portraitUpsideDown
    override init() {
        super.init()
        motionManager = CMMotionManager()
        motionManager?.deviceMotionUpdateInterval = 1.0 / 15.0
        if !(motionManager?.isDeviceMotionAvailable ?? true) {
            motionManager = nil
        } else {
            
            if let motionM = motionManager, let queue = OperationQueue.current {
               motionM.startDeviceMotionUpdates(to: queue, withHandler: { [weak self] (motion, error) in
                guard let self = self else { return }
                self.performSelector(onMainThread: #selector(self.handleDeviceMotion(_:)), with: motion, waitUntilDone: true)
                })
            }
            
        }
    }
    
    @objc func handleDeviceMotion(_ deviceMotion: CMDeviceMotion) {
        let x = deviceMotion.gravity.x
        let y = deviceMotion.gravity.y
        if fabs(y) >= fabs(x) {
            if y >= 0 {
                deviceOrientation = .portraitUpsideDown
                videoOrientation = .portraitUpsideDown
            } else {
                deviceOrientation = .portrait
                videoOrientation = .portrait
            }
        } else {
            if x >= 0 {
                deviceOrientation = .landscapeRight
                videoOrientation = .landscapeRight
            } else {
                deviceOrientation = .landscapeLeft
                videoOrientation = .landscapeLeft
            }
        }
    }
    
    deinit {
        motionManager?.stopDeviceMotionUpdates()
    }
    
}
