//
//  Utils.swift
//  FMFaceDemo
//
//  Created by user on 3/1/23.
//

import Foundation

class Utils {
    
    static func getBestRect(frameWidth: CGFloat, frameHeight: CGFloat, face: FaceBox) -> CGRect {
        
        let padding = CGFloat(face.right - face.left + 1) / 4
        print("face: ", face.left, face.top, face.right, face.bottom, padding)

        let left = max(CGFloat(face.left) - padding, CGFloat(0))
        let top = max(CGFloat(face.top) - padding, CGFloat(0))
        let right = min(CGFloat(face.right) + padding, frameWidth - 1)
        let bottom = min(CGFloat(face.bottom) + padding, frameHeight - 1)
        let faceRect = CGRect(x: CGFloat(left), y: CGFloat(top), width: CGFloat(right - left + 1), height: CGFloat(bottom - top + 1))

        return faceRect
    }
    
    static func resizeImage(image: UIImage, newSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let newImage = renderer.image { (context) in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return newImage
    }
    
    static func showToast(controller: UIViewController, message : String, seconds: Double, color: UIColor) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.view.backgroundColor = color
        alert.view.layer.cornerRadius = 15
        controller.present(alert, animated: true)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + seconds) {
            alert.dismiss(animated: true)
        }
    }
}
