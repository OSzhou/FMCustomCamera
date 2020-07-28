//
//  FMCameraNotAuthorizedView.swift
//  FMCustomCamera
//
//  Created by Zhouheng on 2020/7/28.
//  Copyright © 2020 tataUFO. All rights reserved.
//

import UIKit

class FMCameraNotAuthorizedView: UIView {

    var toSettings: (() -> ())?
    
    init(frame: CGRect, title: String, subTitle: String) {
        super.init(frame: frame)
        
        setupUI()
        
        titleLabel.text = title
        subtitleLabel.text = subTitle
    }
    
    private func setupUI() {
        self.addSubview(containerView)
        containerView.snp.makeConstraints { (make) in
            make.edges.equalTo(0)
        }
        
        containerView.addSubview(contentView)
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { (make) in
            make.left.top.right.equalTo(0)
            make.width.lessThanOrEqualTo(screenWidth - 40)
        }
        
        contentView.addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { (make) in
            make.centerX.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
            make.width.lessThanOrEqualTo(screenWidth - 40)
        }
        
        contentView.addSubview(settingsLabel)
        settingsLabel.snp.makeConstraints { (make) in
            make.centerX.equalTo(subtitleLabel)
            make.top.equalTo(subtitleLabel.snp.bottom)
        }
        contentView.snp.makeConstraints { (make) in
            make.center.equalTo(self)
            make.bottom.equalTo(settingsLabel)
        }
    }
    
    @objc func toSettingsGesture(_ gesture: UITapGestureRecognizer) {
        self.toSettings?()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    /// MARK: --- lazy loading
    lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.appColor242F35
        return view
    }()
    
    lazy var contentView: UIView = {
        let view = UIView()
        return view
    }()
    
    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.appBoldFont(18)
        label.textColor = UIColor.appWhite
        label.textAlignment = .center
        return label
    }()
    
    lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.appFont(14)
        label.textColor = UIColor.appWhite
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()
    
    lazy var settingsLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.appBoldFont(14)
        label.textColor = UIColor.appColorFF5914
        label.textAlignment = .center
        
        let toSetting = LocalizedString("wb_toSettings", value: "去设置", comment: "去设置") + ">"
        let attributedString = NSMutableAttributedString(string: toSetting)
        attributedString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: attributedString.length))
        label.attributedText = attributedString

        label.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(toSettingsGesture(_:)))
        label.addGestureRecognizer(tap)
        return label
    }()

}
