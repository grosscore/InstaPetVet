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

class PhotoEditingViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var livePhotoView: PHLivePhotoView!
    
    override var prefersStatusBarHidden: Bool { return true }
    override var shouldAutorotate: Bool { return false }
    
    var image: UIImage?
    var livePhoto: PHLivePhoto? {
        didSet {
            livePhotoView.livePhoto = livePhoto
            livePhotoView.contentMode = .scaleAspectFit
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        imageView.image = image
    }
    
    @IBAction func savePhotoToCameraRoll(_ sender: UIButton) {
        guard let image = image else { print("Image saving error: no image found"); return}
        try? PHPhotoLibrary.shared().performChangesAndWait {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func applyGlitteringEffect(_ sender: UIButton) {
    }
    

}
