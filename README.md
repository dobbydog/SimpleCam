<h1 align="center">SimpleCam</h1>

<h4 align="center">A Memory Efficient Replacement for the Native UIImagePicker Camera</h4>

<h3>Why Do I Need It?</h3>

SimpleCam was created out of the necessity to have high quality photographs while providing a lightweight memory footprint.  Apple's UIImagePicker is a wonderful application, but because it has a lot of features and a lot of options, . . . it uses a lot of MEMORY.  This can cause crashes, lag, and an overall poor experience when all you wanted was to give the user an opportunity to take a quick picture.

If you're capturing photographs with UIImagePicker, or via AVFoundation on the highest possible capture resolution, it will return giant image files exceeding thousands of pixels in size.  SimpleCam avoids this while still using the highest possible capture resolution by resizing the photo to 2x the size of the phone's screen.  This allows the photo to maintain a significantly reduced file size while still looking clean and brilliant on mobile displays.

I hope you find the project as useful as I did!

# Adding SimpleCam iPad to Your Project

### 1. Add SimpleCam Folder to Xcode

- Unzip SimpleCam
- Drag SimpleCam Folder into your Xcode project
- Make sure "Copy items into destination group's folder (if needed)" is selected

### 2. Your ViewController.h File

- Import SimpleCam
- Set up your view controller as a SimpleCam delegate

```Swift
import UIKit
import SimpleCam

class ViewController : UIViewController {
  ...
}
```

###3. Set Up Delegate

- Add SimpleCam's Delegate method to your ViewController.m file
- Close SimpleCam

This is how SimpleCam will notify your ViewController that the user is finished with it.  If there is an image, then the user took a picture.  If there is not, then the user backed out of the camera without taking a photograph.  Make sure to close SimpleCam in this method using SimpleCam's custom close.  Otherwise, the captureSession may not close properly and may result in memory leaks.

```Swift
extension ViewController : SimpleCamDelegate {
  func simpleCam(_ simpleCam: SimpleCam, didFinishWithImage image: UIImage?) {
    
    if (image != nil) {
        // simple cam finished with image
    }
    else {
        // simple cam finished w/o image
    }
    
    // Close simpleCam - use this as opposed to dismissViewController: to properly end photo session
    simpleCam.closeWithCompletion {
      print("SimpleCam is done closing ... ");
      // It is safe to launch other ViewControllers, for instance, an editor here.
    };
  }
}
```

###4. Launch SimpleCam

- Add this code wherever you'd like SimpleCam to launch

```Swift
let simpleCam = SimpleCam();
simpleCam.delegate = self;    
present(simpleCam, animated: true, completion: nil);
```
If you'd like to launch simple cam when the user presses a button, you could add the above code to the buttonPress method, like so:

```Swift
@IBAction func buttonTap(_ recognizer: UITapGestureRecognizer) {        
  let simpleCam = SimpleCam();
  simpleCam.delegate = self;    
  present(simpleCam, animated: true, completion: nil);
}
```
That's it, it's as  simple as that.  SimpleCam will take care of everything else!

# Notes

- This project is forked from [LoganWright/SimpleCam](https://github.com/LoganWright/SimpleCam) -> [modohash/SimpleCam](https://github.com/modohash/SimpleCam) and rewritten in Swift and XIB
