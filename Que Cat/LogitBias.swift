import SwiftUI

struct LogitBias: Codable, Identifiable {
    var id = UUID()
    var token: Int
    var bias: Int
}

struct LogitBiasSection: View {
    @Binding var logit_bias: [LogitBias]
    @State private var logit_bias_for_editing: [LogitBias] = []
    @State private var showingLogitBiasEditor: Bool = false
    
    var body: some View {
        Section(header: Text("Logit Bias")) {
            ZStack(alignment: .leading) {
                if logit_bias.isEmpty {
                    Text("Enter logit bias here...")
                        .foregroundColor(.gray)
                } else {
                    VStack(alignment: .leading) {
                        ForEach(logit_bias , id: \.token) { logit_bias in
                            Text("\(logit_bias.token) : \(logit_bias.bias)")
                                .lineLimit(4)
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                logit_bias_for_editing = logit_bias
                showingLogitBiasEditor = true
            }
        }
        .sheet(isPresented: $showingLogitBiasEditor, onDismiss: {
            if !logit_bias_for_editing.isEmpty {
                logit_bias = logit_bias_for_editing
            }
        }) {
            LogitBiasEditor(logit_bias: $logit_bias_for_editing)
        }
    }
}

struct LogitBiasEditor: View {
    @Binding var logit_bias: [LogitBias]
    @Environment(\.presentationMode) var presentationMode
    @State private var tempLogit_bias: [LogitBias] = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(tempLogit_bias.indices, id: \.self) { index in
                    let logit = tempLogit_bias[index]
                    HStack {
                        TextField("Token", value: binding(for: index).token, formatter: NumberFormatter())
                            .multilineTextAlignment(.center)
                            .keyboardType(.numberPad)
                            .onChange(of: logit.token) { newValue in
                                if newValue > 999999 {
                                    let truncated = min(newValue, 999999)
                                    tempLogit_bias[index].token = truncated
                                }
                            }
                        Text(":")
                            .padding(.horizontal, 4)
                        TextField("Bias", value: binding(for: index).bias, formatter: NumberFormatter())
                            .multilineTextAlignment(.center)
                            .keyboardType(.numbersAndPunctuation)
                            .onChange(of: logit.bias) { newValue in
                                let limited = max(-100, min(newValue, 100))
                                tempLogit_bias[index].bias = limited
                            }
                    }
                    .swipeActions {
                        Button(action: { delete(at: index) }) {
                            Label("Remove", systemImage: "trash.fill")
                        }
                        .tint(.red)
                    }
                }
            }
            .listRowSeparator(.hidden) // Hide separators between rows
            .navigationTitle("Logit Bias Editor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button("Save") {
                            tempLogit_bias.removeAll(where: { $0.token == 0 })
                            if tempLogit_bias.isEmpty {
                                tempLogit_bias.append(LogitBias(token: 0, bias: 0))
                            }
                            logit_bias = tempLogit_bias
                            presentationMode.wrappedValue.dismiss()
                        }
                        Button(action: {
                            tempLogit_bias.append(LogitBias(token: 0, bias: 0))
                        }) {
                            Image(systemName: "plus")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .onAppear { tempLogit_bias = logit_bias }
        }
    }
    
    private func delete(at index: Int) {
        tempLogit_bias.remove(at: index)
        if tempLogit_bias.isEmpty {
            tempLogit_bias.append(LogitBias(token: 0, bias: 0))
        }
    }
    
    private func binding(for index: Int) -> Binding<LogitBias> {
        guard tempLogit_bias.indices.contains(index) else {
            fatalError("Index out of range")
        }
        return $tempLogit_bias[index]
    }
}
