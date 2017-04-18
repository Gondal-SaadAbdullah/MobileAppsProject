//
//  QRScannerController.swift
//  QRCodeReader
//
//  Created by Simon Ng on 13/10/2016.
//  Copyright © 2016 AppCoda. All rights reserved.
//

import UIKit
import AVFoundation
import MapKit
import CoreLocation

class QRScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate, CLLocationManagerDelegate {

    @IBOutlet var messageLabel:UILabel!
    @IBOutlet var topbar: UIView!
    
    var captureSession:AVCaptureSession?
    var videoPreviewLayer:AVCaptureVideoPreviewLayer?
    var qrCodeFrameView:UIView?
    
    let locationManager = CLLocationManager()
    
    var coveredPaths = [String: Int]()
    var longitude : [CLLocationDegrees] = []
    var latitude : [CLLocationDegrees] = []
    var count : Int = 0
    var hasPreviousValue : Bool = false
    var longiTemp : CLLocationDegrees = 0.0
    var latiTemp : CLLocationDegrees = 0.0
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if (UserDefaults.standard.object(forKey: "focalDistance") != nil)
        {
            calibrated = true;
        }

        // Setting Pixel Width for iPad Air 1
        defaultFocalPoints[UserDefaults.standard.string(forKey: "modelName")!] = 456
        
        // Get an instance of the AVCaptureDevice class to initialize a device object and provide the video as the media type parameter.
        let captureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        
        if(!calibrated)
        {
         DispatchQueue.main.async {
            self.displayMyAlertMessage(userMessage: "Please place the device at the marker and scan the QR code", heading: "Device not calibrated", buttonMessage : "Continue")
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
//            recalibrateButton.center = view.center
            
            //imageViewCam.layer.addSublayer(videoPreviewLayer!)
            
            // Start video capture.
            captureSession?.startRunning()
            
            // Move the message label and top bar to the front
            view.bringSubview(toFront: messageLabel)
            view.bringSubview(toFront: topbar)
            
            
            
            //if (!calibrated && self.confirmCalibration)
           // {
                // Initialize QR Code Frame to highlight the QR code
                qrCodeFrameView = UIView()
                
                if let qrCodeFrameView = qrCodeFrameView {
                    
                    qrCodeFrameView.layer.borderColor = UIColor.green.cgColor
                    qrCodeFrameView.layer.borderWidth = 2
                    
                    view.addSubview(qrCodeFrameView)
                    view.bringSubview(toFront: qrCodeFrameView)
                    //self.messageLabel.text = "height is :: \(qrCodeFrameView.layer.bounds.height)"
                }
          //  }
            
            
        } catch {
            // If any error occurs, simply print it out and don't continue any more.
            print(error)
            return
        }
    }
    
    @IBAction func performRecalibration(_ sender: Any) {
        
        self.calibrated = false
        self.progressLabel.setProgress(0, animated: true)
        self.calibCount = 0
        self.listForCalib.removeAll()
        
        DispatchQueue.main.async {
            self.displayMyAlertMessage(userMessage: "Please place the device at the marker and scan the QR code", heading: "Start Calibration", buttonMessage : "Continue")
        }
    }
    
    func displayMyAlertMessage(userMessage : String, heading : String, buttonMessage : String)
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
    
    
    func updatingLocation()
    {
        // Ask for Authorisation from the User.
        self.locationManager.requestAlwaysAuthorization()
        
        // For use in foreground
        self.locationManager.requestWhenInUseAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.startUpdatingLocation()
        }
    }
    
    func makeProgress()
    {
        progressLabel.setProgress(Float(calibCount/10), animated: true)
        
        if(calibCount == 10)
        {
            calibrated = true
            var avgSizeInPixels : Float = 0
            
            for i in 0..<10
                {
                avgSizeInPixels += Float(listForCalib[i])
            }
            avgSizeInPixels = avgSizeInPixels / 10
            
            let pixelWidth : Float = defaultFocalPoints[UserDefaults.standard.string(forKey: "modelName")!]!
            
            if(abs(avgSizeInPixels - pixelWidth) > 90)
            {
                DispatchQueue.main.async {
                    self.calibrated = false
                    self.progressLabel.setProgress(0, animated: true)
                    self.calibCount = 0
                    self.listForCalib.removeAll()
                    self.displayMyAlertMessage(userMessage: "Please make sure you stand at the marker and reduce the device movement", heading: "Recalibrate", buttonMessage: "Continue")
                    
                }
            }
            
            let focalDistance = calculateFocalDistance(avgSizeInPixels : avgSizeInPixels)
            UserDefaults.standard.set(focalDistance, forKey: "focalDistance")
        }
    }
    
    func calculateDistance(sizeInPixels : Float) -> Float
    {
        let focalDistance = UserDefaults.standard.float(forKey: "focalDistance")
        return (widthOfPhysicalObject * focalDistance)/sizeInPixels
    }
    
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
        
        // Check if the metadataObjects array is not nil and it contains at least one object.
        if metadataObjects == nil || metadataObjects.count == 0 {
            qrCodeFrameView?.frame = CGRect.zero
            messageLabel.text = "No QR code is detected"
            return
        }
        
        
        // Get the metadata object.
        let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
        
        if metadataObj.type == AVMetadataObjectTypeQRCode {
            
            // If the found metadata is equal to the QR code metadata then update the status label's text and set the bounds
            let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObj)
            qrCodeFrameView?.frame = barCodeObject!.bounds
            
            if metadataObj.stringValue != nil {
                messageLabel.text = metadataObj.stringValue
                
                
                if (!calibrated && calibCount <= 10 && confirmCalibration)
                {
                    listForCalib.append(qrCodeFrameView!.layer.bounds.width)
                    calibCount += 1
                    makeProgress()
                    
                }
                if calibCount == 10
                {
                    activityIndicator.stopAnimating()
                    calibrated = true
                }
                
                if(calibrated)
                {
                    messageLabel.text = ">> \(calculateDistance(sizeInPixels : Float(qrCodeFrameView!.layer.bounds.width)))"
                }
                
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        let locValue:CLLocationCoordinate2D = manager.location!.coordinate
        longitude.append(locValue.longitude)
        latitude.append(locValue.latitude)
        
        latiTemp = locValue.latitude;
        longiTemp = locValue.longitude;
        
        messageLabel.text = "locations = \(locValue.longitude), \(locValue.latitude), course = \(manager.location!.course)"
        
        showLocationDiff()
    }
    
    func showLocationDiff()
    {
        //messageLabel.text = "locations = \(longitude[longitude.count] - longitude[longitude.count - 1])"
        if(longitude.count > 1)
        {
            print("longitude = \((longitude[longitude.count - 1] - longitude[longitude.count - 2]) * 10000), latitude = \((latitude[latitude.count - 1] - latitude[latitude.count - 2]) * 10000)")
        }
        
        
        
    }
    
    

}
