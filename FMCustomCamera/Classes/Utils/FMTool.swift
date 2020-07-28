//
//  FMTool.swift
//  FMCustomCamera
//
//  Created by Zhouheng on 2020/7/28.
//  Copyright © 2020 tataUFO. All rights reserved.
//

import UIKit
import Foundation
import Photos
import UIKit

// MARK: 屏幕高度
let screenHeight: CGFloat = UIScreen.main.bounds.height
// MARK: 屏幕宽度
let screenWidth: CGFloat = UIScreen.main.bounds.width
// MARK: 屏幕比率
let screenScale: CGFloat = UIScreen.main.scale

struct Constants {
    static let bottomSafeMargin: CGFloat = UIDevice.current.iPhoneX() ? 34.0 :0.0

    static let navAndStatusBarHeight: CGFloat = UIDevice.current.iPhoneX() ? 88.0 : 64.0

    static let statusBarHeight: CGFloat = UIDevice.current.iPhoneX() ? 44.0 : 20.0
}

func FMLog<T> (_ message: T, file: String = #file, funcName: String = #function, lineNumber: Int = #line) {
    #if DEBUG
    let fileName = (file as NSString).lastPathComponent
    let ocFileName = fileName as NSString
    var str = ""
    if ocFileName.hasSuffix(".swift") {
        let range = ocFileName.range(of: ".swift")
        str = ocFileName.substring(to: range.location)
    }
    print("[\(str)-\(funcName)-line:\(lineNumber)]: \(message)")
    #endif
}

extension UIColor {
    /// 白色
    static let appWhite = UIColor.white
    
    /// 纯黑
    static let appPureBlack = UIColor(hex: "000000")
    
    /// app main color - FF8214
    static let appColorFF8214 = UIColor(hex: "FF8214")
    
    /// 90A7B2
    static let appColor90A7B2 = UIColor(hex: "90A7B2")
    
    /// 9099A2
    static let appColor9099A2 = UIColor(hex: "9099A2")
    
    /// F6F6F8
    static let appColorF6F6F8 = UIColor(hex: "F6F6F8")
    
    /// 242F35
    static let appColor242F35 = UIColor(hex: "242F35")
    
    /// FF5914
    static let appColorFF5914 = UIColor(hex: "FF5914")
    
    /// 1E2124
    static let appColor1E2124 = UIColor(hex: "1E2124")
    
    /// 18294E
    static let appColor18294E = UIColor(hex: "18294E")
    
    /// 00C77B
    static let appColor00C77B = UIColor(hex: "00C77B")
    
    /// 002035
    static let appColor002035 = UIColor(hex: "002035")
    
    /// 252F35
    static let appColor252F35 = UIColor(hex: "252F35")
    
    /// FFA400
    static let appColorFFA400 = UIColor(hex: "FFA400")
}

extension UIColor {
    convenience init(red: Int, green: Int, blue: Int) {
        assert(red >= 0 && red <= 255, "Invalid red component")
        assert(green >= 0 && green <= 255, "Invalid green component")
        assert(blue >= 0 && blue <= 255, "Invalid blue component")

        self.init(red: CGFloat(red) / 255.0, green: CGFloat(green) / 255.0, blue: CGFloat(blue) / 255.0, alpha: 1.0)
    }

    convenience init(netHex: Int) {
        self.init(red: (netHex >> 16) & 0xff, green: (netHex >> 8) & 0xff, blue: netHex & 0xff)
    }

    convenience init(hex: String) {
        let scanner = Scanner(string: hex)
        scanner.scanLocation = 0

        var rgbValue: UInt64 = 0

        scanner.scanHexInt64(&rgbValue)

        let r = (rgbValue & 0xff0000) >> 16
        let g = (rgbValue & 0xff00) >> 8
        let b = rgbValue & 0xff

        self.init(
            red: CGFloat(r) / 0xff,
            green: CGFloat(g) / 0xff,
            blue: CGFloat(b) / 0xff, alpha: 1
        )
    }
    
