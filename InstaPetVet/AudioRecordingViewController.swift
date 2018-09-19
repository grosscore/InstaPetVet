//
//  PhotoEditingViewController.swift
//  InstaPetVet
//
//  Created by Alex Gnilov on 12/27/17.
//  Copyright © 2017 GrossCo. All rights reserved.
//


import Foundation
import AVFoundation
import UIKit
import Alamofire

class AudioRecordingController: UIViewController, AVAudioRecorderDelegate {
    
    @IBOutlet weak var listenAgainButton: UIStackView!
    @IBOutlet weak var blurView: UIView!
    @IBOutlet weak var analysisLabel: UILabel!
    @IBOutlet weak var responseTitle: UILabel!
    @IBOutlet weak var responseText: UILabel!
    @IBOutlet weak var responseStackView: UIStackView!
    
    
    // MARK: - PROPERTIES
    
    override var prefersStatusBarHidden: Bool { return true }
    
    // Audio Recorder properties
    var recordingSession: AVAudioSession!
    var audioRecorder: AVAudioRecorder!
    var timeInterval: TimeInterval = 30
    var permissionGranted: Bool = false
    var audioURL: URL?
    var audioData: Data?
    
    //CircularProgressBar properties
    let shapeLayer = CAShapeLayer()
    let trackLayer = CAShapeLayer()
    
    var updater: CADisplayLink?
    
    // MARK: - VIEWCONTROLLER'S LIFECYCLE
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // audio session setup
        checkAudioPermission()
    
    }
    
    override func viewDidLayoutSubviews() {
        shapeLayer.position = analysisLabel.center
        trackLayer.position = analysisLabel.center
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        
    }
    
    // MARK: - AUDIO RECORDING
    
    private func checkAudioPermission() {
        let permission = AVAudioSession.sharedInstance().recordPermission()
        if permission == AVAudioSessionRecordPermission.granted  {
            self.permissionGranted = true
            setupAudioRecorder()
            setupCircularProgressBar()
            startRecording()
        } else {
            requestRecordPermission()
        }
    }
    
    private func requestRecordPermission() {
        AVAudioSession.sharedInstance().requestRecordPermission () { [unowned self] allowed in
            if allowed {
                self.checkAudioPermission()
            } else {
                self.statusAlert()
            }
        }
    }
    
    private func setupAudioRecorder() {
        guard permissionGranted == true else { return }
        recordingSession = AVAudioSession.sharedInstance()
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let docsDirect = paths[0]
        audioURL = docsDirect.appendingPathComponent("instapetvet_audiofile.m4a")
        
        do {
            try recordingSession.setCategory(AVAudioSessionCategoryPlayAndRecord, mode: AVAudioSessionModeDefault)
            try recordingSession.setActive(true)
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 2,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            guard let audioURL = self.audioURL else { return }
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder.delegate = self
            audioRecorder.prepareToRecord()
            
            
        }
        catch let error {
            print("failed to record with \(error)")
        }
        
    }
    
    private func startRecording() {
        audioRecorder.record(forDuration: timeInterval)
        AudioServicesPlaySystemSound(1113)
        
        updater = CADisplayLink(target: self, selector: #selector(trackAudio))
        updater?.add(to: RunLoop.current, forMode: RunLoopMode.commonModes)
        
    }
    
    internal func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("sending audio to a server...")

        updater?.invalidate()
        shapeLayer.strokeEnd = 1
        animatePulsation(for: trackLayer)
        
        analysisLabel.text = "ANALYZING..."
        analysisLabel.center = shapeLayer.position

        // Sending audio to server
        let endpoint = "insert your endpoint"

        guard audioURL != nil else { print("audioURL is nil"); return }
        do {
            self.audioData = try Data(contentsOf: audioURL!)
        } catch(let error) {
            print(error)
        }

        let audioName = "instapetvet_audiofile.m4a"

        guard let audioData = audioData else { return }
        Alamofire.upload(multipartFormData: { multipartFormData in
            multipartFormData.append(audioData,
                                     withName: "audio",
                                     fileName: audioName,
                                     mimeType: ".m4a")
            },
            to: endpoint,
            encodingCompletion: { encodingResult in
                switch encodingResult {
                case .success(let upload, _, _):
                    upload.validate()
                    upload.responseJSON { response in
                        guard response.result.isSuccess else {
                            print("Error while uploading file: \(String(describing: response.result.error))")
                            self.connectionAlert()
                            return
                        }
                        self.hideProgressBar()
                        // JSON DECODING
                        do {
                            let decoder = JSONDecoder()
                            let jsonResponse = try decoder.decode(JSONResponse.self, from: response.data!)
                            self.presentResponseStackView(with: jsonResponse.title, and: jsonResponse.text)
                            print(jsonResponse.text)
                        } catch {
                            print("an error occured while decoding JSON")
                        }

                    }
                case .failure(let encodingError):
                    print(encodingError)
                    self.connectionAlert()
                    
            }
        })
    }
    
    
    // MARK - @IBACTIONS
    
    @IBAction func restartRecording(_ sender: UIButton) {
        requestRecordPermission()
        setupAudioRecorder()
        setupCircularProgressBar()
        trackLayer.removeAllAnimations()
        startRecording()
    }
    
}



