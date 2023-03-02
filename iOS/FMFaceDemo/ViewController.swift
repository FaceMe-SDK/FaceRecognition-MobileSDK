//
//  ViewController.swift
//  FMFaceDemo
//
//  Created by user on 2/25/23.
//

import UIKit
import CoreData

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITableViewDataSource, UITableViewDelegate {

    @IBOutlet var lblWarning: UILabel!
    @IBOutlet weak var tableView: UITableView!
    
    var selectedIdx: Int = 0
    
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
        // Do any additional setup after loading the view.
        
        overrideUserInterfaceStyle = .dark
        
        tableView.delegate = self
        tableView.dataSource = self
               

        let menuItem1 = UIMenuItem(title: "Delete", action: #selector(doDeleteUser))
        let menuItem2 = UIMenuItem(title: "Delete All", action: #selector(doDeleteAll))
                
        let menuController = UIMenuController.shared
        menuController.menuItems = [menuItem1, menuItem2]
        
        menuController.setTargetRect(tableView.bounds, in: self.tableView)
        menuController.setMenuVisible(true, animated: true)

        guard let filePath = Bundle.main.path(forResource: "license", ofType: "skm") else {
            // Handle file not found error
            return
        }
        
        var license = ""
        do {
            license = try String(contentsOfFile: filePath, encoding: .utf8)
        } catch {
            // Handle file read error
        }
        
        FaceSDK.createInstance()
        let ret = FaceSDK.getInstance().initSDK(license)
        let enumValue = SDK_INIT_RESULT(rawValue: UInt32(ret))
        if(enumValue != SDK_SUCCESS) {
            self.lblWarning.isHidden = false
            
            if(enumValue == SDK_ACTIVATE_APPID_ERROR) {
                self.lblWarning.text = NSLocalizedString("appid_error", comment: "")
            } else if(enumValue == SDK_ACTIVATE_INVALID_LICENSE) {
                self.lblWarning.text = NSLocalizedString("invalid_license", comment: "")
            } else if(enumValue == SDK_ACTIVATE_LICENSE_EXPIRED) {
                self.lblWarning.text = NSLocalizedString("license_expired", comment: "")
            } else if(enumValue == SDK_NO_ACTIVATED) {
                self.lblWarning.text = NSLocalizedString("no_activated", comment: "")
            } else if(enumValue == SDK_INIT_ERROR) {
                self.lblWarning.text = NSLocalizedString("init_error", comment: "")
            }
        }
    }

    @IBAction func btnAddClicked(_ sender: Any) {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .photoLibrary
        imagePicker.delegate = self
        present(imagePicker, animated: true, completion: nil)
    }
    
    
    @IBAction func btnVerifyClicked(_ sender: Any) {
        performSegue(withIdentifier: "showCamera", sender: self)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
    
        dismiss(animated: true, completion: nil)

        guard let image = info[.originalImage] as? UIImage else {
            return
        }

        let fixed_image = image.fixOrientation()
        let faceBoxes:NSMutableArray = FaceSDK.getInstance().detectFace(fixed_image)
        let faceCount = faceBoxes.count
                
        if(faceCount == 1) {
            let face = faceBoxes[0] as! FaceBox
            let livenessScore = FaceSDK.getInstance().checkLiveness(fixed_image, faceBox: face)
            
            if(livenessScore > CameraViewController.LIVENESS_THRESHOLD) {
                let featData = FaceSDK.getInstance().extractFeature(fixed_image, faceBox: face)
                
                let cropRect = Utils.getBestRect(frameWidth: fixed_image.size.width, frameHeight: fixed_image.size.height, face: face)
                guard let croppedImage = fixed_image.cgImage!.cropping(to: cropRect) else { return }

                // Create the alert controller
                let alertController = UIAlertController(title: NSLocalizedString("register", comment: ""), message: nil, preferredStyle: .alert)
                alertController.overrideUserInterfaceStyle = .dark

                guard let addUserVC = storyboard?.instantiateViewController(withIdentifier: "AddUserViewController") as? AddUserViewController else {
                    return
                }

                let faceImage = UIImage(cgImage: croppedImage)
                let resizedImage = Utils.resizeImage(image: faceImage, newSize: CGSize(width: 120, height: 120))
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
                        
                        if(text.isEmpty) {
                            Utils.showToast(controller: self, message: NSLocalizedString("please_input_name", comment: ""), seconds: 1, color:.red)
                            return
                        }
                        
                                                
                        let context = self.persistentContainer.viewContext
                        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: UserDB.USERS_ENTITY)
                        fetchRequest.predicate = NSPredicate(format: "userName = %@", text)

                        do {
                            let results = try context.fetch(fetchRequest)
                            if let item = results.first as? NSManagedObject {
                                Utils.showToast(controller: self, message: NSLocalizedString("duplicated_name", comment: ""), seconds: 1, color:.red)
                                
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
                        
                        self.tableView.reloadData()
                        
                        Utils.showToast(controller: self, message: NSLocalizedString("register_successed", comment: ""), seconds: 1, color:.green)

                    }
                }

                // Create the Cancel action
                let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (action:UIAlertAction!) in
                    // Handle Cancel button tap
                }

                // Add the actions to the alert controller
                alertController.addAction(okAction)
                alertController.addAction(cancelAction)

                // Present the alert controller
                self.present(alertController, animated: true, completion:nil)
            } else {
                //liveness check failed
                Utils.showToast(controller: self, message: NSLocalizedString("liveness_check_failed", comment: ""), seconds: 1, color:.red)
            }
        } else if(faceCount == 0) {
            Utils.showToast(controller: self, message: NSLocalizedString("no_face_detected", comment: ""), seconds: 1, color:.red)
        } else {
            Utils.showToast(controller: self, message: NSLocalizedString("multiple_face_detected", comment: ""), seconds: 1, color:.red)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    // UITableViewDataSource methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Return the number of cells in the table view
        
        let context = self.persistentContainer.viewContext
        let count = try! context.count(for: NSFetchRequest(entityName: UserDB.USERS_ENTITY))
        
        return count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Get the table view cell for the specified index path
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! UserViewCell

        let context = self.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: UserDB.USERS_ENTITY)
        do {
            let users = try context.fetch(fetchRequest) as! [NSManagedObject]
            var rowCount = 0
            for user in users {
                if(rowCount == indexPath.row) {
                    cell.lblUserName.text = user.value(forKey: UserDB.USER_NAME) as? String
                    cell.faceImageView.image = UIImage(data: user.value(forKey: UserDB.FACE_DATA) as! Data)
                    
                    break
                }
                rowCount = rowCount + 1
            }
        } catch {
            print("Failed fetching: \(error)")
        }
        
        // Customize the cell
        return cell
    }

    // UITableViewDelegate methods
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Handle cell selection
        tableView.deselectRow(at: indexPath, animated: true)
        
        selectedIdx = indexPath.row
        
        // Show the menu controller for the selected cell
        let cellRect = tableView.rectForRow(at: indexPath)
        let menuController = UIMenuController.shared
        menuController.showMenu(from: tableView, rect: cellRect)
    }
    
    @objc func doDeleteUser() {
//        print(sender.value(forKey: "sel_idx") as! Int)
        print("sender: ", selectedIdx)
        
        let context = self.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: UserDB.USERS_ENTITY)

        do {
            let users = try context.fetch(fetchRequest) as! [NSManagedObject]
            var rowCount = 0
            for user in users {
                if(rowCount == selectedIdx) {
                    context.delete(user)
                    try context.save()
                    break
                }
                rowCount = rowCount + 1
            }
        } catch {
            print("Failed fetching: \(error)")
        }
        
        self.tableView.reloadData()
    }
    
    @objc func doDeleteAll() {
        
        let context = self.persistentContainer.viewContext
        let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: UserDB.USERS_ENTITY)

        do {
            let users = try context.fetch(fetchRequest) as! [NSManagedObject]
            for user in users {
                context.delete(user)
            }
            try context.save()
        } catch {
            print("Failed fetching: \(error)")
        }
        
        self.tableView.reloadData()
    }
    
    func onCameraEnd(msg: String) {
        self.tableView.reloadData()
        Utils.showToast(controller: self, message: msg, seconds: 1, color:.green)
    }

}



