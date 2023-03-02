//
//  BoundingBoxOverlay.swift
//  FMFaceDemo
//
//  Created by user on 2/28/23.
//

import UIKit

class BoundingBoxOverlay: UIView {

    var faceBoxes: NSMutableArray? = nil
    var frameSize: CGSize?
    var recogScore_: Float = 0.0
    var livenessResult: Int = 0

    
    public func setFrameRect(frameSize: CGSize) {
        self.frameSize = frameSize
    }
    
    public func setFaceBoxes(faceBoxes: NSMutableArray) {
        self.faceBoxes = faceBoxes
        setNeedsDisplay()
    }

    
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }

        if(self.frameSize != nil) {
            context.beginPath()
            
            var color = UIColor.green
            if(self.livenessResult == 1) {
                color = UIColor.green
            } else if(self.livenessResult == 0) {
                color = UIColor.red
            } else if(self.livenessResult == 2) {
                color = UIColor.yellow
            }
            
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(3.0)

            for face in (faceBoxes! as NSArray as! [FaceBox]) {
                let faceRect = CGRect(x: Int(face.left), y: Int(face.top), width: Int(face.right - face.left + 1), height: Int(face.bottom - face.top + 1))
                
                let transform1 = CGAffineTransform(scaleX: self.bounds.width / self.frameSize!.width, y: self.bounds.height / self.frameSize!.height)

                let scaledRect = faceRect.applying(transform1)
                let facePath = UIBezierPath(roundedRect: scaledRect, cornerRadius: 10)
                context.addPath(facePath.cgPath)

                if(self.livenessResult != 2) {
                    var title = "REAL"
                    if(self.livenessResult == 0) {
                        title = "SPOOF"
                    }
                    
                    let attributes = [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 20),
                                      NSAttributedString.Key.foregroundColor: color]
                    
                    title.draw(at: CGPoint(x: CGFloat(scaledRect.minX + 10), y: CGFloat(scaledRect.minY - 25)), withAttributes: attributes)

                }
                
                context.strokePath()
            }
        }
    }
}
