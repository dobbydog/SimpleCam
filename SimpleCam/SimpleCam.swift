//
//  SimpleCam.m
//  SimpleCam
//
//  Created by Logan Wright on 2/1/14.
//  Copyright (c) 2014 Logan Wright. All rights reserved.
//
//  Mozilla Public License v2.0
//
//  **
//
//  PLEASE FAMILIARIZE YOURSELF WITH THE ----- Mozilla Public License v2.0
//
//  **
//
//  Attribution is satisfied by acknowledging the use of SimpleCam,
//  or its creation by Logan Wright
//
//  **
//
//  You can use, modify and redistribute this code in your product,
//  but to satisfy the requirements of Mozilla Public License v2.0,
//  it is required to provide the source code for any fixes you make to it.
//
//  **
//
//  Covered Software is provided under this License on an “as is” basis, without warranty of any
//  kind, either expressed, implied, or statutory, including, without limitation, warranties that
//  the Covered Software is free of defects, merchantable, fit for a particular purpose or non-
//  infringing. The entire risk as to the quality and performance of the Covered Software is with
//  You. Should any Covered Software prove defective in any respect, You (not any Contributor)
//  assume the cost of any necessary servicing, repair, or correction. This disclaimer of
//  warranty constitutes an essential part of this License. No use of any Covered Software is
//  authorized under this License except under this disclaimer.
//
//  **
//

/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import UIKit
import AVFoundation
import ImageIO

@objc
public protocol SimpleCamDelegate {
    func simpleCamNotAuthorizedForCameraUse(_ simpleCam: SimpleCam) -> Void
    func simpleCam(_ simpleCam: SimpleCam, didFinishWithImage image: UIImage?) -> Void
    @objc optional func simpleCam(_ simpleCam: SimpleCam, didCaptureImage image: UIImage?) -> Void
    @objc optional func simpleCamDidLoadCameraIntoView(_ simpleCam: SimpleCam) -> Void
}

public class SimpleCam : UIViewController {
    private var screenWidth: CGFloat!
    private var screenHeight: CGFloat!
    private var isImageResized = false
    private var isSaveWaitingForResizedImage = false
    private var isCapturingImage = false
    private var currentScale: CGFloat = 1
    @IBOutlet weak var cameraCaptureFlashAnimation: UIView!
    public weak var delegate: SimpleCamDelegate?
    private var _hideAllControls = false
    public var hideAllControls: Bool {
        get { return _hideAllControls }
        set {
            _hideAllControls = hideAllControls
            // This way, hideAllControls can be used as a toggle.
            drawControls()
        }
    }
    private var _hideCaptureButton = false
    public var hideCaptureButton: Bool {
        get { return _hideCaptureButton }
        set {
            _hideCaptureButton = newValue
            captureBtn.isHidden = newValue
        }
    }
    private var _hideBackButton = false
    public var hideBackButton: Bool {
        get { return _hideBackButton }
        set {
            _hideBackButton = newValue
            backBtn.isHidden = newValue
        }
    }
    public var enableZoom = false
    public var enableCameraCaptureAnimation = false
    public var disablePhotoPreview = false
    public var controlAnimateDuration: Float
    @IBOutlet weak var verticalBar: UIView!
    @IBOutlet weak var horizontalBar: UIView!
    @IBOutlet weak var backBtn: UIButton!
    @IBOutlet weak var captureBtn: UIButton!
    @IBOutlet weak var switchCameraBtn: UIButton!
    @IBOutlet weak var saveBtn: UIButton!
    @IBOutlet weak var retakeBtn: UIButton!
    private var session: AVCaptureSession!
    private var stillImageOutput: AVCaptureStillImageOutput!
    fileprivate var _photoOutput: Any!
    @available(iOS 10.0, *)
    fileprivate var photoOutput: AVCapturePhotoOutput! {
        get { return _photoOutput as! AVCapturePhotoOutput }
        set { _photoOutput = newValue }
    }
    private var currentDevice: AVCaptureDevice!
    private var captureVideoPreviewLayer: AVCaptureVideoPreviewLayer!
    @IBOutlet weak var imageStreamV: UIView!
    @IBOutlet weak var capturedImageV: UIImageView!
    private var capturedImage: UIImage!