// MARK: - EXTENSIONS

extension AudioRecordingController {
    
    private func statusAlert() {
        let alert = UIAlertController(
            title: "Need Authorization",
            message: "Use your microphone to analyze your pet's heartbeat",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(
            title: "Deny", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(
            title: "OK", style: .default, handler: {
                _ in
                let url = URL(string: UIApplicationOpenSettingsURLString)!
                UIApplication.shared.open(url)
        }))
        self.present(alert, animated:true, completion:nil)
    }
    
    // CIRCULAR PROGRESS BAR
    
    private func setupCircularProgressBar() {
        let circularPath = UIBezierPath(arcCenter: .zero, radius: 125, startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: true)
        
        //trackLayer.position = analysisLabel.center
        trackLayer.path = circularPath.cgPath
        trackLayer.strokeColor = UIColor(red: 145/255, green: 65/255, blue: 80/255, alpha: 0.4).cgColor
        trackLayer.lineWidth = 23
        trackLayer.lineCap = kCALineCapRound
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.opacity = 1
        
        shapeLayer.transform = CATransform3DMakeRotation(-CGFloat.pi / 2, 0, 0, 1)
        shapeLayer.path = circularPath.cgPath
        shapeLayer.strokeColor = UIColor(red: 255/255, green: 123/255, blue: 163/255, alpha: 1).cgColor
        shapeLayer.lineWidth = 19
        shapeLayer.lineCap = kCALineCapRound
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.opacity = 1
        
        shapeLayer.strokeEnd = 0
        
        self.view.layer.addSublayer(trackLayer)
        self.view.layer.addSublayer(shapeLayer)
        
        self.analysisLabel.alpha = 1
        self.analysisLabel.text = "LISTENING TO THE HEARTBEAT"
        self.analysisLabel.isHidden = false
        
        shapeLayer.position = analysisLabel.center
        trackLayer.position = analysisLabel.center
        
        // Hide response text
        responseStackView.isHidden = true
    }
    
    private func animatePulsation(for layer: CAShapeLayer) {
        DispatchQueue.main.async {
            self.shapeLayer.strokeEnd = 1
            
            let scalingAnimation = CABasicAnimation(keyPath: "transform.scale")
            scalingAnimation.toValue = 1.15
            scalingAnimation.duration = 0.8
            scalingAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
            scalingAnimation.autoreverses = true
            scalingAnimation.repeatCount = Float.infinity
            layer.add(scalingAnimation, forKey: "scaling")
            
            let lineWidthAnimation = CABasicAnimation(keyPath: "lineWidth")
            lineWidthAnimation.toValue = layer.lineWidth * 1.15
            lineWidthAnimation.duration = 0.8
            lineWidthAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
            lineWidthAnimation.autoreverses = true
            lineWidthAnimation.repeatCount = Float.infinity
            layer.add(lineWidthAnimation, forKey: "lineWidth")
        }
    }
    
    private func hideProgressBar() {
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.8) {
                self.shapeLayer.opacity = 0
                self.trackLayer.opacity = 0
                
                self.analysisLabel.alpha = 0
            }
            self.analysisLabel.isHidden = true
        }
    }
    
    @objc private func trackAudio() {
        let percentage = audioRecorder.currentTime / timeInterval
        DispatchQueue.main.async {
            self.shapeLayer.strokeEnd = CGFloat(percentage)
            
        }
    }
    
    private func connectionAlert() {
        let alert = UIAlertController(
            title: "Connection Error",
            message: "There is an error occured while uploading data. Please, check your internet connection.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        self.present(alert, animated:true, completion:nil)
        
        print("Connection alert!")
    }
    
    private func presentResponseStackView(with title: String, and text: String) {
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.3, animations: {
                self.responseStackView.alpha = 0
                self.responseTitle.text = title
                self.responseText.text = text
                self.responseStackView.isHidden = false
                self.responseStackView.alpha = 1
            })
        }
    }
   
}
