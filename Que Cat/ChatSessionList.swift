import Combine
import CoreData
import SwiftUI
import UIKit

struct ChatSessionList: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var openAI: OpenAIService

    @FetchRequest(
        entity: ChatSession.entity(),
        sortDescriptors: [],
        animation: .default
    ) var chatSessions: FetchedResults<ChatSession>
    
    let onSessionSelected: (ChatSession) -> Void
    
    enum SortOrder: String {
        case alphabetical
        case updateTime
        case off
    }
    
    enum ExportType: String, CaseIterable, Identifiable {
        var id: String { self.rawValue }
        
        case json, csv
    }

    @State private var searchText = ""
    @State private var isEditing = false
    @State private var showCreateSessionAlert = false
    @State private var showingDeleteAlert = false
    @State private var sessionToDelete: ChatSession? = nil
    @State private var sortByFavorites = false
    @State private var refreshViewID = UUID()
    @State private var selectedSession: ChatSession?
    @State private var chatNav: Bool? = nil
    @State private var showExportSheet: ChatSession? = nil
    @State private var selectedExportType: ExportType? = nil

    @StateObject var promptManager: PromptManager
    @StateObject private var errorHandler = ErrorHandler()

    @AppStorage("sortOrder") private var sortOrder: SortOrder = .updateTime
    @AppStorage("sessionName") private var sessionName: String = ""
    @AppStorage("selectedName") var selectedName: String = ""
    @AppStorage("selectedSessionID") private var selectedSessionID: String?

    var filteredSessions: [ChatSession] {
        let filtered: [ChatSession]
        
        if searchText.isEmpty {
            filtered = Array(chatSessions)
        } else {
            filtered = chatSessions.filter { session in
                let sessionName = session.name?.lowercased() ?? ""
                return sessionName.contains(searchText.lowercased())
            }
        }
        
        let sortedSessions: [ChatSession]
        switch sortOrder {
        case .alphabetical:
            sortedSessions = filtered.sorted { $0.name?.lowercased() ?? "" < $1.name?.lowercased() ?? "" }
        case .updateTime:
            sortedSessions = filtered.sorted { $0.timestamp ?? Date() > $1.timestamp ?? Date() }
        case .off:
            sortedSessions = filtered
        }
        
        return sortByFavorites ? sortedSessions.filter { $0.isFavorite } : sortedSessions
    }
    
    var body: some View {
        
        let impactGenerator = UIImpactFeedbackGenerator(style: .heavy)

        NavigationStack {
            VStack {
                SearchBar(text: $searchText)
                    .padding(.horizontal)
                List {
                    ForEach(filteredSessions, id: \.self) { session in
                        ChatSessionRow(
                            session: session,
                            lastMessage: getLastMessage(session) ?? "",
                            lastMessageTimestamp: getLastTimestamp(session),
                            promptName: session.promptName ?? "",
                            selectedSessionID: $selectedSessionID)
                        .swipeActions(edge: .leading, allowsFullSwipe: !session.isLocked) {
                            if !session.isLocked {
                                Button(action: {
                                    session.isFavorite.toggle()
                                    saveContext()
                                }) {
                                    Label(
                                        session.isFavorite ? "Unfavorite" : "Favorite",
                                        systemImage: session.isFavorite ? "star.slash.fill" : "star.fill")
                                }
                                .tint(.yellow)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: !session.isLocked) {
                            if !session.isLocked {
                                Button(role: .destructive) {
                                    sessionToDelete = session
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                        }
                        .contextMenu {
                            Button(action: {
                                showExportSheet = session
                            }) {
                                Label("Export", systemImage: "square.and.arrow.up")
                            }
                            Button(action: {
                                session.isFavorite.toggle()
                                saveContext()
                            }) {
                                Label(
                                    session.isFavorite ? "Unfavorite" : "Favorite",
                                    systemImage: session.isFavorite ? "star.slash.fill" : "star.fill")
                            }
                            if !session.isLocked {
                                Button(action: {
                                    editSession(session)
                                }) {
                                    Label("Edit Name", systemImage: "pencil")
                                }
                            }
                            Button(action: {
                                sessionToDelete = session
                                showingDeleteAlert = true
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                            .foregroundColor(.red)
                            Button(action: {
                                session.isLocked.toggle()
                                saveContext()
                            }) {
                                Label(
                                    session.isLocked ? "Unlock" : "Lock",
                                    systemImage: session.isLocked ? "lock.open.fill" : "lock.fill")
                            }
                        }
                        .actionSheet(item: $showExportSheet) { session in
                            ActionSheet(
                                title: Text("Export Chat Session"),
                                message: Text("Select an export format"),
                                buttons: exportActionSheetButtons(session: session)
                            )
                        }
                        .onTapGesture {
                            if session.id != selectedSessionID {
                                selectedSessionID = session.id
                                saveContext()
                                onSessionSelected(session)
                                selectedSession = session
                            }
                            impactGenerator.impactOccurred()
                        }
                    }
                }
                .listStyle(GroupedListStyle())
                .alert(
                    "Delete Chat Session", isPresented: $showingDeleteAlert,
                    actions: {
                        Button(
                            "Cancel", role: .cancel,
                            action: {
                                showingDeleteAlert = false
                            })
                        Button(
                            "Delete", role: .destructive,
                            action: {
                                if let session = sessionToDelete {
                                    if session.id == selectedSessionID {
                                        selectedSessionID = nil
                                    }
                                    viewContext.delete(session)
                                    saveContext()
                                    sessionToDelete = nil
                                    showingDeleteAlert = false
                                }
                            })
                    },
                    message: {
                        Text("Are you sure you want to delete this chat session?")
                    }
                )
                .id(refreshViewID)
            }
            .onAppear {
                if let storedSortOrder = SortOrder(
                    rawValue: UserDefaults.standard.string(forKey: "sortOrder") ?? "")
                {
                    sortOrder = storedSortOrder
                }
                purgeEmptyChats()
                refreshViewID = UUID()
                if let selectedSession = chatSessions.first(where: { $0.id == selectedSessionID }) {
                     selectedName = selectedSession.promptName ?? ""
                }
            }
            .onChange(of: selectedSessionID) { newValue in
                selectedSession = chatSessions.first(where: { $0.id == newValue })
                if let session = selectedSession {
                    selectedName = session.promptName ?? ""
                }
            }
        }
        .navigationTitle("Chat Sessions")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(
                    action: {
                        showAlert(title: "New Chat Session", message: "", onSave: createSession)
                    },
                    label: {
                        Label("Create Session", systemImage: "plus")
                    })
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        sortOrder = sortOrder == .alphabetical ? .off : .alphabetical
                    }) {
                        Label("Alphabetical", systemImage: "abc")
                            .foregroundColor(sortOrder == .alphabetical ? .blue : .primary)
                    }
                    Button(action: {
                        sortOrder = sortOrder == .updateTime ? .off : .updateTime
                    }) {
                        Label("Last Update", systemImage: "clock")
                            .foregroundColor(sortOrder == .updateTime ? .blue : .primary)
                    }
                    Button(action: {
                        sortByFavorites.toggle()
                    }) {
                        Label("Favorites", systemImage: "star.fill")
                            .foregroundColor(sortByFavorites ? .blue : .primary)
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
            }
        }
    }
    
    func fetchChatHistory(from chatSession: ChatSession) -> [ExportChat] {
        guard let chatSet = chatSession.messages as? Set<ChatMessage> else {
            debugPrint("Failed to fetch chat history from chat session: \(chatSession)")
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

    func sanitizeFileName(_ name: String) -> String {
        // Remove all special characters and spaces
        var sanitized = name
            .replacingOccurrences(of: " ", with: "") // Remove spaces
            .replacingOccurrences(of: "[^a-zA-Z0-9]", with: "", options: .regularExpression) // Remove special characters

        // If the name is "Select a prompt ->" or if sanitizing the name has left it empty, use a default value.
        if name == "Select a prompt ->" || sanitized.isEmpty {
            sanitized = "ChatSession"
        }

        return sanitized
    }

    func exportActionSheetButtons(session: ChatSession) -> [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = ExportType.allCases.map { type in
                .default(Text(type.rawValue.uppercased())) {
                let exportData: Data?
                var fileName: String
                
                let chatHistory = fetchChatHistory(from: session)

                // Sanitize file name
                let sessionName = sanitizeFileName(session.name ?? "")
                let promptName = sanitizeFileName(session.promptName ?? "")

                switch type {
                case .json:
                    exportData = exportChatHistoryAsJSON(chatHistory)
                    fileName = "\(promptName).\(sessionName).json"
                case .csv:
                    exportData = exportChatHistoryAsCSV(chatHistory)
                    fileName = "\(promptName).\(sessionName).csv"
                }

                if let data = exportData {
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                    do {
                        try data.write(to: tempURL, options: .atomicWrite)
                        let activityViewController = UIActivityViewController(
                            activityItems: [tempURL],
                            applicationActivities: nil
                        )
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            scene.windows.first?.rootViewController?.present(
                                activityViewController, animated: true, completion: nil
                            )
                        }
                    } catch {
                        debugPrint("Failed to write export data to file: \(error)")
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

        do {
            let jsonData = try encoder.encode(chatHistory)
            return jsonData
        } catch {
            debugPrint("Failed to export chat history as JSON: \(error)")
        }
        return nil
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
    
    private func editSession(_ session: ChatSession) {
        showAlert(
            title: "Edit Chat Name", message: session.name ?? "",
            onSave: { newName in
                session.name = newName
                saveContext()
            })
    }
    
    private func createSession(name: String) {
        let newSession = ChatSession(context: viewContext)
        newSession.name = name
        newSession.timestamp = Date()
        newSession.id = UUID().uuidString
        saveContext()
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
            if selectedSessionID == nil, let firstSession = filteredSessions.first {
                selectedSessionID = firstSession.id
            }
            
        } catch {
            errorHandler.handleError(error)
        }
    }
    
    private func purgeEmptyChats() {
        for session in chatSessions where session.messages?.count == 0 {
            viewContext.delete(session)
        }
        saveContext()
    }
    
    private func getLastMessage(_ session: ChatSession) -> String? {
        let messages = session.messages?.allObjects as? [ChatMessage]
        let lastMessage = messages?.max { a, b in a.timestamp ?? Date() < b.timestamp ?? Date() }
        return lastMessage?.message
    }

    private func getLastTimestamp(_ session: ChatSession) -> Date? {
        let messages = session.messages?.allObjects as? [ChatMessage]
        let lastMessage = messages?.max { a, b in a.timestamp ?? Date() < b.timestamp ?? Date() }
        return lastMessage?.timestamp
    }
        
    private func showAlert(title: String, message: String, onSave: @escaping (String) -> Void) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController
        else {
            return
        }
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addTextField { textField in
            textField.placeholder = "Chat Session Name"
        }
        let saveAction = UIAlertAction(title: "Save", style: .default) { _ in
            if let textField = alertController.textFields?.first, let text = textField.text {
                onSave(text)
            }
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alertController.addAction(saveAction)
        alertController.addAction(cancelAction)
        
        rootViewController.present(alertController, animated: true, completion: nil)
        
        if let sessionID = selectedSessionID {
            selectedSessionID = sessionID
        }
    }
}

struct SessionAlert: View {
    @Binding var isPresented: Bool
    @State private var sessionName: String
    let session: ChatSession?
    let onSave: (String) -> Void

    init(isPresented: Binding<Bool>, session: ChatSession? = nil, onSave: @escaping (String) -> Void) {
        self._isPresented = isPresented
        self.session = session
        _sessionName = State(initialValue: session?.name ?? "")
        self.onSave = onSave
    }

    var body: some View {
        VStack {
            TextField(session == nil ? "New Chat Session" : "Edit Chat Session", text: $sessionName)
            Button("Save") {
                onSave(sessionName)
                isPresented = false
            }
        }
        .padding()
    }
}

struct ChatSessionRow: View {
    let session: ChatSession
    let scale: CGFloat = 0.8
    let lastMessage: String?
    let lastMessageTimestamp: Date?
    let promptName: String?
    @Binding var selectedSessionID: String?

    var isSelected: Bool {
        selectedSessionID == session.id
    }
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .center, spacing: 4) {
                Image(systemName: isSelected ? "circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .scaleEffect(scale)
                Image(systemName: session.isFavorite ? "star.fill" : "star")
                    .foregroundColor(session.isFavorite ? .yellow : .gray)
                    .scaleEffect(scale)
                Image(systemName: session.isLocked ? "lock.fill" : "lock")
                    .foregroundColor(session.isLocked ? .red : .gray)
                    .scaleEffect(scale)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                Text(session.name ?? "")
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                    Spacer()
                    if let lastMessageTimestamp = lastMessageTimestamp {
                        Text(relativeDateTimeFormatter.localizedString(for: lastMessageTimestamp, relativeTo: Date()))
                            .font(.subheadline)
                            .lineLimit(1)
                            .foregroundColor(.gray)
                    }
                }
                Text(promptName ?? "")
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                Text(lastMessage ?? "")
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var relativeDateTimeFormatter: RelativeDateTimeFormatter {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .numeric
        formatter.unitsStyle = .full
        return formatter
    }
}
