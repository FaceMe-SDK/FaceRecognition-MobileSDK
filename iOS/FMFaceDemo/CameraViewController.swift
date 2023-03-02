//
//  CameraViewController.swift
//  FMFaceDemo
//
//  Created by user on 2/25/23.
//

import UIKit
import AVFoundation
import CoreData

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate{
    
    
    @IBOutlet weak var lblMessage: UILabel!
    @IBOutlet weak var imageViewIcon: UIImageView!
    @IBOutlet weak var lblFaceMe: UILabel!
    @IBOutlet weak var btnAdd: UIButton!
    
    static let VERIFY_TIMEOUT = CGFloat(5000)
    static let LIVENESS_THRESHOLD = Float(0.5)
    static let RECOGNIZE_THRESHOLD = Float(0.78)
    
    var curSession: AVCaptureSession? = nil
    let captureSession = AVCaptureSession()
    var previewLayer: AVCaptureVideoPreviewLayer!
    var videoDataOutput: AVCaptureVideoDataOutput!
    let videoQueue = DispatchQueue(label: "videoQueue", qos: .userInteractive)

    enum PROC_MODE {
        case VERIFY
        case REGISTER
    }
        
    var mode = PROC_MODE.VERIFY
    var isProcessing = false
    var startVerifyTime: Date? = nil
    var frameCount: Int = 0

    let boudingBoxOverlay = BoundingBoxOverlay()
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: UserDB.CORE_DATA_NAME)
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up the preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        view.addSubview(self.boudingBoxOverlay)

        view.layer.addSublayer(lblMessage.layer)
        view.layer.addSublayer(lblFaceMe.layer)
        view.layer.addSublayer(btnAdd.layer)
        view.layer.addSublayer(imageViewIcon.layer)
        
        self.boudingBoxOverlay.backgroundColor = UIColor.clear
        self.boudingBoxOverlay.translatesAutoresizingMaskIntoConstraints = false
        self.boudingBoxOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        self.boudingBoxOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        self.boudingBoxOverlay.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        self.boudingBoxOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true

        self.lblMessage.alpha = 0
        startCaptureSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.captureSession.stopRunning()
    }
    
    func startCaptureSession() {
        
        captureSession.beginConfiguration()

        // Add the video device input
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else { return }
        guard let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }

        // Add the video data output
        let videoDataOutput = AVCaptureVideoDataOutput()
        let videoQueue = DispatchQueue(label: "videoQueue", qos: .userInteractive)
        videoDataOutput.setSampleBufferDelegate(self, queue: videoQueue)
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }

        // Configure the video orientation
        if let videoConnection = videoDataOutput.connection(with: .video) {
            videoConnection.videoOrientation = .portrait
        }

        captureSession.commitConfiguration()
        captureSession.startRunning()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Update the frame of the preview layer
        previewLayer.frame = view.bounds
    }
        
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        if(isProcessing == true) {
            return
        }
        
        isProcessing = true
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(CGImagePropertyOrientation.upMirrored)
        
        let context = CIContext()
        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)
        let image = UIImage(cgImage: cgImage!)
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags.readOnly)

        let faceBoxes:NSMutableArray = FaceSDK.getInstance().detectFace(image)
        
        frameCount = frameCount + 1
        if(frameCount == 1) {
            isProcessing = false
            return
        }
        
        if(faceBoxes.count == 1) {
            

            hideMessage()

            let face = faceBoxes[0] as! FaceBox

            let livenessScore = FaceSDK.getInstance().checkLiveness(image, faceBox: face)
            if(livenessScore > CameraViewController.LIVENESS_THRESHOLD) {
                self.boudingBoxOverlay.livenessResult = 1

                let featData = FaceSDK.getInstance().extractFeature(image, faceBox: face)

                if(mode == PROC_MODE.REGISTER) {
                    
                    DispatchQueue.main.async {
                        let cropRect = Utils.getBestRect(frameWidth: image.size.width, frameHeight: image.size.height, face: face)
                        
                        guard let croppedImage = image.cgImage!.cropping(to: cropRect) else {
                            self.isProcessing = false
                            return
                        }
                        
                        // Create the alert controller
                        let alertController = UIAlertController(title: NSLocalizedString("register", comment: ""), message: nil, preferredStyle: .alert)
                        alertController.overrideUserInterfaceStyle = .dark
                        
                        guard let addUserVC =  self.storyboard?.instantiateViewController(withIdentifier: "AddUserViewController") as? AddUserViewController else {
                            self.isProcessing = false
                            return
                        }
                        
                        let faceImage = UIImage(cgImage: croppedImage)
                        //                        let resizedImage = Utils.resizeImage(image: faceImage, newSize: CGSize(width: 120, height: 120))
                        let resizedImage = faceImage
                        let imageData = resizedImage.jpegData(compressionQuality: CGFloat(1.0))
                        
                        addUserVC.image = resizedImage
                        alertController.setValue(addUserVC, forKey: "contentViewController")
                        alertController.addTextField { (textField) in
                            textField.placeholder = NSLocalizedString("name", comment: "")
                            
                            let context = self.persistentContainer.viewContext
                            let count = try! context.count(for: NSFetchRequest(entityName: UserDB.USERS_ENTITY))
                            textField.text = "User" + String(count + 1)
                        }
                        
                        // Create the OK action
                        let okAction = UIAlertAction(title: "OK", style: .default) { (action:UIAlertAction!) in
                            // Handle OK button tap
                            if let textField = alertController.textFields?.first, let text = textField.text {
                                print("Text entered: \(text)")
                                
                                if(text.isEmpty) {
                                    Utils.showToast(controller: self, message: NSLocalizedString("please_input_name", comment: ""), seconds: 1, color:.red)
                                    self.isProcessing = false
                                    return
                                }
                                
                                
                                let context = self.persistentContainer.viewContext
                                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: UserDB.USERS_ENTITY)
                                fetchRequest.predicate = NSPredicate(format: "userName = %@", text)
                                
                                do {
                                    let results = try context.fetch(fetchRequest)
                                    if let item = results.first as? NSManagedObject {
                                        Utils.showToast(controller: self, message: NSLocalizedString("duplicated_name", comment: ""), seconds: 1, color:.red)
                                        
                                        self.isProcessing = false
                                        return
                                    }
                                } catch let error as NSError {
                                    print("Error deleting item: \(error), \(error.userInfo)")
                                }
                                
                                
                                let entity = NSEntityDescription.entity(forEntityName: UserDB.USERS_ENTITY, in: context)!
                                let user = NSManagedObject(entity: entity, insertInto: context)
                                
                                user.setValue(text, forKey: UserDB.USER_NAME)
                                user.setValue(featData, forKey: UserDB.FEAT_DATA)
                                user.setValue(imageData, forKey: UserDB.FACE_DATA)
                                
                                do {
                                    try context.save()
                                } catch let error as NSError {
                                    print("Could not save. \(error), \(error.userInfo)")
                                }
                                
                                if let vc = self.presentingViewController as? ViewController {
                                    self.dismiss(animated: true, completion: {
                                        vc.onCameraEnd(msg: NSLocalizedString("register_successed", comment: ""))
                                    })
                                }
                            }
                        }

                        // Create the Cancel action
                        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (action:UIAlertAction!) in
                            // Handle Cancel button tap
                            self.isProcessing = false
                        }
                        
                        // Add the actions to the alert controller
                        alertController.addAction(okAction)
                        alertController.addAction(cancelAction)
                        
                        // Present the alert controller
                        self.present(alertController, animated: true, completion:nil)
                        self.mode = PROC_MODE.VERIFY
                    }
                } else {
                    
                    var maxScore = Float(0)
                    var maxScoreName = ""
                    
                    let context = self.persistentContainer.viewContext
                    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: UserDB.USERS_ENTITY)

                    do {
                        let users = try context.fetch(fetchRequest) as! [NSManagedObject]
                        for user in users {
                            let score = FaceSDK.getInstance().compareFeature(user.value(forKey: UserDB.FEAT_DATA) as! Data, feature2: featData)
                            if(maxScore < score) {
                                maxScore = score
                                maxScoreName = user.value(forKey: UserDB.USER_NAME) as! String
                            }
                        }
                    } catch {
                        print("Failed fetching: \(error)")
                    }

                    if(maxScore > CameraViewController.RECOGNIZE_THRESHOLD) {

                        DispatchQueue.main.async {
                            self.boudingBoxOverlay.setFrameRect(frameSize: image.size)
                            self.boudingBoxOverlay.setFaceBoxes(faceBoxes: faceBoxes)

                            if let vc = self.presentingViewController as? ViewController {
                                self.dismiss(animated: true, completion: {
                                    vc.onCameraEnd(msg: NSLocalizedString("verify_succeed", comment: "") + " " + maxScoreName)
                                })
                            }
                        }
                        
                        return
                    } else {
                        self.isProcessing = false
                    }
                }
            } else {
                self.boudingBoxOverlay.livenessResult = 0
                self.isProcessing = false
            }
        } else if(faceBoxes.count > 1) {
            showMessage(msg: NSLocalizedString("multiple_face_detected", comment: ""))
            self.boudingBoxOverlay.livenessResult = 2
            self.isProcessing = false
        } else {
            
            if(mode == PROC_MODE.REGISTER) {
                showMessage(msg: NSLocalizedString("no_face_detected", comment: ""))
            }
            
            self.isProcessing = false
        }
        
        DispatchQueue.main.async {
            self.boudingBoxOverlay.setFrameRect(frameSize: image.size)
            self.boudingBoxOverlay.setFaceBoxes(faceBoxes: faceBoxes)
        }

        
        if(self.mode == PROC_MODE.VERIFY) {
            if(startVerifyTime == nil) {
                startVerifyTime = Date()
            }

            if(Date().timeIntervalSince(startVerifyTime!) * 1000 > CameraViewController.VERIFY_TIMEOUT) {
                DispatchQueue.main.async {
                    if(faceBoxes.count == 0) {
                        if let vc = self.presentingViewController as? ViewController {
                            self.dismiss(animated: true, completion: {
                                vc.onCameraEnd(msg: NSLocalizedString("verify_timeout", comment: ""))
                            })
                        }
                    } else if(self.boudingBoxOverlay.livenessResult == 0) {
                        if let vc = self.presentingViewController as? ViewController {
                            self.dismiss(animated: true, completion: {
                                vc.onCameraEnd(msg: NSLocalizedString("liveness_check_failed", comment: ""))
                            })
                        }
                    } else {
                        if let vc = self.presentingViewController as? ViewController {
                            self.dismiss(animated: true, completion: {
                                vc.onCameraEnd(msg: NSLocalizedString("verify_failed", comment: ""))
                            })
                        }
                    }
                }
            }
        }
    }
    
    
    @IBAction func btnAddUserClick(_ sender: Any) {
        self.mode = PROC_MODE.REGISTER
    }
    
    func showMessage(msg: String) {
        DispatchQueue.main.async {
            self.lblMessage.alpha = 1.0
            self.lblMessage.text = msg
        }
    }
    
    func hideMessage() {
        DispatchQueue.main.async {
            self.lblMessage.alpha = 0
        }
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
