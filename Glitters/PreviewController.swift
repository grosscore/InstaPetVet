//
//  PreviewController.swift
//  Glitters
//
//  Created by Alex Gnilov on 12/24/17.
//  Copyright © 2017 GrossCo. All rights reserved.
//

import UIKit
import Photos

class PreviewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet var previewView: UIView!
    @IBOutlet weak var managingView: UIView!
    
    @IBOutlet weak var captureButton: UIButton!
    @IBOutlet weak var cameraRollButton: UIButton!
    @IBOutlet weak var modeSwitcherButton: UIButton!
    @IBOutlet weak var flashButton: UIButton!
    @IBOutlet weak var livePhotoButton: UIButton!
    
    override var shouldAutorotate: Bool { return false }
    override var prefersStatusBarHidden: Bool { return true }
    
    let cameraController = CameraController()
    var photo: UIImage?
    
    var captureMode: CaptureMode?
    
    override func viewDidLayoutSubviews() {
        constrainManagingView()
        self.modeSwitcherButton.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        self.cameraRollButton.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
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
        
        setCameraRollButtonImage()
        PHPhotoLibrary.shared().register(self)
        
        self.captureMode = .photo
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
        self.captureButton.isEnabled = false
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        let deviceOrientation = UIDevice.current.orientation.rawValue
        if captureMode == .photo {
            if let photoOutputConnection = cameraController.photoOutput?.connection(with: AVMediaType.video) {
                photoOutputConnection.videoOrientation = AVCaptureVideoOrientation(rawValue: deviceOrientation)!
            }
            cameraController.captureImage {(image, error) in
                guard let image = image else {
                    print(error ?? "Image capture error")
                    return
                }
                self.photo = image
                self.performSegue(withIdentifier: "presentPhotoEditingViewController", sender: sender)
                self.captureButton.isEnabled = true
                UIDevice.current.endGeneratingDeviceOrientationNotifications()
            }
        }
    }
    
    // ImagePickerController methods
    @IBAction func openCameraRoll(_ sender: UIButton) {
        if UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum) {
            let imagePicker = UIImagePickerController()
            imagePicker.allowsEditing = false
            imagePicker.sourceType = .savedPhotosAlbum
            imagePicker.delegate = self
            self.present(imagePicker, animated: true, completion: nil)
        }
    }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        self.photo = info[UIImagePickerControllerOriginalImage] as? UIImage
        dismiss(animated: true, completion: nil)
        self.performSegue(withIdentifier: "presentPhotoEditingViewController", sender: nil)
    }
    
    func setCameraRollButtonImage() {
        let imageManager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        requestOptions.isSynchronous = true
        let fetchOptions = PHFetchOptions()
        fetchOptions.fetchLimit = 1
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let fetchResult: PHFetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)   //FIXME: - In case Adding Video
        if fetchResult.firstObject != nil {
            imageManager.requestImage(for: fetchResult.firstObject!, targetSize: cameraRollButton.bounds.size, contentMode: .aspectFill, options: requestOptions, resultHandler: {(result, _) in
                self.cameraRollButton.setImage(result, for: .normal)
                self.cameraRollButton.imageView!.layer.cornerRadius = self.cameraRollButton.bounds.size.width / 2
            })
        }
    }

    //===========================
    
    @IBAction func tapToFocus(_ sender: UITapGestureRecognizer) {
        let devicePoint = cameraController.previewLayer?.captureDevicePointConverted(fromLayerPoint: sender.location(in: sender.view))
        cameraController.focus(with: .autoFocus, exposureMode: .autoExpose, at: devicePoint!, monitorSubjectAreaChange: true)
    }
    
    @IBAction func switchMode(_ sender: UIButton) {
        do {
            try self.cameraController.configureVideoOutput()
        } catch { print("error configuring Video Output")}
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
    @IBAction func livePhoto(_ sender: UIButton) {
    }
    
    @IBAction func applyGlittersEffect(_ sender: UIButton) {
    }
    
}

extension PreviewController: PHPhotoLibraryChangeObserver {
    enum CaptureMode {
        case photo
        case video
    }
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.sync {
            self.setCameraRollButtonImage()
        }
    }
    
    @IBAction func close(segue:UIStoryboardSegue) {
    }
}
