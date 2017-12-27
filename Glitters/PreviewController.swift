//
//  PreviewController.swift
//  Glitters
//
//  Created by Alex Gnilov on 12/24/17.
//  Copyright © 2017 GrossCo. All rights reserved.
//

import UIKit
import Photos

class PreviewController: UIViewController {
    
    @IBOutlet var previewView: UIView!
    @IBOutlet weak var managingView: UIView!
    
    @IBOutlet weak var captureButton: UIButton!
    @IBOutlet weak var cameraRollButton: UIButton!
    @IBOutlet weak var modeSwitcherButton: UIButton!
    @IBOutlet weak var flashButton: UIButton!
    
    override var prefersStatusBarHidden: Bool { return true }
    override var shouldAutorotate: Bool { return false }
    
    let cameraController = CameraController()
    var photo: UIImage?
    
    var captureMode: CaptureMode { return .photo }
    
    override func viewDidLayoutSubviews() {
        constrainManagingView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        func configureCameraController() {
            cameraController.prepare { error in
                if let error = error {
                    print(error)
                }
                try? self.cameraController.displayPreview(on: self.previewView)
            }
        }
        configureCameraController()
        managingView.backgroundColor = UIColor.white
    }

    func constrainManagingView() {
        let safeArea = self.view.safeAreaLayoutGuide
        let height = UIScreen.main.bounds.size.height - (UIScreen.main.bounds.height * 3/4)
        managingView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor).isActive = true
        managingView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor).isActive = true
        managingView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor).isActive = true
        managingView.heightAnchor.constraint(equalToConstant: height).isActive = true
    }
    

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "presentPhotoEditingViewController" {
            let destination = segue.destination as! PhotoEditingViewController
            if self.photo != nil {
                destination.image = photo
            }
        }
    }

    
    //================================
    
    @IBAction func capture(_ sender: UIButton) {
        if captureMode == .photo {
            cameraController.captureImage {(image, error) in
                guard let image = image else {
                    print(error ?? "Image capture error")
                    return
                }
                self.photo = image
                self.performSegue(withIdentifier: "presentPhotoEditingViewController", sender: sender)
            }
        }
    }
    
    @IBAction func openCameraRoll(_ sender: UIButton) {
    }
    
    @IBAction func switchMode(_ sender: UIButton) {
        
    }
    
    @IBAction func toggleFlash(_ sender: UIButton) {
        if cameraController.flashMode == .on {
            cameraController.flashMode = .off
            flashButton.setImage(#imageLiteral(resourceName: "flash-off"), for: .normal)
        } else {
            cameraController.flashMode = .on
            flashButton.setImage(#imageLiteral(resourceName: "flash-on"), for: .normal)
        }
    }
    
    @IBAction func switchCameras(_ sender: UIButton) {
        do {
            try cameraController.switchCameras()
        } catch {
            print(error)
        }
    }
    
    @IBAction func applyGlittersEffect(_ sender: UIButton) {
    }
    
    
    
}

extension PreviewController {
    enum CaptureMode {
        case photo
        case video
    }
}
