//
//  ViewController.swift
//  SimpleCamDemo
//
//  Created by shuhei takahashi on 2017/11/15.
//  Copyright © 2017年 shuhei takahashi. All rights reserved.
//

import UIKit
import SimpleCam

class ViewController: UIViewController {
    
    @IBOutlet weak var imgView: UIImageView!
    @IBOutlet weak var tapLabel: UILabel!
    var takePhotoImmediately = false

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func handleTap(_ recognizer: UITapGestureRecognizer) {
        let simpleCam = SimpleCam();
        simpleCam.delegate = self;
        simpleCam.enableCameraCaptureAnimation = true;
        
        present(simpleCam, animated: true, completion: nil)
    }

}

extension ViewController : SimpleCamDelegate {
    func simpleCam(_ simpleCam: SimpleCam, didFinishWithImage image: UIImage?) {
        if (image != nil) {
            // simple cam finished with image
            imgView.image = image;
        }
        else {
            // simple cam finished w/o image
            imgView.image = nil;
        }
        
        // Close simpleCam - use this as opposed to 'dismissViewController' otherwise, the captureSession may not close properly and may result in memory leaks.
        simpleCam.closeWithCompletion({
            NSLog("SimpleCam is done closing ... ");
        });
    }

    func simpleCamDidLoadCameraIntoView(_ simpleCam: SimpleCam) {
        NSLog("Camera loaded ... ");
        
        if (takePhotoImmediately) {
            simpleCam.capturePhoto();
        }
    }

    func simpleCamNotAuthorizedForCameraUse(_ simpleCam: SimpleCam) {
        simpleCam.closeWithCompletion({
            NSLog("SimpleCam is done closing ... Not Authorized");
        });
    }
}
