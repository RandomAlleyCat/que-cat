import Foundation
import SwiftUI
import UIKit

class BackgroundImageProcessor {
    
    static func process(_ backgroundImage: UIImage) -> UIImage? {
        
        let inputImage = CIImage(image: backgroundImage)
        
        let filter = CIFilter(name: "CIColorControls")!
        filter.setValue(inputImage, forKey: kCIInputImageKey)
        filter.setValue(0.9, forKey: kCIInputSaturationKey)
        filter.setValue(0.1, forKey: kCIInputBrightnessKey)
        filter.setValue(0.9, forKey: kCIInputContrastKey)
        
        let alphaFilter = CIFilter(name: "CIColorMatrix")!
        alphaFilter.setValue(filter.outputImage, forKey: kCIInputImageKey)
        alphaFilter.setValue(CIVector(x: 0, y: 0, z: 0, w: 0.5), forKey: "inputAVector")
        
        let blurFilter = CIFilter(name: "CIGaussianBlur")!
        blurFilter.setValue(alphaFilter.outputImage, forKey: kCIInputImageKey)
        blurFilter.setValue(0.5, forKey: kCIInputRadiusKey)
        
        guard let outputCIImage = blurFilter.outputImage else { return nil }
        
        let outputImage = UIImage(ciImage: outputCIImage)
        let resizedImage = resizeImage(image: outputImage, targetSize: CGSize(width: 900, height: backgroundImage.size.height / backgroundImage.size.width * 900))
        return resizedImage
    }

    static func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height

        // Figure out what our orientation is, and use that to form the rectangle
        var newSize: CGSize
        if widthRatio > heightRatio {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        }

        // This is the rect that we've calculated out and this is what is actually used below
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)

        // Actually do the resizing to the rect using the ImageContext stuff
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage!
    }

}
