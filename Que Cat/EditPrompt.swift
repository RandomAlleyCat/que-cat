import SwiftUI

struct EditPrompt: View {
    @Binding var promptData: Prompt
    @Binding var isNewPrompt: Bool
    @EnvironmentObject var viewModel: PromptManager
    @Environment(\.presentationMode) private var presentationMode
    @State private var showingTextEditor = false
    @State private var showingLogitBiasEditor = false

    var isSaveDisabled: Bool {
        return promptData.promptName.isEmpty || promptData.promptText.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                PromptNameSection(promptName: $promptData.promptName)
                PromptTextSection(promptText: $promptData.promptText, showingTextEditor: $showingTextEditor)
                ModelSettingsSection(promptData: $promptData)
                LogitBiasSection(logit_bias: $promptData.logit_bias)
                StopSequenceSection(stop: $promptData.stop)
                UserSection(user: $promptData.user)
            }
            .onTapGesture {
                dismissKeyboard()
            }
            .navigationTitle("Edit System Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    viewModel.cancelEdit()
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    viewModel.savePrompt()
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(isSaveDisabled)
            )
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct PromptNameSection: View {
    @Binding var promptName: String
    
    var body: some View {
        Section(header: Text("System Prompt Name")) {
            TextField("", text: $promptName)
        }
    }
}

struct PromptTextSection: View {
    @Binding var promptText: String
    @Binding var showingTextEditor: Bool
    
    var body: some View {
        Section(header: Text("System Prompt Text")) {
            ZStack(alignment: .leading) {
                if promptText.isEmpty {
                    Text("Enter prompt text here...")
                        .foregroundColor(.gray)
                }
                Text(promptText)
                    .lineLimit(2)
            }
            .contentShape(Rectangle())
            .onTapGesture { showingTextEditor = true }
        }
        .sheet(isPresented: $showingTextEditor) {
            PromptTextEditor(text: $promptText)
        }
    }
}

struct ModelSettingsSection: View {
    @Binding var promptData: Prompt
    @State private var isCustomModel: Bool = false

    let models = [
        ("gpt-5", "GPT-5"),
        ("gpt-5-nano", "GPT-5 Nano"),
        ("gpt-4.1", "GPT-4.1"),
        ("gpt-4.1-mini", "GPT-4.1 Mini"),
        ("gpt-4o", "GPT-4o"),
        ("gpt-4o-mini", "GPT-4o Mini"),
        ("o4", "O4"),
        ("o4-mini", "O4 Mini"),
        ("gpt-4", "GPT-4 (Legacy)"),
        ("gpt-4-turbo", "GPT-4 Turbo (Legacy)"),
        ("gpt-3.5-turbo", "GPT-3.5 Turbo (Legacy)")
    ]

    var tokens: Int {
        switch promptData.modelName {
        case "gpt-5":
            return 256000
        case "gpt-5-nano", "gpt-4.1", "gpt-4o", "o4":
            return 128000
        case "gpt-4.1-mini", "gpt-4o-mini", "o4-mini", "gpt-4-turbo":
            return 128000
        case "gpt-4":
            return 8192
        case "gpt-3.5-turbo":
            return 16000
        default:
            return 128000
        }
    }
    
    var body: some View {
        Section(header: Text("Model Settings")) {
            ModelPickerView(models: models, promptData: $promptData, tokens: tokens)
            TemperatureSettingsView(promptData: $promptData)
            MaxTokensSettingsView(promptData: $promptData, tokens: tokens)
            PresencePenaltySettingsView(promptData: $promptData)
            FrequencyPenaltySettingsView(promptData: $promptData)
        }
    }
}

struct ModelPickerView: View {
    let models: [(String, String)]
    @Binding var promptData: Prompt
    let tokens: Int
    
    var body: some View {
        VStack {
            HStack {
                Picker("Model", selection: Binding(get: {
                    promptData.modelName
                }, set: { newValue in
                    promptData.modelName = newValue
                    let newTokens = promptData.tokens(forModel: newValue)
                    if promptData.max_tokens > newTokens {
                        promptData.max_tokens = newTokens
                    }
                })) {
                    ForEach(models.indices, id: \.self) { index in
                        Text(models[index].1).tag(models[index].0)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(alignment: .trailing)
            }
        }
    }
}

struct TemperatureSettingsView: View {
    @Binding var promptData: Prompt

    var body: some View {
        let temperatureFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 2
            return formatter
        }()
        return VStack {
            HStack {
                Text("Temperature")
                    .frame(width: 200, alignment: .leading)
                Spacer()
                TextField("", value: $promptData.temperature, formatter: temperatureFormatter)
                        .multilineTextAlignment(.trailing)
                }
            Slider(value: $promptData.temperature, in: 0.0...1.0)
                .accentColor(.blue)
        }
    }
}

struct MaxTokensSettingsView: View {
    @Binding var promptData: Prompt
    let tokens: Int
    
    var body: some View {
        VStack {
            HStack {
                Text("Max Tokens")
                    .frame(width: 200, alignment: .leading)
                Spacer()
                TextField("", value: $promptData.max_tokens, formatter: NumberFormatter())
                    .onChange(of: promptData.max_tokens, perform: { value in
                        promptData.max_tokens = min(value, tokens)
                    })
                    .multilineTextAlignment(.trailing)
            }
            Slider(value: Binding(get: {
                Double(promptData.max_tokens)
            }, set: { newValue in
                promptData.max_tokens = min(Int(newValue.rounded()), tokens)
            }), in: 16...Double(tokens), step: 16)
            .accentColor(.blue)
        }
    }
}
    
struct PresencePenaltySettingsView: View {
    @Binding var promptData: Prompt

    var body: some View {
        let penaltyFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 2
            return formatter
        }()
        return VStack {
            HStack {
                Text("Presence Penalty")
                    .frame(width: 200, alignment: .leading)
                Spacer()
                TextField("", value: $promptData.presence_penalty, formatter: penaltyFormatter)
                      .multilineTextAlignment(.trailing)
                }
            Slider(value: $promptData.presence_penalty, in: -2.0...2.0)
                .accentColor(.blue)
        }
    }
}
    
struct FrequencyPenaltySettingsView: View {
    @Binding var promptData: Prompt

    var body: some View {
        let penaltyFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 2
            return formatter
        }()
        return VStack {
            HStack {
                Text("Frequency Penalty")
                    .frame(width: 200, alignment: .leading)
                Spacer()
                TextField("", value: $promptData.frequency_penalty, formatter: penaltyFormatter)
                       .multilineTextAlignment(.trailing)
                }
            Slider(value: $promptData.frequency_penalty, in: -2.0...2.0)
                .accentColor(.blue)
        }
    }
}

struct StopSequenceSection: View {
    @Binding var stop: String
    
    var body: some View {
        Section(header: Text("Stop Sequence")) {
            TextField("", text: $stop)
        }
    }
}

struct UserSection: View {
    @Binding var user: String
    
    var body: some View {
        Section(header: Text("User")) {
            TextField("", text: $user)
        }
    }
}

struct PromptTextEditor: View {
    @Binding var text: String
    @State private var tempText: String
    @Environment(\.presentationMode) var presentationMode

    init(text: Binding<String>) {
        _text = text
        _tempText = State(initialValue: text.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            VStack {
                TextEditor(text: $tempText)
                HStack {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    Spacer()
                    Button("Save") {
                        text = tempText
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .padding()
            .navigationTitle("Prompt Text Editor")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
