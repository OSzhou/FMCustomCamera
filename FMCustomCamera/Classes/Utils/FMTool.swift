//
//  FMTool.swift
//  FMCustomCamera
//
//  Created by Zhouheng on 2020/7/28.
//  Copyright © 2020 tataUFO. All rights reserved.
//

import UIKit

func FMLog<T> (message: T, file: String = #file, funcName: String = #function, lineNumber: Int = #line) {
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
