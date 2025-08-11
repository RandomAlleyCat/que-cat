import SwiftUI

struct MessageInputView: View {
    let onSend: (String) -> Void
    @Environment(\.managedObjectContext) private var viewContext
    
    @AppStorage("devMode") private var devMode: Bool = false
    @AppStorage("devKey") private var devKey: String = ""
    @AppStorage("userText") var userText: String = ""
    @AppStorage("selectedName") var selectedName: String = ""
    @AppStorage("selectedIndex") var selectedIndex: Int = 0
    @AppStorage("selectedSessionID") private var selectedSessionID: String?
    @AppStorage("adShown") var adShown: Bool = false
    
    @State private var showAlert: Bool = false
    @State private var sendButtonDisabled: Bool = false
    @StateObject var promptManager: PromptManager
    
    var body: some View {
        ZStack(alignment: .trailing) {
            if #available(iOS 16, *) {
                TextField(promptManager.selectedPrompt.promptName.isEmpty ? "Select a prompt..." : promptManager.selectedPrompt.promptName, text: $userText, axis: .vertical)
                    .padding(7)
                    .padding(.trailing, userText.isEmpty ? 0 : 35)  // create space for the button
                    .background(Color(.systemGray6))
                    .cornerRadius(25)
                    .disabled(promptManager.selectedPrompt.promptName.isEmpty)
                    .alert(isPresented: $showAlert) {
                        Alert(
                            title: Text("API Key Required"),
                            message: Text("Please enter an API key in the Developer settings or disable Dev Mode."),
                            dismissButton: .default(Text("OK"))
                        )
                    }
                    .overlay(
                        HStack {
                            Spacer()
                            if !userText.isEmpty {
                                Button(action: {
                                    sendMessage()
                                }) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.title)
                                        .scaleEffect(1)
                                }
                                .disabled(sendButtonDisabled || promptManager.selectedPrompt.promptName.isEmpty)
                            }
                        }
                        .padding(.trailing, 2)
                    )
            } else {
                TextField(promptManager.selectedPrompt.promptName.isEmpty ? "Select a prompt..." : promptManager.selectedPrompt.promptName, text: $userText)
                    .padding(7)
                    .padding(.trailing, userText.isEmpty ? 0 : 35)  // create space for the button
                    .background(Color(.systemGray6))
                    .cornerRadius(25)
                    .disabled(promptManager.selectedPrompt.promptName.isEmpty)
                    .alert(isPresented: $showAlert) {
                        Alert(
                            title: Text("API Key Required"),
                            message: Text("Please enter an API key in the Developer settings or disable Dev Mode."),
                            dismissButton: .default(Text("OK"))
                        )
                    }
                    .overlay(
                        HStack {
                            Spacer()
                            if !userText.isEmpty {
                                Button(action: {
                                    sendMessage()
                                }) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.title)
                                        .scaleEffect(1)
                                }
                                .disabled(sendButtonDisabled || promptManager.selectedPrompt.promptName.isEmpty)
                            }
                        }
                        .padding(.trailing, 2)
                    )
            }

        }
        .padding(.horizontal, 1)
        .padding(.vertical, 5)
        .onChange(of: selectedSessionID) { _ in
            userText = ""
        }
    }
    
    private func canSendMessage() -> Bool {
        if userText.isEmpty { return false }
        
        if devMode && devKey.isEmpty {
            showAlert = true
            return false
        }
        return true
    }
    
    private func sendMessage() {
        if !canSendMessage() { return }
        
        promptManager.loadPromptList()
        promptManager.updateSelectedPrompt(with: selectedName)

        onSend(userText)
        userText = ""

        if !devMode {
            sendButtonDisabled = true
            DispatchQueue.main.asyncAfter(deadline: .now() + (adShown ? 5 : 30)) {
                sendButtonDisabled = false
            }
        }
        hideKeyboard()
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
