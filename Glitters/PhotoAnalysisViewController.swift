//
//  PhotoEditingViewController.swift
//  Glitters
//
//  Created by Alex Gnilov on 12/27/17.
//  Copyright © 2017 GrossCo. All rights reserved.
//

import UIKit
import Photos
import PhotosUI
import CoreImage

class PhotoAnalysisViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var analyzisLabel: UILabel!
    @IBOutlet weak var blurView: UIVisualEffectView!
    
    override var prefersStatusBarHidden: Bool { return true }
    override var shouldAutorotate: Bool { return false }
    
    var image: UIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if image != nil {
            imageView.image = image
        }
        analyzisLabel.center = blurView.center
        blurView.isHidden = true

    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.image = nil
        self.imageView = nil
    }
    
    
    @IBAction func savePhotoToCameraRoll(_ sender: UIButton) {
        guard let image = image else { print("Image saving error: no image found"); return}
        
        try? PHPhotoLibrary.shared().performChangesAndWait {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func uploadMedia(_ sender: UIButton) {
        
        // Alert
        let alertMenu = UIAlertController(title: "There is nothing here yet", message: "Uploading feature will be implemented soon", preferredStyle: .alert)
        let okAction =  UIAlertAction(title: "OK", style: .cancel, handler: nil)
        alertMenu.addAction(okAction)
        self.present(alertMenu, animated: true, completion: nil)
        
    }
    
}
