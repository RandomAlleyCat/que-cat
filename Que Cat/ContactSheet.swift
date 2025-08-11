import SwiftUI

struct ContactSheet: View {
    @State private var feedbackType = 0
    @State private var feedback = ""
    @State private var email = ""
    @State private var name = ""
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    let feedbackTypes = ["Bug Report", "Prompt Request", "Feature Request"]
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("Select Feedback Type")) {
                    Picker(selection: $feedbackType, label: Text("Feedback Type")) {
                        ForEach(0..<feedbackTypes.count, id: \.self) { index in
                            Text(feedbackTypes[index]).tag(index)
                        }
                    }
                }
                
                Section(header: Text("Feedback")) {
                    TextEditor(text: $feedback)
                        .frame(height: 200)
                }
                
                Section(header: Text("Name (Optional)")) {
                    TextField("Name", text: $name)
                }
                
                Section(header: Text("Email (Optional)")) {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                }
            }
        }
        .navigationBarTitle("Feedback and Requests", displayMode: .inline)
        .alert(isPresented: $showAlert, content: alertContent)
    }
    
    private func alertContent() -> Alert {
        Alert(
            title: Text(alertTitle),
            message: Text(alertMessage),
            dismissButton: .default(Text("OK"))
        )
    }
}
