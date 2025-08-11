import UIKit
import SwiftUI
import Combine
import CoreData
import Foundation

struct ContentView: View {
    
    let session: ChatSession

    @EnvironmentObject private var promptManager: PromptManager
    @EnvironmentObject private var openAI: OpenAIService
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode
    
    var onSave: ((ChatMessage) -> Void)?
    var onDelete: ((ChatMessage) -> Void)?
    
    @StateObject private var navBarState = NavigationBarState()
    @StateObject private var errorHandler = ErrorHandler()
    @State private var showingAnswerSavedAlert: Bool = false
    @State private var selectedMessage: ChatMessage? = nil
    @State private var showDeleteAlert: Bool = false
    @State private var showClearChatAlert: Bool = false
    @State private var showPromptAlert: Bool = false
    @State private var includeQuestion = true
    @State private var showShareSheet = false
    @State var isCreatingNewSession: Bool
    @State private var isLoading: Bool = false
    @State private var editedMessage: String? = nil

    @AppStorage("userText") var userText: String = ""
    @AppStorage("selectedName") var selectedName: String = ""
    @AppStorage("selectedIndex") var selectedIndex: Int = 0
    @AppStorage("devMode") private var devMode: Bool = false
    @AppStorage("devPrompts") private var devPrompts: Data = Data()
    @AppStorage("selectedSessionID") private var selectedSessionID: String?
    @AppStorage("experimentalPrompts") var experimentalPrompts = false
    @AppStorage("questionPic") var questionPic: String = ""
    @AppStorage("answerPic") var answerPic: String = ""
    
    @FetchRequest(fetchRequest: chatSessionFetchRequest())
    var chatSessions: FetchedResults<ChatSession>

