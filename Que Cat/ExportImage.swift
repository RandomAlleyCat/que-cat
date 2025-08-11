import Foundation
import UIKit
import PhotosUI
import SwiftUI

func monospaceTextStyling(_ text: String, attributes: [NSAttributedString.Key: Any], monospaceAttributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
    let pattern = "(\\`{3})(.+?)(\\`{3})"
    let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators)
    let attributedString = NSMutableAttributedString(string: text, attributes: attributes)

    var offset = 0
    regex?.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) { match, _, _ in
        if let match = match {
            let nsRange = match.range(at: 2)
            let range = Range(nsRange, in: text)!
            let startIndex = text.index(range.lowerBound, offsetBy: -3)
            let endIndex = text.index(range.upperBound, offsetBy: 3)
            let completeRange = startIndex..<endIndex

            attributedString.replaceCharacters(in: NSRange(completeRange, in: text), with: NSAttributedString(string: String(text[range]), attributes: monospaceAttributes))
            
            // Adjust the offset for the removed characters
            offset -= 6
        }
    }
    return attributedString
}

func exportImage(includeQuestion: Bool) -> UIImage? {
    let userDefaults = UserDefaults.standard
    let answer = userDefaults.string(forKey: "answerPic") ?? ""
    let signature = "Que Cat"

    var questionFontSize: CGFloat = 46
    var answerFontSize: CGFloat = 42
    let signatureFontSize: CGFloat = 38

    var image: UIImage?

    repeat {
        let questionFont = UIFont(name: "Genos", size: questionFontSize) ?? UIFont.systemFont(ofSize: questionFontSize)
        let answerFont = UIFont(name: "Genos", size: answerFontSize) ?? UIFont.systemFont(ofSize: answerFontSize)
        let signatureFont = UIFont(name: "ChalkDuster", size: signatureFontSize) ?? UIFont.systemFont(ofSize: signatureFontSize)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineSpacing = 10

        let shadow = NSShadow()
        shadow.shadowColor = UIColor.black.withAlphaComponent(0.6)
        shadow.shadowBlurRadius = 6
        shadow.shadowOffset = CGSize(width: 0, height: 2)

        let questionAttributes: [NSAttributedString.Key: Any] = [.font: questionFont, .foregroundColor: UIColor.black, .paragraphStyle: paragraphStyle, .shadow: shadow]
        let answerAttributes: [NSAttributedString.Key: Any] = [.font: answerFont, .foregroundColor: UIColor.blue, .paragraphStyle: paragraphStyle, .shadow: shadow]
        let signatureAttributes: [NSAttributedString.Key: Any] = [.font: signatureFont, .foregroundColor: UIColor.black, .paragraphStyle: paragraphStyle, .shadow: shadow]

        let monospaceAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.monospacedSystemFont(ofSize: answerFontSize - 4, weight: .regular), .foregroundColor: UIColor.black, .paragraphStyle: paragraphStyle, .shadow: shadow]

        let answerAttributedString = monospaceTextStyling(answer, attributes: answerAttributes, monospaceAttributes: monospaceAttributes)

        var questionSize = CGSize.zero
        if includeQuestion {
            let question = userDefaults.string(forKey: "questionPic") ?? ""
            questionSize = question.boundingRect(with: CGSize(width: 800, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], attributes: questionAttributes, context: nil).size
        }
        
        let answerSize = answerAttributedString.boundingRect(with: CGSize(width: 800, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], context: nil).size

        let signatureSize = signature.boundingRect(with: CGSize(width: 800, height: CGFloat.greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], attributes: signatureAttributes, context: nil).size

        var imageSize = CGSize(width: 900, height: 50 + answerSize.height + 50 + signatureSize.height)
        if includeQuestion {
            imageSize.height += questionSize.height + 50
        }

        UIGraphicsBeginImageContextWithOptions(imageSize, false, 0)

        guard let backgroundImage = UIImage(named: "greenalley"),
              let processedBackground = BackgroundImageProcessor.process(backgroundImage) else {
            return nil
        }

        let backgroundRect = CGRect(x: 0, y: imageSize.height - processedBackground.size.height, width: processedBackground.size.width, height: processedBackground.size.height)
        processedBackground.draw(in: backgroundRect)

        if includeQuestion {
            let questionRect = CGRect(x: 50, y: 50, width: 800, height: questionSize.height)
            let questionAttributedString = NSAttributedString(string: userDefaults.string(forKey: "questionPic") ?? "", attributes: questionAttributes)
            questionAttributedString.draw(in: questionRect)
        }

        var answerRect = CGRect(x: 50, y: 50, width: 800, height: answerSize.height)
        if includeQuestion {
            answerRect.origin.y = 50 + questionSize.height + 30
        }

        answerAttributedString.draw(in: answerRect)

        let signatureRect = CGRect(x: 50, y: imageSize.height - signatureSize.height - 30, width: 800, height: signatureSize.height)
        let signatureAttributedString = NSAttributedString(string: signature, attributes: signatureAttributes)
        signatureAttributedString.draw(in: signatureRect)

        guard let smallImage = UIImage(named: "qr3.jpg") else {
            return nil
        }

        let smallImageWidth: CGFloat = 80
        let smallImageHeight: CGFloat = smallImage.size.height * (smallImageWidth / smallImage.size.width)
        let smallImageX = signatureRect.maxX - 45
        let smallImageY = signatureRect.midY - (smallImageHeight / 2)

        let smallImageRect = CGRect(x: smallImageX, y: smallImageY, width: smallImageWidth, height: smallImageHeight)
        smallImage.draw(in: smallImageRect)

        image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        if imageSize.height > 2000 {
            questionFontSize -= 2.0
            answerFontSize -= 2.0
        }
        
    } while image == nil || image!.size.height > 2000

    return image
}
