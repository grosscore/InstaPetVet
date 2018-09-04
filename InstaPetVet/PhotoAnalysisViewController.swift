//
//  PhotoEditingViewController.swift
//  InstaPetVet
//
//  Created by Alex Gnilov on 12/27/17.
//  Copyright © 2017 GrossCo. All rights reserved.
//

import UIKit
import Photos
import PhotosUI
import CoreImage
import Alamofire

class PhotoAnalysisViewController: UIViewController {
    
    // ViewController Settings
    override var prefersStatusBarHidden: Bool { return true }
    override var shouldAutorotate: Bool { return false }
    
    
    //Outlets

    @IBOutlet weak var sendButton: UIStackView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var analysisLabel: UILabel!
    @IBOutlet weak var blurView: UIVisualEffectView!
    @IBOutlet weak var responseTitle: UILabel!
    @IBOutlet weak var responseText: UILabel!
    @IBOutlet weak var responseStackView: UIStackView!
    
    // Main Properties
    var image: UIImage?
    
    
    // CircularLayer Properties
    let shapeLayer = CAShapeLayer()
    let trackLayer = CAShapeLayer()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if image != nil {
            imageView.image = image
        }

        analysisLabel.center = blurView.center
        blurView.isHidden = true
    }
    
    override func viewDidLayoutSubviews() {
        shapeLayer.position = analysisLabel.center
        trackLayer.position = analysisLabel.center
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.image = nil
        self.imageView = nil
    }

    
    // MARK: - NETWORKING
    
    @IBAction func uploadMedia(_ sender: UIButton) {
        
        setupCircularProgressBar()
        animatePulsation(for: trackLayer)
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.3) {
                self.blurView.alpha = 0.0
                self.blurView.isHidden = false
                self.blurView.alpha = 1.0
            }
        }
        
        // Converting image to JPEG
        guard image != nil, let imageData = UIImageJPEGRepresentation(image!, 0.8) else {
            print("Error while converting Image to JPEG")
            return
        }
        
        // Uploading
        
        let endpoint = "https://www.instapetvet.com/appupload.php"
    
        Alamofire.upload(multipartFormData: { multipartFormData in
            multipartFormData.append(imageData,
                                     withName: "image",
                                     fileName: "instapetvet_image.jpg",
                                     mimeType: "image/jpeg")
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
                            // Hide progress bar with animation
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
                    case .failure(let encodingError): print(encodingError)
                    self.connectionAlert()
                }
        })
    }
    
}


// MARK: - EXTENSION

extension PhotoAnalysisViewController {
    
    // CIRCULAR PROGRESS BAR
    
    private func setupCircularProgressBar() {
        let circularPath = UIBezierPath(arcCenter: .zero, radius: 125, startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: true)
        
        trackLayer.path = circularPath.cgPath
        trackLayer.strokeColor = UIColor(red: 55/255, green: 100/255, blue: 155/255, alpha: 0.4).cgColor
        trackLayer.lineWidth = 23
        trackLayer.lineCap = kCALineCapRound
        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.opacity = 1
        
        shapeLayer.transform = CATransform3DMakeRotation(-CGFloat.pi / 2, 0, 0, 1)
        shapeLayer.path = circularPath.cgPath
        shapeLayer.strokeColor = UIColor(red: 93/255, green: 164/255, blue: 255/255, alpha: 1).cgColor
        shapeLayer.lineWidth = 19
        shapeLayer.lineCap = kCALineCapRound
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.opacity = 1
        
        shapeLayer.strokeEnd = 1
        
        self.blurView.layer.addSublayer(trackLayer)
        self.blurView.layer.addSublayer(shapeLayer)
        
        self.analysisLabel.alpha = 1
        self.analysisLabel.isHidden = false
        
        // Hide response stack view
        responseText.text = ""
        responseTitle.text = ""
        responseStackView.isHidden = true
    }
    
    private func animatePulsation(for layer: CAShapeLayer) {
        DispatchQueue.main.async {
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
                self.sendButton.alpha = 0
                self.sendButton.isHidden = true
                self.responseStackView.alpha = 0
                self.responseTitle.text = title
                self.responseText.text = text
                self.responseStackView.isHidden = false
                self.responseStackView.alpha = 1
            })
        }
    }

    
}