    static func chatSessionFetchRequest() -> NSFetchRequest<ChatSession> {
        let request = NSFetchRequest<ChatSession>(entityName: "ChatSession")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChatSession.timestamp, ascending: false)]
        if let selectedSessionID = UserDefaults.standard.string(forKey: "selectedSessionID") {
            request.predicate = NSPredicate(format: "id == %@", selectedSessionID)
        }
        request.fetchLimit = 1
        return request
    }
    
    private var navigationBarTitle: String {
        return chatSession?.name ?? "Chat"
    }
    var chatSession: ChatSession? {
        return chatSessions.first
    }

    @FetchRequest(
        entity: ChatMessage.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \ChatMessage.timestamp, ascending: true)],
        predicate: chatMessagesPredicate())
    var chatMessages: FetchedResults<ChatMessage>

    static func chatMessagesPredicate() -> NSPredicate? {
        if let selectedSessionID = UserDefaults.standard.string(forKey: "selectedSessionID") {
            return NSPredicate(format: "session.id == %@", selectedSessionID)
        }
        return nil
    }
    
    @FetchRequest(
        entity: AnswerEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \AnswerEntity.timestamp, ascending: true)],
        animation: .default)
    var answerList: FetchedResults<AnswerEntity>

    var body: some View {
        NavigationStack {
            VStack {
                ChatHistory(saveAnswer: saveAnswer, deleteMessage: deleteMessage, selectedMessage: $selectedMessage, isLoading: $isLoading, navigationBarState: navBarState, chatMessages: _chatMessages)
                MessageInputView(onSend: sendMessage, userText: userText, promptManager: promptManager)
            }
            .padding(.horizontal)
            .environmentObject(navBarState)
            .onTapGesture {
                selectedMessage = nil
            }
        }
        .navigationBarTitle(navigationBarTitle)
        .navigationBarItems(trailing: navigationBarItems)
        .onAppear {
            if isCreatingNewSession || selectedSessionID == nil {
                createNewChatSession()
                selectedName = ""
                selectedIndex = 0
            } else {
                if let session = chatSession {
                    selectedName = session.promptName ?? ""
                    promptManager.loadPromptList()
                    promptManager.updateSelectedPrompt(with: selectedName)
                }
                let _ = navigationBarTitle
            }
        }
        .onChange(of: selectedName) { _ in
            promptManager.loadPromptList()
            promptManager.updateSelectedPrompt(with: selectedName)
        }
        .alert(isPresented: $showingAnswerSavedAlert) {
            Alert(
                title: Text("Message Saved"),
                message: Text("The answer has been saved and can be shared from the Shared page."),
                primaryButton: .default(Text("Share Now"), action: {
                    showIncludeQuestionAlert()
                }),
                secondaryButton: .default(Text("Ok"))
            )
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [exportImage(includeQuestion: includeQuestion)].compactMap { $0 })
        }
    }
    
    private func sendMessage(_ text: String) {
        guard !text.isEmpty, let chatSession = chatSession else { return }

        let userMessage = ChatMessage(context: viewContext)
        userMessage.session = chatSession
        userMessage.role = "user"
        userMessage.message = text
        userMessage.timestamp = Date()

        Task {
            do {
                isLoading = true
                try viewContext.save()
                let stream = try await openAI.sendMessageStream(text: text)
                var assistantMessage = ""

                let assistantMessageEntity = ChatMessage(context: viewContext)
                assistantMessageEntity.session = chatSession
                assistantMessageEntity.role = "assistant"
                assistantMessageEntity.message = ""
                assistantMessageEntity.timestamp = Date()

                let impactGenerator = UIImpactFeedbackGenerator(style: .soft)
                isLoading = false

                for try await message in stream {
                    assistantMessage.append(message)
                    assistantMessageEntity.message = assistantMessage
                    try viewContext.save()
                    NotificationCenter.default.post(name: .assistantMessageUpdated, object: nil)
                    
                    impactGenerator.impactOccurred()

                }
            } catch {
                errorHandler.handleError(error)
                userText = userMessage.message ?? ""
                viewContext.delete(userMessage)
                try? viewContext.save()
                isLoading = false
            }
        }
    }
    
    private func updateChatSession() {
        guard let sessionId = selectedSessionID,
              let session = fetchChatSession(id: sessionId) else { return }

        session.promptName = selectedName

        do {
            try viewContext.save()
        } catch {
            debugPrint("Error updating ChatSession: \(error)")
        }
    }

    private func fetchChatSession(id: String) -> ChatSession? {
        let request: NSFetchRequest<ChatSession> = ChatSession.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1

        do {
            let sessions = try viewContext.fetch(request)
            return sessions.first
        } catch {
            errorHandler.handleError(error)
            return nil
        }
    }
    
    private func showIncludeQuestionAlert() {
        let alertController = UIAlertController(
            title: "Include User Message?",
            message: "Do you want to include the user message when sharing?",
            preferredStyle: .alert
        )
        
        alertController.addAction(UIAlertAction(title: "Yes", style: .default) { _ in
            includeQuestion = true
            showShareSheet = true
        })
        
        alertController.addAction(UIAlertAction(title: "No", style: .default) { _ in
            UserDefaults.standard.set("", forKey: "questionPic")
            includeQuestion = false
            showShareSheet = true
        })
        
        UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .map { $0 as? UIWindowScene }
            .compactMap { $0 }
            .first?.windows.first?.rootViewController?
            .present(alertController, animated: true, completion: nil)
    }
    
    var saveAnswerButton: some View {
        Button(action: {
            if let assistantMessage = selectedMessage, assistantMessage.role == "assistant" {
                onSave?(assistantMessage)
            }
        }) {
            Label("Save Message", systemImage: "square.and.arrow.down")
        }
        .disabled(selectedMessage?.role != "assistant")
    }
    
    private func saveAnswer(assistantMessage: ChatMessage) {
 
        guard let index = chatMessages.firstIndex(of: assistantMessage), index > 0 else { return }
        let userMessage = chatMessages[index - 1]
        let answerEntity = AnswerEntity(context: viewContext)
        
        answerEntity.id = UUID()
        answerEntity.name = selectedName
        answerEntity.question = userMessage.message ?? ""
        answerEntity.answer = assistantMessage.message ?? ""
        answerEntity.timestamp = assistantMessage.timestamp ?? Date()
        questionPic = answerEntity.question ?? ""
        answerPic = answerEntity.answer ?? ""

        do {
            try viewContext.save()
            showingAnswerSavedAlert = true
        } catch {
            debugPrint("Error saving answer: \(error.localizedDescription)")
        }
    }
    
    private func getPreviousUserMessage(from systemMessage: ChatMessage) -> ChatMessage? {
        let index = chatMessages.firstIndex(of: systemMessage) ?? 0
        if index > 0 {
            let previousMessageIndex = index - 1
            let previousMessage = chatMessages[previousMessageIndex]
            if previousMessage.role == "user" {
                return previousMessage
            }
        }
        return nil
    }
    
    private var navigationBarItems: some View {
        HStack {
            promptListMenu
            clearChatHistoryButton
        }
    }
    
    private func deleteMessage(_ message: ChatMessage) {
        if let previousUserMessage = getPreviousUserMessage(from: message) {
            userText = previousUserMessage.message ?? ""
            viewContext.delete(previousUserMessage)
        }
        viewContext.delete(message)
        try? viewContext.save()
    }

    private func createNewChatSession() {
        let chatSession = ChatSession(context: viewContext)
        chatSession.name = "Select a prompt ->"
        chatSession.timestamp = Date()
        chatSession.id = UUID().uuidString

        do {
            try viewContext.save()
            selectedSessionID = chatSession.id
            presentationMode.wrappedValue.dismiss()
        } catch {
            debugPrint("Error creating new chat session: \(error.localizedDescription)")
        }
    }
    
    private var promptListMenu: some View {
        Menu {
            ForEach(promptManager.prompts.indices, id: \.self) { index in
                Button(action: {
                    selectedName = promptManager.prompts[index].promptName
                    updateChatSession()

                    if isCreatingNewSession {
                        chatSession?.name = promptManager.selectedPrompt.promptName
                        isCreatingNewSession = false
                    }
                }) {
                    Text(promptManager.prompts[index].promptName)
                }
            }
        } label: {
            Image(systemName: "list.bullet")
        }
        .menuStyle(DefaultMenuStyle())
        .alert(isPresented: $showPromptAlert) {
            Alert(
                title: Text("Empty Prompt List"),
                message: Text("Please add a prompt to the list in the Developer settings or disable Dev Mode."),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func getMessageToEdit() -> ChatMessage? {
        return selectedMessage
    }
    
    private var clearChatHistoryButton: some View {
        Button(action: {
            showClearChatAlert = true
        }) {
            Label("Clear Chat History", systemImage: "trash")
        }
        .alert(isPresented: $showClearChatAlert) {
            Alert(title: Text("Clear Chat History"), message: Text("Are you sure you want to clear the chat history? This cannot be undone!"), primaryButton: .destructive(Text("Clear")) {
                clearChatHistory()
            }, secondaryButton: .cancel())
        }
    }
    
    private func clearChatHistory() {
        guard let selectedSessionID = selectedSessionID else { return }

        let fetchRequest: NSFetchRequest<ChatMessage> = ChatMessage.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "session.id == %@", selectedSessionID)
        
        do {
            let chatMessages = try viewContext.fetch(fetchRequest)
            for message in chatMessages {
                viewContext.delete(message)
            }
            try viewContext.save()
        } catch {
            debugPrint("Error deleting chat history: \(error.localizedDescription)")
        }
    }
}

extension Notification.Name {
    static let assistantMessageUpdated = Notification.Name("assistantMessageUpdated")
}
