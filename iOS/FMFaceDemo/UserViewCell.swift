//
//  UserViewCell.swift
//  FMFaceDemo
//
//  Created by user on 3/1/23.
//

import UIKit

class UserViewCell: UITableViewCell {
        
    @IBOutlet weak var faceImageView: UIImageView!
    @IBOutlet weak var lblUserName: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
