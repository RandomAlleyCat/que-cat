import SwiftUI

class ErrorHandler: ObservableObject {
    @Published var errorMessage: String?
    @Published var showAlert: Bool = false

    func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showAlert = true
    }

    func captureScreenshot() -> UIImage? {
        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
            return nil
        }

        let window = windowScene.windows.first { $0.isKeyWindow }
        UIGraphicsBeginImageContextWithOptions(window?.frame.size ?? CGSize(), false, UIScreen.main.scale)
        window?.drawHierarchy(in: window?.frame ?? CGRect(), afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    func sendErrorMessageWithScreenshot() {
        // Implement your functionality to send the error message and screenshot.
    }
}
