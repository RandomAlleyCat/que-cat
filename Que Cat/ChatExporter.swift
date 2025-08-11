import SwiftUI

struct ChatExporter {
    let session: ChatSession
    
    @AppStorage("selectedName") var selectedName: String = ""
    
    enum ExportType: String, CaseIterable, Identifiable {
        var id: String { self.rawValue }
        
        case json, csv
    }
    
    func fetchChatHistory() -> [ExportChat] {
        guard let chatSet = session.messages as? Set<ChatMessage> else {
            debugPrint("Failed to fetch chat history from chat session: \(session)")
            return []
        }
        
        let chatArray = Array(chatSet)
        let sortedChats = chatArray.sorted { $0.timestamp ?? Date() < $1.timestamp ?? Date() }
        
        return sortedChats.map { chat in
            ExportChat(
                timestamp: chat.timestamp ?? Date(),
                role: chat.role ?? "",
                message: chat.message ?? ""
            )
        }
    }
    
    func exportActionSheetButtons() -> [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = ExportType.allCases.map { exportType in
                .default(Text(exportType.rawValue.uppercased())) {
                    let chatHistory = fetchChatHistory()
                    
                    var data: Data?
                    switch exportType {
                    case .json:
                        data = exportChatHistoryAsJSON(chatHistory)
                    case .csv:
                        data = exportChatHistoryAsCSV(chatHistory)
                    }
                    
                    if let data = data,
                       let fileURL = writeExportDataToFile(data, sessionName: session.name ?? "ChatSession", exportType: exportType) {
                        DispatchQueue.main.async {
                            let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
                            
                            UIApplication.shared.connectedScenes
                                .filter { $0.activationState == .foregroundActive }
                                .map { $0 as? UIWindowScene }
                                .compactMap { $0 }
                                .first?.windows.first?.rootViewController?
                                .present(activityVC, animated: true, completion: nil)
                        }
                    }
                }
        }
        buttons.append(.cancel())
        return buttons
    }
    
    func exportChatHistoryAsJSON(_ chatHistory: [ExportChat]) -> Data? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(chatHistory)
    }
    
    func exportChatHistoryAsCSV(_ chatHistory: [ExportChat]) -> Data? {
        var csvString = "timestamp,role,message\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for chat in chatHistory {
            let timestamp = dateFormatter.string(from: chat.timestamp)
            let role = chat.role
            let message = chat.message.replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: ",", with: "\\,")
            csvString += "\(timestamp),\(role),\"\(message)\"\n"
        }
        
        return csvString.data(using: .utf8)
    }
    
    func writeExportDataToFile(_ data: Data, sessionName: String, exportType: ExportType) -> URL? {
        let ext: String
        switch exportType {
        case .json: ext = "json"
        case .csv: ext = "csv"
        }
        
        let fileName = "\(sessionName).\(selectedName).\(ext)"
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            debugPrint("Error writing export data to file: \(error)")
            return nil
        }
    }
}
