import Foundation
import SwiftUI

struct SettingsPage: View {
    @State private var showAPIKeyEditor = false
    @AppStorage("devKey") var devKey: String = ""
    @AppStorage("devMode") var devMode = false
    @AppStorage("experimentalPrompts") var experimentalPrompts = false
    @State private var showDeveloperModeAlert = false
    @State private var showExperimentalPromptsAlert = false
    @StateObject private var viewModel = PromptManager()

    var body: some View {
        List {
    //        Section(header: Text("Support")) {
    //            NavigationLink(destination: ContactSheet()) {
    //                Text("Feedback and Requests")
    //            }
    //        }
    //        Section(header: Text("Prompts")) {
    //            NavigationLink(destination: PromptOptions()) {
    //                Text("Prompt Options")
    //            }
    //        }
            Section(header: Text("Developer")) {
                Toggle("Developer Mode", isOn: $devMode)
                    .onChange(of: devMode) { value in
                        showDeveloperModeAlert = value
                    }
                    .alert(isPresented: $showDeveloperModeAlert) {
                        Alert(
                            title: Text("Warning"),
                            message: Text("Warning: Developer mode may cause unintended operation or malfunction of the app. This mode is intended for advanced users and developers only. Use at your own risk. Do you wish to proceed?"),
                            primaryButton: .destructive(Text("Enable"), action: {
                                // Enable Developer Mode
                            }),
                            secondaryButton: .cancel(Text("Cancel"), action: {
                                // Disable Developer Mode
                                devMode = false
                            })
                        )
                    }
                if devMode {
                    Button("API Key") {
                        showAPIKeyEditor = true
                    }
                    NavigationLink(destination: DevPromptList().environmentObject(viewModel)) {
                        Text("System Prompts")
                    }
                    Toggle("Experimental Prompts", isOn: $experimentalPrompts)
                        .onChange(of: experimentalPrompts) { value in
                            if value {
                                showExperimentalPromptsAlert = true
                            }
                        }
                        .alert(isPresented: $showExperimentalPromptsAlert) {
                            Alert(
                                title: Text("Warning"),
                                message: Text("Warning: Experimental prompts are untested and may generate unexpected or undesired results. Use at your own risk. Do you wish to proceed?"),
                                primaryButton: .destructive(Text("Enable"), action: {
                                    // Enable Experimental Prompts
                                }),
                                secondaryButton: .cancel(Text("Cancel"), action: {
                                    // Disable Experimental Prompts
                                    experimentalPrompts = false
                                })
                            )
                        }
                }
            }
            Section(header: Text("Legal")) {
                NavigationLink(destination: PrivacyPage()) {
                    Text("Privacy and Legal Policy")
                }
            }
        }
        .listStyle(GroupedListStyle())
        .navigationBarTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .popover(isPresented: $showAPIKeyEditor, arrowEdge: .bottom) {
            APIKeyEditor(devKey: $devKey) { devKey in
                showAPIKeyEditor = false
            }
            .frame(width: 400, height: 150)
        }
    }
}

struct APIKeyEditor: View {
    @Binding var devKey: String
    @Environment(\.presentationMode) private var presentationMode
    
    let onSave: (String) -> Void
    
    var body: some View {
        VStack {
            Text("Enter your API Key:")
                .font(.headline)
                .padding(.bottom)
            
            SecureField("API Key", text: $devKey)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            HStack {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .padding()
                
                Spacer()
                
                Button("Save") {
                    onSave(devKey)
                    presentationMode.wrappedValue.dismiss()
                }
                .padding()
            }
        }
        .padding()
    }
}
