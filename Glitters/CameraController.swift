//
//  CameraController.swift
//  Glitters
//
//  Created by Alex Gnilov on 12/24/17.
//  Copyright © 2017 GrossCo. All rights reserved.
//

import UIKit
import AVFoundation
import CoreMotion
import Photos

class CameraController: NSObject, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    var captureSession: AVCaptureSession?
    var frontCamera: AVCaptureDevice?
    var rearCamera: AVCaptureDevice?
    var currentCameraPosition: CameraPosition?
    var frontCameraInput: AVCaptureDeviceInput?
    var rearCameraInput: AVCaptureDeviceInput?
    var photoOutput: AVCapturePhotoOutput?
    var videoOutput: AVCaptureVideoDataOutput?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    var flashMode = AVCaptureDevice.FlashMode.off
    var photoCaptureCompletionBlock: ((Data?, Error?) -> Void)?
    
    var photoData: Data?
    var livePhotoCompanionMovieURL: URL?
    var livePhotoMode: LivePhotoMode = .off
    
    func prepare(completionHandler: @escaping (Error?) -> Void) {

        self.captureSession = AVCaptureSession()
        
        func configureCaptureDevices() throws {
            let discoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualCamera, .builtInWideAngleCamera], mediaType: AVMediaType.video, position: .unspecified)
            let cameras = (discoverySession.devices.flatMap { $0 })
            guard !cameras.isEmpty else { throw CameraControllerError.noCamerasAvailable }
            
            for camera in cameras {
                if camera.position == .front {
                    self.frontCamera = camera
                }
                if camera.position == .back {
                    self.rearCamera = camera
                    try camera.lockForConfiguration()
                    camera.focusMode = .continuousAutoFocus
                    camera.unlockForConfiguration()
                }
            }
        }
        
        func configureDeviceInputs() throws {
            guard let captureSession = self.captureSession else { throw CameraControllerError.captureSessionIsMissing }
            
            if let rearCamera = self.rearCamera {
                self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
                if captureSession.canAddInput(self.rearCameraInput!) {
                    captureSession.addInput(self.rearCameraInput!)
                }
                self.currentCameraPosition = .rear
            }
            else if let frontCamera = self.frontCamera {
                self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
                if captureSession.canAddInput(self.frontCameraInput!) {
                    captureSession.addInput(self.frontCameraInput!)
                }
                self.currentCameraPosition = .front
            } else { throw CameraControllerError.noCamerasAvailable }
        }
        
        DispatchQueue(label: "prepare").async {
            do {
                try configureCaptureDevices()
                try configureDeviceInputs()
                try self.configurePhotoOutput()
            } catch {
                DispatchQueue.main.async {
                    completionHandler(error)
                }
                return
            }
            DispatchQueue.main.async {
                completionHandler(nil)
            }
        }
        
    }
    
    // ==================== MARK: - CONFIGURE PHOTO & VIDEO CAPTURE OUTPUTS =================
    
    func configurePhotoOutput() throws {
        guard let captureSession = self.captureSession else { throw CameraControllerError.captureSessionIsMissing }
        captureSession.sessionPreset = .photo
        self.photoOutput = AVCapturePhotoOutput()
        if self.photoOutput!.availablePhotoCodecTypes.contains(.hevc) {
            self.photoOutput!.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])], completionHandler: nil)
        }
        if captureSession.canAddOutput(self.photoOutput!) {
            captureSession.addOutput(self.photoOutput!)
            photoOutput!.isHighResolutionCaptureEnabled = true
            photoOutput!.isLivePhotoCaptureEnabled = photoOutput!.isLivePhotoCaptureSupported
        }
        
        self.captureSession!.startRunning()
    }
    
    // ==================== MARK: - CONFIGURE DISPLAY PREVIEW ===============================
    
    func displayPreview(on view: UIView) throws {
        guard let captureSession = self.captureSession, captureSession.isRunning else { throw CameraControllerError.captureSessionIsMissing }
        var height: CGFloat?
        self.previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer?.videoGravity = .resizeAspect
        
        let width: CGFloat = UIScreen.main.bounds.width
        if captureSession.sessionPreset == .photo {
            height = (UIScreen.main.bounds.height * 3/4)
        }
        if captureSession.sessionPreset == .high {
            height = view.bounds.size.height
        }
        self.previewLayer?.frame = CGRect(x: 0, y: 0, width: width, height: height!)
        view.layer.insertSublayer(previewLayer!, at: 0)
        
    }
    
    // ==================== MARK: - CONFIGURE FOCUS MODE ===================================
    
    func focus(with focusMode: AVCaptureDevice.FocusMode, exposureMode: AVCaptureDevice.ExposureMode, at devicePoint: CGPoint, monitorSubjectAreaChange: Bool) {
        var device: AVCaptureDevice!
        if self.currentCameraPosition == .rear {
            device = self.rearCamera
        }
        if self.currentCameraPosition == .front {
            device = self.frontCamera
        }
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode) {
                device.focusPointOfInterest = devicePoint
                device.focusMode = focusMode
            }
            if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode) {
                device.exposureMode = exposureMode
                device.exposurePointOfInterest = devicePoint
            }
            device.isSubjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange
            device.unlockForConfiguration()
        } catch {
            print(error)
        }
    }
    
    // ==================== MARK: - CAPTURING PHOTO AND VIDEO ==============================
    
    func captureImage(completion: @escaping (Data?, Error?) -> Void) {
        guard let captureSession = captureSession, captureSession.isRunning else { completion(nil, CameraControllerError.captureSessionIsMissing); return }
        let settings = AVCapturePhotoSettings()
        settings.flashMode = self.flashMode
        
        if self.livePhotoMode == .on && self.photoOutput!.isLivePhotoCaptureSupported {
            let livePhotoMovieFileName = NSUUID().uuidString
            let livePhotoMovieFilePath = (NSTemporaryDirectory() as NSString).appendingPathComponent((livePhotoMovieFileName as NSString).appendingPathExtension("mov")!)
            let livePhotoMovieFileURL = URL(fileURLWithPath: livePhotoMovieFilePath)
            settings.livePhotoMovieFileURL = livePhotoMovieFileURL
        }
        
        self.photoOutput?.capturePhoto(with: settings, delegate: self)
        self.photoCaptureCompletionBlock = completion
    }
    
    
    // implementing AVCapturePhotoCaptureDelegate methods:
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error { self.photoCaptureCompletionBlock?(nil, error) }
        else
            
            if let data = photo.fileDataRepresentation() { self.photoCaptureCompletionBlock?(data, nil); self.photoData = data }
        else { self.photoCaptureCompletionBlock?(nil, CameraControllerError.unknown) }
    }

    // implementing AVCapturePhotoCaptureDelegate methods for LivePhoto:
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL, duration: CMTime, photoDisplayTime: CMTime, resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error = error {
            print("An error occured while processing LivePhoto movie file: \(error)")
        } else {
            self.livePhotoCompanionMovieURL = outputFileURL
            print("Successfully captured LivePhotoMovieFile")
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        guard let photoData = self.photoData, let livePhotoMovieURL = self.livePhotoCompanionMovieURL else { return }
        if let error = error {
            print("An error occured while finishing capture the photo: \(error)")
        } else {
            if self.livePhotoMode == .on {
                
            saveLivePhotoToPhotoLibrary(photoData: photoData, livePhotoMovieURL: livePhotoMovieURL)
            }
        }
    }
    

    
    // Save Live Photo To PhotoLibrary ===============!!!!==================!!!!============!!!!!========================!!!!!!!!!!!!
    func saveLivePhotoToPhotoLibrary(photoData: Data, livePhotoMovieURL: URL) {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                try? PHPhotoLibrary.shared().performChangesAndWait {
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    let creationOptions = PHAssetResourceCreationOptions()
                    creationOptions.shouldMoveFile = true
                    creationRequest.addResource(with: .photo, data: photoData, options: creationOptions)
                    creationRequest.addResource(with: .pairedVideo, fileURL: livePhotoMovieURL, options: creationOptions)
                    
                    print("Successfully saved LivePhoto to PhotoLibrary")
                }
            } else {
                self.didFinish()
            }
        }
    }
    
    // Create LivePhoto object
    func createLivePhotoObject(movieFileURL: URL, imageData: Data, completion: @escaping (_ livePhotoObject: PHLivePhoto) -> Void) {
        
        let previewImage = UIImage(data: imageData)
        PHLivePhoto.request(withResourceFileURLs: [movieFileURL], placeholderImage: previewImage, targetSize: CGSize.zero, contentMode: .aspectFill) {
            (livePhoto, infoDict) -> Void in
            if let requestedPhoto = livePhoto {
                
                completion(requestedPhoto)
            } else {
                print("Error creating LivePhoto object")
            }
        }
    }

    
    // ==================== MARK: - ADDITIONAL METHODS =====================================
    
    private func didFinish() {
        if let livePhotoCompanionMoviePath = livePhotoCompanionMovieURL?.path {
            if FileManager.default.fileExists(atPath: livePhotoCompanionMoviePath) {
                do {
                    try FileManager.default.removeItem(atPath: livePhotoCompanionMoviePath)
                } catch {
                    print("Could not remove file at url: \(livePhotoCompanionMoviePath)")
                }
            }
        }
    }
    
    func switchCameras() throws {
        guard let currentCameraPosition = currentCameraPosition, let captureSession = self.captureSession, captureSession.isRunning else { throw CameraControllerError.captureSessionIsMissing }
        
        captureSession.beginConfiguration()
        
        func switchToFrontCamera() throws {
            guard let rearCameraInput = self.rearCameraInput, captureSession.inputs.contains(rearCameraInput), let frontCamera = self.frontCamera else { throw CameraControllerError.invalidOperation }
            
            self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
            
            captureSession.removeInput(rearCameraInput)
            if captureSession.canAddInput(frontCameraInput!) {
                captureSession.addInput(frontCameraInput!)
                self.currentCameraPosition = .front
            } else { throw CameraControllerError.invalidOperation }
        }
        
        func switchToRearCamera() throws {
            guard let frontCameraInput = self.frontCameraInput, captureSession.inputs.contains(frontCameraInput), let rearCamera = self.rearCamera else { throw CameraControllerError.invalidOperation }
            
            self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
            
            captureSession.removeInput(frontCameraInput)
            
            if captureSession.canAddInput(rearCameraInput!) {
                captureSession.addInput(rearCameraInput!)
                self.currentCameraPosition = .rear
            } else { throw CameraControllerError.invalidOperation }
        }

        switch currentCameraPosition {
            case .front: try switchToRearCamera()
            case .rear: try switchToFrontCamera()
        }
        
        self.photoOutput!.isLivePhotoCaptureEnabled = self.photoOutput!.isLivePhotoCaptureSupported
        captureSession.commitConfiguration()
    }

     
}


// ======================== MARK: - EXTENSION ============================================

extension CameraController {
    
    private enum CameraControllerError: Swift.Error {
        case captureSessionIsAlreadyRunning
        case captureSessionIsMissing
        case inputsAreInvalid
        case invalidOperation
        case noCamerasAvailable
        case unknown
    }
    
    public enum CameraPosition {
        case front
        case rear
    }
    
    enum LivePhotoMode {
        case on
        case off
    }
}
