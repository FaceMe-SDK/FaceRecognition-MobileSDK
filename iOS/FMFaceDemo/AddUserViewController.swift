//
//  AddUserViewController.swift
//  FMFaceDemo
//
//  Created by user on 3/1/23.
//

import UIKit

class AddUserViewController: UIViewController {

    
    @IBOutlet weak var imageView: UIImageView!
    
    var image: UIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        imageView.image = image
    }
    
    override func viewDidLayoutSubviews() {
        preferredContentSize.height = imageView.frame.height + 20
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