    static func averageColor(fromColor: UIColor, toColor: UIColor, percent: CGFloat) -> UIColor {
        var fromRed: CGFloat = 0
        var fromGreen: CGFloat = 0
        var fromBlue: CGFloat = 0
        var fromAlpha: CGFloat = 0
        fromColor.getRed(&fromRed, green: &fromGreen, blue: &fromBlue, alpha: &fromAlpha)
        
        var toRed: CGFloat = 0
        var toGreen: CGFloat = 0
        var toBlue: CGFloat = 0
        var toAlpha: CGFloat = 0
        toColor.getRed(&toRed, green: &toGreen, blue: &toBlue, alpha: &toAlpha)
        
        let nowRed = fromRed + (toRed - fromRed) * percent
        let nowGreen = fromGreen + (toGreen - fromGreen) * percent
        let nowBlue = fromBlue + (toBlue - fromBlue) * percent
        let nowAlpha = fromAlpha + (toAlpha - fromAlpha) * percent
        
        return UIColor(red: nowRed, green: nowGreen, blue: nowBlue, alpha: nowAlpha)
    }
}

extension UIFont {
    static func appFont(_ size: CGFloat) -> UIFont {
//        return UIFont(name: "PingFangSC-Regular", size: size)!
//        return UIFont(name: "Montserrat-Regular", size: size)!
        return UIFont(name: "AmericanTypewriter", size: size)!
    }

    static func appBoldFont(_ size: CGFloat) -> UIFont {
//        return UIFont(name: "PingFangSC-Bold", size: size)!
//        return UIFont(name: "Montserrat-Bold", size: size)!
        return UIFont(name: "AmericanTypewriter-Bold", size: size)!
    }
    
    static func appSemiBoldFont(_ size: CGFloat) -> UIFont {
//        return UIFont(name: "PingFangSC-Semibold", size: size)!
//        return UIFont(name: "Montserrat-SemiBold", size: size)!
        return UIFont(name: "AmericanTypewriter-Semibold", size: size)!
    }
    
}

func LocalizedString(_ key: String, value: String, comment: String) -> String {
    return NSLocalizedString(key, tableName: "",
                             bundle: Bundle.main,
                             value: value,
                             comment: comment)
}

class FMTool: NSObject {
    static func canAccessPhotoLib() -> Bool {
        return PHPhotoLibrary.authorizationStatus() == .authorized
    }
    
    static func openIphoneSetting() {
        UIApplication.shared.openURL(URL(string: UIApplication.openSettingsURLString)!)
    }
    static func requestAuthorizationForPhotoAccess(authorized: @escaping () -> Void, rejected: @escaping () -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                if status == .authorized {
                    authorized()
                } else {
                    rejected()
                }
            }
        }
    }
}

extension UIImage {
    // 修复图片旋转
    func fixOrientation() -> UIImage? {
        
        if self.imageOrientation == .up {
            return self
        }
        
        var transform = CGAffineTransform.identity
        
        switch self.imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: self.size.width, y: self.size.height)
            transform = transform.rotated(by: .pi)
            break
            
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: self.size.width, y: 0)
            transform = transform.rotated(by: .pi/2)
            break
            
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: self.size.height)
            transform = transform.rotated(by: -.pi/2)
            break
            
        default:
            break
        }
        
        switch self.imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: self.size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
            break
            
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: self.size.height, y: 0);
            transform = transform.scaledBy(x: -1, y: 1)
            break
        default:
            break
        }
        
        let ctx = CGContext(data: nil, width: Int(self.size.width), height: Int(self.size.height), bitsPerComponent: self.cgImage!.bitsPerComponent, bytesPerRow: 0, space: self.cgImage!.colorSpace!, bitmapInfo: self.cgImage!.bitmapInfo.rawValue)
        ctx?.concatenate(transform)
        
        switch self.imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            ctx?.draw(self.cgImage!, in:CGRect(x:CGFloat(0), y:CGFloat(0), width:CGFloat(size.height), height:CGFloat(size.width)))
            break
            
        default:
            ctx?.draw(self.cgImage!, in:CGRect(x:CGFloat(0), y:CGFloat(0), width:CGFloat(size.width), height:CGFloat(size.height)))
            break
        }
        
        if let cgimg: CGImage = ctx?.makeImage() {
            let img = UIImage(cgImage: cgimg)
            return img
        }
        
        return nil
    }
}