    override public init(nibName nibNameOrNil: String?, bundle bundleOrNil: Bundle?) {
        // Custom initialization
        controlAnimateDuration = 0.25
        var nibName = nibNameOrNil
        var bundle = bundleOrNil

        if nibName == nil && bundle == nil {
            nibName = "SimpleCam"
            bundle = Bundle(for: type(of: self))
        }

        super.init(nibName: nibName, bundle: bundle)
    }
    
    required public init?(coder: NSCoder) {
        // Custom initialization
        controlAnimateDuration = 0.25
        super.init(coder: coder)
    }

    override public func viewDidLoad() {

        super.viewDidLoad()

        if #available(iOS 8.0, *) {
            // iOS 8
            
            // Thanks: http://stackoverflow.com/a/24684021/2611971
            let status = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
            if status == .authorized {
                // Do setup early if possible.
                setup()
            }
        }
        else {
            // Pre iOS 8 -- No camera auth required.
            setup()
        }
    }
    
    override public func viewDidAppear(_ animated: Bool) {

        super.viewDidAppear(animated)

        if #available(iOS 8.0, *) {
            // iOS 8
            let status = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
            switch status {
            case .denied, .restricted:
                print("SC: Not authorized, or restricted")
                delegate?.simpleCamNotAuthorizedForCameraUse(self)
            case .authorized:
                animateIntoView()
            case .notDetermined:
                // not determined
                AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo) { granted in
                    DispatchQueue.main.async {
                        if granted {
                            self.setup()
                            self.animateIntoView()
                        } else {
                            self.delegate?.simpleCam(self, didFinishWithImage: nil)
                        }
                    }
                }
            }
        }
        else {
            // Pre iOS 8 -- No camera auth required.
            animateIntoView()
        }
    }

    func animateIntoView() {
        self.rotatePreviewLayer()

        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut, animations: { [weak self] in
            guard let `self` = self else { return }
            self.imageStreamV.alpha = 1
        }) { finished in
            if finished {
                self.delegate?.simpleCamDidLoadCameraIntoView?(self)
            }
        }
    }

    override public func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        print("SC: DID RECIEVE MEMORY WARNING")
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Setup

    func setup() {

        /*
         The layout has shifted in iOS 8 causing problems.  I realize that this isn't the best solution, so if you're looking at this, feel free to submit a Pull Request.  This is an older project.
         */
        let screen = UIScreen.main.bounds
        let currentWidth = screen.width
        let currentHeight = screen.height
        screenWidth = currentWidth < currentHeight ? currentWidth : currentHeight
        screenHeight = currentWidth < currentHeight ? currentHeight : currentWidth

        // SETTING UP CAM
        if session == nil { session = AVCaptureSession() }
        session.sessionPreset = AVCaptureSessionPresetPhoto

        captureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        captureVideoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        captureVideoPreviewLayer.frame = imageStreamV.layer.bounds // parent of layer

        imageStreamV.layer.addSublayer(captureVideoPreviewLayer)

        // rear camera: 0 front camera: 1
        let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as! [AVCaptureDevice]
        if devices.count == 0 {
            print("SC: No devices found (for example: simulator)")
            return
        }
        currentDevice = devices[0]

        if currentDevice.isFlashAvailable && currentDevice.isFlashActive {
            //print("SC: Turning Flash Off ...");
            do {
                try currentDevice.lockForConfiguration()
                currentDevice.flashMode = .off
                currentDevice.unlockForConfiguration()
            } catch let error {
                print("SC: ERROR: lock for camera configuration: \(error.localizedDescription)")
            }
        }

        do {
            let input = try AVCaptureDeviceInput(device: currentDevice)
            session.addInput(input)
        } catch let error {
            print("SC: ERROR: open camera: \(error.localizedDescription)")
        }

        if #available(iOS 10.0, *) {
            photoOutput = AVCapturePhotoOutput()
            session.addOutput(photoOutput)
        } else {
            stillImageOutput = AVCaptureStillImageOutput()
            stillImageOutput.outputSettings = [AVVideoCodecKey: AVVideoCodecJPEG]
            session.addOutput(stillImageOutput)
        }

        session.startRunning()

        // -- PREPARE OUR CONTROLS -- //
        // If a device doesn't have multiple cameras, fade out button ...
        if AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo).count == 1 {
            switchCameraBtn.isEnabled = false
        }
        
        // Draw camera controls
        drawControls()
    }

    // MARK: CAMERA CONTROLS

    func drawControls() {
        if hideAllControls {
            verticalBar.isHidden = true
            horizontalBar.isHidden = true
            return
        }

        UIView.animate(withDuration: TimeInterval(controlAnimateDuration), delay: 0, options: .curveEaseOut, animations: { [weak self] in
            guard let `self` = self else { return }
            let imageCaptured = self.capturedImageV.image != nil

            self.verticalBar.isHidden = imageCaptured
            self.horizontalBar.isHidden = !imageCaptured
        }, completion: nil)
    }
    
    public func capturePhoto() {
        if isCapturingImage { return }
        
        if #available(iOS 10.0, *) {
            isCapturingImage = true
            let settings = AVCapturePhotoSettings();
            settings.flashMode = currentDevice.isFlashAvailable ? .auto : .off
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
        else {
            guard let connection = stillImageOutput.connection(withMediaType: AVMediaTypeVideo) else {
                print("SC: ERROR: capturing image: output connection not found")
                return
            }
            
            isCapturingImage = true
            stillImageOutput.captureStillImageAsynchronously(from: connection) { [weak self] imageSampleBuffer, error in
                
                if let error = error {
                    print("SC: ERROR: capturing image: \(error.localizedDescription)")
                    return
                }
                
                guard
                    let `self` = self,
                    let buffer = imageSampleBuffer,
                    CMSampleBufferIsValid(buffer),
                    let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(buffer),
                    let image = UIImage(data: imageData)
                else {
                    print("SC: ERROR: capturing image: image data creation failed")
                    return
                }
                
                self.processPhoto(image)
            }
        }
    }
    
    func processPhoto(_ image: UIImage) {
        guard let cgImage = image.cgImage else {
            isCapturingImage = false
            return
        }

        // Camera "flash" animation
        if enableCameraCaptureAnimation {
            UIView.animate(withDuration: 0.2, animations: { [weak self] in
                guard let `self` = self else { return }
                self.cameraCaptureFlashAnimation.alpha = 1.0
                self.cameraCaptureFlashAnimation.setNeedsDisplay()
            }) { finished in
                UIView.animate(withDuration: 0.2, animations: { [weak self] in
                    guard let `self` = self else { return }
                    self.cameraCaptureFlashAnimation.alpha = 0.0
                })
            }
        }
        
        let orientation = UIDevice.current.orientation
        let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as! [AVCaptureDevice]
        let isLandscapeRight = orientation == .landscapeRight
        let isLandscapeLeft = orientation == .landscapeLeft
        let isPortraitUpsideDown = orientation == .portraitUpsideDown
        let isRearCamera = currentDevice == devices[0]
        let isFrontCamera = currentDevice == devices[1]
        let imageOrientation: UIImageOrientation
        
        if isLandscapeRight && isRearCamera || isLandscapeLeft && isFrontCamera {
            imageOrientation = .down
        } else if isLandscapeRight && isFrontCamera || isLandscapeLeft && isRearCamera {
            imageOrientation = .up
        } else if isPortraitUpsideDown {
            imageOrientation = .left
        } else {
            imageOrientation = .right
        }
        
        isCapturingImage = false
        capturedImage = crop(UIImage(cgImage: cgImage, scale: image.scale, orientation: imageOrientation))
        capturedImageV.image = capturedImage
        // show captured image view
        capturedImageV.isHidden = false
        // hide image stream view
        imageStreamV.isHidden = true
        
        // If we have disabled the photo preview directly fire the delegate callback, otherwise, show user a preview
        disablePhotoPreview ? photoCaptured() : drawControls()
        
        delegate?.simpleCam?(self, didCaptureImage: capturedImage)
    }

    public func retakePhoto() -> Bool {
        if capturedImageV.image == nil {
            return false
        }

        imageStreamV.isHidden = false
        capturedImageV.contentMode = .scaleAspectFill
        capturedImageV.backgroundColor = .clear
        capturedImageV.image = nil
        capturedImageV.isHidden = true
        capturedImage = nil

        isImageResized = false
        isSaveWaitingForResizedImage = false
        
        drawControls()
        return true
    }

    func photoCaptured() {
        if isImageResized {
            delegate?.simpleCam(self, didFinishWithImage: capturedImage)
        }
        else {
            isSaveWaitingForResizedImage = true
            resizeImage()
        }
    }

    // MARK: BUTTON EVENTS

    @IBAction func captureBtnPressed(_ sender: AnyObject!) {
        capturePhoto()
    }

    @IBAction func saveBtnPressed(_ sender: AnyObject!) {
        photoCaptured()
    }

    @IBAction func backBtnPressed(_ sender: AnyObject!) {
        if !retakePhoto() {
            delegate?.simpleCam(self, didFinishWithImage: capturedImage)
        }
    }

    @IBAction func retakeBtnPressed(_ sender: AnyObject!) {
        let _ = retakePhoto()
    }

    @IBAction func switchCameraBtnPressed(_ sender: AnyObject!) {
        if isCapturingImage { return }

        let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as! [AVCaptureDevice]
        if currentDevice == devices[0] {
            // rear active, switch to front
            currentDevice = devices[1]
        }
        else if currentDevice == devices[1] {
            // front active, switch to rear
            currentDevice = devices[0]
        }

        session.beginConfiguration()
        
        do {
            let newInput = try AVCaptureDeviceInput(device: currentDevice)
            for oldInput in (session.inputs as! [AVCaptureDeviceInput]) {
                session.removeInput(oldInput)
            }
            session.addInput(newInput)
        } catch let error {
            print("SC: ERROR: open camera: \(error.localizedDescription)")
        }
        
        session.commitConfiguration()
    }

    // MARK: TAP TO FOCUS

    @IBAction func tapSent(_ tap: UITapGestureRecognizer) {

        if capturedImageV.image != nil { return }
        guard let target = tap.view else { return }
        guard currentDevice.isFocusPointOfInterestSupported, currentDevice.isFocusModeSupported(.autoFocus) else {
            print("SC: focusPointOfInterest or auto focus not supported on current device")
            return
        }
        
        let aPoint = tap.location(in: target)
        // we subtract the point from the width to inverse the focal point
        // focus points of interest represents a CGPoint where
        // {0,0} corresponds to the top left of the picture area, and
        // {1,1} corresponds to the bottom right in landscape mode with the home button on the right—
        // THIS APPLIES EVEN IF THE DEVICE IS IN PORTRAIT MODE
        // (from docs)
        // this is all a touch wonky
        let pX = Double(aPoint.x / target.bounds.size.width)
        let pY = Double(aPoint.y / target.bounds.size.height)
        let focusX = pY
        // x is equal to y but y is equal to inverse x ?
        let focusY = 1 - pX

        //print("SC: about to focus at x: %f, y: %f", focusX, focusY);
        do {
            try currentDevice.lockForConfiguration()
            session.beginConfiguration()
            currentDevice.focusPointOfInterest = CGPoint(x: focusX, y: focusY)
            currentDevice.focusMode = .autoFocus
            currentDevice.exposurePointOfInterest = CGPoint(x: focusX, y: focusY)
            currentDevice.exposureMode = .continuousAutoExposure
            session.commitConfiguration()
            currentDevice.unlockForConfiguration()
        } catch let error {
            print("SC: ERROR: lock for camera configuration: \(error.localizedDescription)")
        }
    }

    // MARK: PINCH TO ZOOM

    @IBAction func pinchToZoom(_ pinch: UIPinchGestureRecognizer) {
        
        guard let target = pinch.view else { return }

        if pinch.state == .began {
            // Reset the recognizer scale to current view scale
            pinch.scale = currentScale
        }

        if pinch.state == .began || pinch.state == .changed {

            // Constants to adjust the max/min values of zoom
            let kMaxScale: CGFloat = 3.0
            let kMinScale: CGFloat = 1.0

            let newScale = max(min(pinch.scale, kMaxScale), kMinScale)

            target.transform = CGAffineTransform.identity.rotated(by: rotateDegree).scaledBy(x: newScale, y: newScale)
            currentScale = newScale
        }
    }

    // MARK: RESIZE IMAGE

    func calculateBounds(for src:CGSize, withTarget target:CGSize) -> CGRect {
        var result = CGRect(x: 0, y: 0, width: 0, height: 0)

        let scaleX1 = target.width
        let scaleY1 = (src.height * target.width) / src.width
        let scaleX2 = (src.width * target.height) / src.height
        let scaleY2 = target.height

        if scaleX2 > target.width {
            result.size.width = round(2.0 * scaleX1) / 2.0
            result.size.height = round(2.0 * scaleY1) / 2.0
        } else {
            result.size.width = round(2.0 * scaleX2) / 2.0
            result.size.height = round(2.0 * scaleY2) / 2.0
        }
        result.origin.x = round(target.width - result.size.width) / 2.0
        result.origin.y = round(target.height - result.size.height) / 2.0

        return result
    }

    func resizeImage() {
        
        guard let image = capturedImageV.image else { return }

        // Set Orientation
        let isLandscape = UIDevice.current.orientation.isLandscape

        // Set Size
        let size = isLandscape ? CGSize(width: screenHeight, height: screenWidth) : CGSize(width: screenWidth, height: screenHeight)

        // Set Draw Rect
        let drawRect = calculateBounds(for: image.size, withTarget: size);

        // START CONTEXT
        UIGraphicsBeginImageContextWithOptions(size, true, 2.0)
        image.draw(in: drawRect)
        capturedImageV.image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        // END CONTEXT

        // See if someone's waiting for resized image
        if isSaveWaitingForResizedImage {
            delegate?.simpleCam(self, didFinishWithImage: image)
        }

        isImageResized = true
    }

    func crop(_ img: UIImage) -> UIImage? {
        let newW = img.size.width / currentScale
        let newH = img.size.height / currentScale
        let newX1 = Int((img.size.width / 2) - (newW / 2))
        let newY1 = Int((img.size.height / 2) - (newH / 2))

        let rect = CGRect(x: -newX1, y: -newY1, width: Int(img.size.width), height: Int(img.size.height))

        UIGraphicsBeginImageContextWithOptions(CGSize(width: newW, height: newH), true, 1.0)
        img.draw(in: rect)
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return result
    }

    // MARK: ROTATION

    override public func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        if capturedImageV.image != nil {
            if !isImageResized {
                resizeImage()
            }
        }
        
        coordinator.animate(alongsideTransition: { context in
            self.rotatePreviewLayer()
            self.drawControls()
        })
    }
    
    func rotatePreviewLayer() {
        imageStreamV.transform = CGAffineTransform.identity.rotated(by: rotateDegree)
        imageStreamV.frame = view.bounds
        captureVideoPreviewLayer.frame = imageStreamV.layer.bounds
    }
    
    var rotateDegree: CGFloat {
        get {
            let orientation = UIDevice.current.orientation
            
            switch orientation {
            case .landscapeLeft:
                return -CGFloat.pi / 2
            case .landscapeRight:
                return CGFloat.pi / 2
            case .portraitUpsideDown:
                return CGFloat.pi
            default:
                return 0
            }
        }
    }
    
    // MARK: CLOSE

    public func closeWithCompletion(_ completion: @escaping () -> Void) {

        dismiss(animated: true, completion: {

            completion()

            // Clean Up
            self.isImageResized = false
            self.isSaveWaitingForResizedImage = false

            if self.session != nil {
                self.session.stopRunning()
                self.session = nil
            }

            self.capturedImage = nil
            self.capturedImageV.image = nil
            self.capturedImageV.removeFromSuperview()
            self.capturedImageV = nil

            self.imageStreamV.removeFromSuperview()
            self.imageStreamV = nil

            self.stillImageOutput = nil
            if #available(iOS 10.0, *) {
                self.photoOutput = nil
            }
            self.currentDevice = nil

            self.view = nil
            self.delegate = nil
            self.removeFromParentViewController()

        })
    }

    // MARK: STATUS BAR

    override public var prefersStatusBarHidden: Bool {
        get {return true}
    }
}

@available(iOS 10.0, *)
extension SimpleCam : AVCapturePhotoCaptureDelegate {
    public func capture(_ output: AVCapturePhotoOutput, didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?, previewPhotoSampleBuffer: CMSampleBuffer?, resolvedSettings: AVCaptureResolvedPhotoSettings, bracketSettings: AVCaptureBracketedStillImageSettings?, error: Error?) {

        if let error = error {
            print("SC: ERROR: capturing image: \(error.localizedDescription)")
            return
        }
        
        guard
            let buffer = photoSampleBuffer,
            let imageData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: buffer, previewPhotoSampleBuffer: previewPhotoSampleBuffer),
            let image = UIImage(data: imageData)
        else {
            print("SC: ERROR: capturing image: image data creation failed")
            return
        }
        
        self.processPhoto(image)
    }
}
