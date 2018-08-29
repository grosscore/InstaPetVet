import Foundation
import AVFoundation
import UIKit

class AudioRecordingController: UIViewController, AVAudioRecorderDelegate {
    
    @IBOutlet weak var blurView: UIView!
    @IBOutlet weak var analysisLabel: UILabel!
    
    // MARK: - PROPERTIES
    
    override var prefersStatusBarHidden: Bool { return true }
    
    // Audio Recorder properties
    var recordingSession: AVAudioSession!
    var audioRecorder: AVAudioRecorder!
    var timeInterval: TimeInterval = 30
    var permissionGranted: Bool = false
    var audioURL: URL?
    
    //CircularProgressBar properties
    let shapeLayer = CAShapeLayer()
    let trackLayer = CAShapeLayer()
    
    var updater: CADisplayLink?
    
    // MARK: - VIEWCONTROLLER'S LIFECYCLE
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // audio session setup
        requestRecordPermission()
        setupAudioRecorder()
        
        setupCircularProgressBar()
        
        startRecording()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        
    }
    
    
    private func requestRecordPermission() {
        AVAudioSession.sharedInstance().requestRecordPermission () { [unowned self] allowed in
            if allowed {
                self.permissionGranted = true
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
        audioURL = docsDirect.appendingPathComponent("audio_file_000.m4a")
        
        do {
            try recordingSession.setCategory(AVAudioSession.Category.playAndRecord, mode: AVAudioSession.Mode.default)
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
        updater?.add(to: RunLoop.current, forMode: RunLoop.Mode.common)
        
    }
    
    internal func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        updater?.invalidate()
        
        animatePulsation(for: trackLayer)
        analysisLabel.text = "ANALYZING..."
        
        // Sending audio to server
        print("sending to a server")
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
                let url = URL(string:UIApplication.openSettingsURLString)!
                UIApplication.shared.open(url)
        }))
        self.present(alert, animated:true, completion:nil)
    }
    
    // CIRCULAR PROGRESS BAR
    
    private func setupCircularProgressBar() {
        let circularPath = UIBezierPath(arcCenter: .zero, radius: self.view.bounds.width / 3, startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: true)
        
        trackLayer.position = analysisLabel.center
        trackLayer.path = circularPath.cgPath
        trackLayer.strokeColor = UIColor(red: 145/255, green: 65/255, blue: 80/255, alpha: 0.4).cgColor
        trackLayer.lineWidth = 23
        trackLayer.lineCap = CAShapeLayerLineCap.round
        trackLayer.fillColor = UIColor.clear.cgColor
        
        shapeLayer.position = analysisLabel.center
        shapeLayer.transform = CATransform3DMakeRotation(-CGFloat.pi / 2, 0, 0, 1)
        shapeLayer.path = circularPath.cgPath
        shapeLayer.strokeColor = UIColor(red: 255/255, green: 123/255, blue: 163/255, alpha: 1).cgColor
        shapeLayer.lineWidth = 19
        shapeLayer.lineCap = CAShapeLayerLineCap.round
        shapeLayer.fillColor = UIColor.clear.cgColor
        
        shapeLayer.strokeEnd = 0
        
        self.view.layer.addSublayer(trackLayer)
        self.view.layer.addSublayer(shapeLayer)
    }
    
    private func animatePulsation(for layer: CAShapeLayer) {
        DispatchQueue.main.async {
            let scalingAnimation = CABasicAnimation(keyPath: "transform.scale")
            scalingAnimation.toValue = 1.15
            scalingAnimation.duration = 0.8
            scalingAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
            scalingAnimation.autoreverses = true
            scalingAnimation.repeatCount = Float.infinity
            layer.add(scalingAnimation, forKey: "scaling")
            
            let lineWidthAnimation = CABasicAnimation(keyPath: "lineWidth")
            lineWidthAnimation.toValue = layer.lineWidth * 1.15
            lineWidthAnimation.duration = 0.8
            lineWidthAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
            lineWidthAnimation.autoreverses = true
            lineWidthAnimation.repeatCount = Float.infinity
            layer.add(lineWidthAnimation, forKey: "lineWidth")
        }
    }
    
    @objc private func trackAudio() {
        let percentage = audioRecorder.currentTime / timeInterval
        DispatchQueue.main.async {
            self.shapeLayer.strokeEnd = CGFloat(percentage)
            
        }
    }

    
}
