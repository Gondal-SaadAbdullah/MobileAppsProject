import UIKit
import AVFoundation


class QRScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    @IBOutlet var messageLabel:UILabel!
    @IBOutlet var topbar: UIView!
    @IBOutlet weak var imageViewCam: UIImageView!
    @IBOutlet weak var progressLabel: UIProgressView!
    @IBOutlet weak var recalibrateButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    var captureSession:AVCaptureSession?
    var videoPreviewLayer:AVCaptureVideoPreviewLayer?
    var qrCodeFrameView:UIView?
    
    var hasPreviousValue : Bool = false
    var calibrated : Bool = false
    var confirmCalibration : Bool = false
    var listForCalib : [CGFloat] = []
    var calibCount : Int = 0
    var allowedThreshold : Float = 7.62
    
    let widthOfPhysicalObject : Float = 19.1
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if (UserDefaults.standard.object(forKey: "focalDistance") != nil)
        {
            calibrated = true;
        }
        
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
            activityIndicator.stopAnimating()
            
            var avgSizeInPixels : Float = 0
            
            //Calculate average pixel size received from each calibration attempt
            for i in 0..<10
            {
                avgSizeInPixels += Float(listForCalib[i])
            }
            avgSizeInPixels = avgSizeInPixels / 10
            
            let focalDistance = calculateFocalDistance(avgSizeInPixels : avgSizeInPixels)
            
            //Store the calculated Focal Distance in application storage
            UserDefaults.standard.set(focalDistance, forKey: "focalDistance")
            
            let distance = calculateDistance(sizeInPixels: avgSizeInPixels)
            print ("focal distance ::::::: \(focalDistance)")
            
            //If calibration is performed at a distance greater than the allowed threshold
            //Reinitiate the calibration cycle
            if(abs(distance - 61) > allowedThreshold) {
                DispatchQueue.main.async {
                    self.resetCalibData()
                    self.displayAlertMessage(userMessage: "Please make sure you stand at the marker and reduce the device movement", heading: "Recalibrate", buttonMessage: "Continue")
                    
                }
            }
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
                if (!calibrated && confirmCalibration)
                {
                    listForCalib.append(qrCodeFrameView!.layer.bounds.width)
                    calibCount += 1
                    makeProgress()
                    
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
