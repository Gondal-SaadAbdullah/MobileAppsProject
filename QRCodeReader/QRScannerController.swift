import UIKit
import AVFoundation


class QRScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    @IBOutlet var messageLabel:UILabel!
    @IBOutlet var topbar: UIView!
    
    var captureSession:AVCaptureSession?
    var videoPreviewLayer:AVCaptureVideoPreviewLayer?
    var qrCodeFrameView:UIView?
    
    var coveredPaths = [String: Int]()
    
    var count : Int = 0
    var hasPreviousValue : Bool = false
    @IBOutlet weak var imageViewCam: UIImageView!
    var calibrated : Bool = false
    @IBOutlet weak var progressLabel: UIProgressView!
    var confirmCalibration : Bool = false
    var listForCalib : [CGFloat] = []
    var calibCount : Int = 0
    var defaultFocalPoints = [String: Float]()
    
    @IBOutlet weak var recalibrateButton: UIButton!
    let widthOfPhysicalObject : Float = 19.5
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var modelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        
        switch identifier {
        case "iPod5,1":                                 return "iPod Touch 5"
        case "iPod7,1":                                 return "iPod Touch 6"
        case "iPhone3,1", "iPhone3,2", "iPhone3,3":     return "iPhone 4"
        case "iPhone4,1":                               return "iPhone 4s"
        case "iPhone5,1", "iPhone5,2":                  return "iPhone 5"
        case "iPhone5,3", "iPhone5,4":                  return "iPhone 5c"
        case "iPhone6,1", "iPhone6,2":                  return "iPhone 5s"
        case "iPhone7,2":                               return "iPhone 6"
        case "iPhone7,1":                               return "iPhone 6 Plus"
        case "iPhone8,1":                               return "iPhone 6s"
        case "iPhone8,2":                               return "iPhone 6s Plus"
        case "iPhone9,1", "iPhone9,3":                  return "iPhone 7"
        case "iPhone9,2", "iPhone9,4":                  return "iPhone 7 Plus"
        case "iPhone8,4":                               return "iPhone SE"
        case "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4":return "iPad 2"
        case "iPad3,1", "iPad3,2", "iPad3,3":           return "iPad 3"
        case "iPad3,4", "iPad3,5", "iPad3,6":           return "iPad 4"
        case "iPad4,1", "iPad4,2", "iPad4,3":           return "iPad Air"
        case "iPad5,3", "iPad5,4":                      return "iPad Air 2"
        case "iPad2,5", "iPad2,6", "iPad2,7":           return "iPad Mini"
        case "iPad4,4", "iPad4,5", "iPad4,6":           return "iPad Mini 2"
        case "iPad4,7", "iPad4,8", "iPad4,9":           return "iPad Mini 3"
        case "iPad5,1", "iPad5,2":                      return "iPad Mini 4"
        case "iPad6,3", "iPad6,4", "iPad6,7", "iPad6,8":return "iPad Pro"
        case "AppleTV5,3":                              return "Apple TV"
        case "i386", "x86_64":                          return "Simulator"
        default:                                        return identifier
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if (UserDefaults.standard.object(forKey: "focalDistance") != nil)
        {
            calibrated = true;
        }
        
        // Setting Pixel Width for iPad Air 1
        defaultFocalPoints[modelName] = 456
        
        // Get an instance of the AVCaptureDevice class to initialize a device object and provide the video as the media type parameter.
        let captureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        
        if(!calibrated)
        {
            DispatchQueue.main.async {
                self.displayAlertMessage(userMessage: "Please place the device at the marker and scan the QR code", heading: "Device not calibrated", buttonMessage : "Continue")
            }
        }
        
        do {
            // Get an instance of the AVCaptureDeviceInput class using the previous device object.
            let input = try AVCaptureDeviceInput(device: captureDevice)
            
            // Initialize the captureSession object.
            captureSession = AVCaptureSession()
            
            // Set the input device on the capture session.
            captureSession?.addInput(input)
            
            // Initialize a AVCaptureMetadataOutput object and set it as the output device to the capture session.
            let captureMetadataOutput = AVCaptureMetadataOutput()
            captureSession?.addOutput(captureMetadataOutput)
            
            // Set delegate and use the default dispatch queue to execute the call back
            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            captureMetadataOutput.metadataObjectTypes = [AVMetadataObjectTypeQRCode]
            
            // Initialize the video preview layer and add it as a sublayer to the viewPreview view's layer.
            videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            videoPreviewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
            videoPreviewLayer?.frame = view.layer.bounds
            view.layer.addSublayer(videoPreviewLayer!)
            view.layer.addSublayer(activityIndicator.layer)
            view.layer.addSublayer(progressLabel.layer)
            activityIndicator.center = view.center
            progressLabel.layer.frame.size.width = view.layer.bounds.width
            
            
            // Start video capture.
            captureSession?.startRunning()
            
            // Move the message label and top bar to the front
            view.bringSubview(toFront: messageLabel)
            view.bringSubview(toFront: topbar)
            
            // Initialize QR Code Frame to highlight the QR code
            qrCodeFrameView = UIView()
            
            if let qrCodeFrameView = qrCodeFrameView {
                
                qrCodeFrameView.layer.borderColor = UIColor.green.cgColor
                qrCodeFrameView.layer.borderWidth = 2
                
                view.addSubview(qrCodeFrameView)
                view.bringSubview(toFront: qrCodeFrameView)
            }
            
        } catch {
            // If any error occurs, simply print it out and don't continue any more.
            print(error)
            return
        }
    }
    
    @IBAction func performRecalibration(_ sender: Any) {
        
        self.resetCalibData()
        
        DispatchQueue.main.async {
            self.displayAlertMessage(userMessage: "Please place the device at the marker and scan the QR code", heading: "Start Calibration", buttonMessage : "Continue")
        }
    }
    
    func displayAlertMessage(userMessage : String, heading : String, buttonMessage : String)
    {
        let myAlert = UIAlertController(title: heading, message: userMessage, preferredStyle: UIAlertControllerStyle.alert);
        let okAction = UIAlertAction(title: buttonMessage, style: UIAlertActionStyle.default, handler: doSomething);
        
        myAlert.addAction(okAction)
        self.present(myAlert, animated: true, completion: nil);
    }
    
    func doSomething(action: UIAlertAction) {
        self.confirmCalibration = true
        activityIndicator.startAnimating()
    }
    
    func makeProgress()
    {
        progressLabel.setProgress(Float(calibCount/10), animated: true)
        
        //When maximum calibration attempts are achieved
        if(calibCount == 10)
        {
            calibrated = true
            var avgSizeInPixels : Float = 0
            
            //Calculate average pixel size received from each calibration attempt
            for i in 0..<10
            {
                avgSizeInPixels += Float(listForCalib[i])
            }
            avgSizeInPixels = avgSizeInPixels / 10
            
            let pixelWidth : Float = defaultFocalPoints[modelName]!
            
            //If calibration is performed at a distance greater than the allowed threshold
            //Reinitiate the calibration cycle
            if(abs(avgSizeInPixels - pixelWidth) > 90) {
                DispatchQueue.main.async {
                    self.resetCalibData()
                    self.displayAlertMessage(userMessage: "Please make sure you stand at the marker and reduce the device movement", heading: "Recalibrate", buttonMessage: "Continue")
                    
                }
            }
            
            let focalDistance = calculateFocalDistance(avgSizeInPixels : avgSizeInPixels)
            print ("focal distance ::::::: \(focalDistance)")
            
            //Successful calibration - store Focal Distance in application storage
            UserDefaults.standard.set(focalDistance, forKey: "focalDistance")
        }
    }
    
    func resetCalibData()
    {
        self.calibrated = false
        self.progressLabel.setProgress(0, animated: true)
        self.calibCount = 0
        self.listForCalib.removeAll()
    }
    
    //Distance calculation
    func calculateDistance(sizeInPixels : Float) -> Float
    {
        let focalDistance = UserDefaults.standard.float(forKey: "focalDistance")
        return (widthOfPhysicalObject * focalDistance)/sizeInPixels
    }
    
    //Focal distance calculation
    func calculateFocalDistance(avgSizeInPixels : Float) -> Float
    {
        let calibrationDistance : Float = 61
        let focalDistance : Float = (avgSizeInPixels * calibrationDistance) / widthOfPhysicalObject
        
        return focalDistance
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [Any]!, from connection: AVCaptureConnection!) {
        
        // Check if QRCode is detected - if not end processing for this callback
        if metadataObjects == nil || metadataObjects.count == 0 {
            qrCodeFrameView?.frame = CGRect.zero
            messageLabel.text = "No QR code is detected"
            return
        }
        
        let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
        
        if metadataObj.type == AVMetadataObjectTypeQRCode {
            
            let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObj)
            qrCodeFrameView?.frame = barCodeObject!.bounds
            
            //If a QRCode is read with a string value
            if metadataObj.stringValue != nil {
                
                //If in calibration process
                if (!calibrated && calibCount <= 10 && confirmCalibration)
                {
                    listForCalib.append(qrCodeFrameView!.layer.bounds.width)
                    calibCount += 1
                    makeProgress()
                    
                }
                
                //If maximum calibration attempts are achieved
                if calibCount == 10
                {
                    activityIndicator.stopAnimating()
                    calibrated = true
                }
                
                //If calibrated report distance from the detected QRCode
                if(calibrated)
                {
                    messageLabel.text = "\(calculateDistance(sizeInPixels : Float(qrCodeFrameView!.layer.bounds.width)) / 100) meters from \(metadataObj.stringValue!)"
                }
                
            }
        }
    }
}
