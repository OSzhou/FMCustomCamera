# FMCustomCamera
This is a custom camera view kit
一个 自定义相机

![](https://upload-images.jianshu.io/upload_images/2149459-f5971159418b0af6.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)

- 可能用到的delegate接口说明
```
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
```

- 自定义UI见面，可以自行修改`FMCameraView`中的代码

- 相机界面初始化，可参照`FMCustomCameraViewController`
