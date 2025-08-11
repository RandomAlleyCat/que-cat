import SwiftUI
import CoreData

enum ChatRole: String {
    case assistant
    case system
    case user
}

struct ChatHistory: View {

    @State private var isEditingMessage = false
    @State private var showingDeleteAlert = false
    @State private var messageToDelete: ChatMessage?
    @State private var isEditingMessageSheetPresented = false
    @State private var messageToEdit: ChatMessage?

    let saveAnswer: (ChatMessage) -> Void
    let deleteMessage: (ChatMessage) -> Void
   
    @Binding var selectedMessage: ChatMessage?
    @Binding var isLoading: Bool
    
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.colorScheme) private var colorScheme
    
    @ObservedObject var navigationBarState: NavigationBarState

    @FetchRequest(sortDescriptors: []) var chatMessages: FetchedResults<ChatMessage>

    var body: some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(chatMessages, id: \.self) { message in
                        chatBubble(chatMessage: message)
                            .onReceive(NotificationCenter.default.publisher(for: .assistantMessageUpdated)) { _ in
                                DispatchQueue.main.async {
                                    scrollToLatestMessage(scrollProxy, message: message)
                                }
                            }
                    }
                    if isLoading {
                        AnimatedEllipsis()
                    }
                }
            }
            .onAppear {
                if let latestMessage = chatMessages.last {
                    scrollToLatestMessage(scrollProxy, message: latestMessage)
                }
            }
            .onChange(of: chatMessages.last, perform: { latestMessage in
                if let latestMessage = latestMessage {
                    scrollToLatestMessage(scrollProxy, message: latestMessage)
                }
            })
        }
        .sheet(item: $messageToEdit) { messageToEdit in
            EditMessageView(message: messageToEdit.message ?? "", onSave: updateMessage)
        }
    }

    private func scrollToLatestMessage(_ proxy: ScrollViewProxy, message: ChatMessage) {
        withAnimation {
            proxy.scrollTo(message, anchor: .bottom)
        }
    }

    private func editMessage(_ message: ChatMessage) {
        self.messageToEdit = message
        self.isEditingMessageSheetPresented = true
    }

    private func updateMessage(newMessage: String) {
        self.messageToEdit?.message = newMessage
        saveContext()
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            debugPrint("Failed to save context: \(error)")
        }
    }
    
    private func showAlert(title: String, message: String, onSave: @escaping (String) -> Void) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return
        }
        
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = "Enter your message"
            textField.textAlignment = .left
            textField.autocapitalizationType = .sentences
            textField.autocorrectionType = .yes
            textField.spellCheckingType = .yes
            textField.text = message
        }
        
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            guard let textField = alert.textFields?.first,
                  let newMessage = textField.text else {
                return
            }
            onSave(newMessage)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        rootViewController.present(alert, animated: true, completion: nil)
    }

    private func chatBubble(chatMessage: ChatMessage) -> some View {
        let codeBlockIndicator = "```"
        let messageSegments = chatMessage.message?.components(separatedBy: codeBlockIndicator) ?? []
        
        let trimmedMessageSegments = messageSegments.enumerated().filter { (index, segment) in
            let trimmedSegment = segment.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmedSegment.isEmpty
        }
        
        return HStack {
            if chatMessage.role == ChatRole.assistant.rawValue {
                VStack(alignment: .leading) {
                    ForEach(trimmedMessageSegments, id: \.offset) { (index, segment) in
                        let isCodeBlock = index % 2 != 0
                        let trimmedSegment = segment.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        Text(trimmedSegment)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: isCodeBlock ? 4 : 16, style: .continuous)
                                    .fill(isCodeBlock ? Color(uiColor: .systemGray4) : Color(uiColor: .systemGray6))
                            )
                            .font(.system(size: isCodeBlock ? 14 : 17, design: isCodeBlock ? .monospaced : .default))
                            .foregroundColor(.primary)
                    }
                }
                Spacer()
            } else if chatMessage.role == ChatRole.system.rawValue {
                Spacer()
                VStack {
                    Text(chatMessage.message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
                        .padding(8)
                        .background(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .foregroundColor(.white)
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        deleteMessage(chatMessage)
                    }
                }
                Spacer()
            } else {
                Spacer()
                VStack(alignment: .trailing) {
                    if let url = URL(string: chatMessage.message ?? ""), url.isImageURL() {
                        ImageMessageView(url: chatMessage.message ?? "")
                            .frame(width: 400, height: 200) // Adjust this as needed
                    } else {
                        Text(chatMessage.message?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.blue)
                            )
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .contextMenu {
            if chatMessage.role == ChatRole.assistant.rawValue {
                Button(action: {
                    editMessage(chatMessage)
                }) {
                    Label("Edit Message", systemImage: "pencil")
                }
                Button(action: {
                    saveAnswer(chatMessage)
                }) {
                    Label("Save Message", systemImage: "square.and.arrow.down")
                }
                Button(action: {
                    UIPasteboard.general.string = chatMessage.message
                }) {
                    Label("Copy Message", systemImage: "doc.on.doc")
                }
                if !navigationBarState.deletionMode {
                    Button(action: {
                        showingDeleteAlert = true
                        messageToDelete = chatMessage
                    }) {
                        Label("Delete Message", systemImage: "trash")
                    }
                    .tint(.red)
                }
            } else if chatMessage.role == ChatRole.user.rawValue {
                Button(action: {
                    editMessage(chatMessage)
                }) {
                    Label("Edit Message", systemImage: "pencil")
                }
                Button(action: {
                    UIPasteboard.general.string = chatMessage.message
                }) {
                    Label("Copy Message", systemImage: "doc.on.doc")
                }
                if !navigationBarState.deletionMode {
                    Button(action: {
                        showingDeleteAlert = true
                        messageToDelete = chatMessage
                    }) {
                        Label("Delete Message", systemImage: "trash")
                    }
                    .tint(.red)
                }
            }
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(title: Text("Delete Message"), message: Text("Are you sure you want to delete this message? This action cannot be undone."), primaryButton: .destructive(Text("Delete")) {
                if let messageToDelete = messageToDelete {
                    deleteMessage(messageToDelete)
                }
            }, secondaryButton: .cancel())
        }
    }
}

class NavigationBarState: ObservableObject {
    @Published var deletionMode: Bool = false
}

struct AnimatedEllipsis: View {
    @State private var visibleDot = 0
    let maxDots = 3
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                HStack(spacing: 5) {
                    ForEach(0..<3) { dot in
                        Circle()
                            .fill(Color.primary)
                            .frame(width: 8, height: 8)
                            .opacity(dot == visibleDot ? 1 : 0.3)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(uiColor: .systemGray6))
                )
            }
            Spacer()
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut) {
                visibleDot = (visibleDot + 1) % (maxDots)
            }
        }
    }
}

struct EditMessageView: View {
    @Environment(\.presentationMode) var presentationMode
    @State var message: String
    let onSave: (String) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                if #available(iOS 16, *) {
                    TextField("Enter your message", text: $message, axis: .vertical)
                } else {
                    TextField("Enter your message", text: $message)
                }
            }
            .navigationBarTitle("Edit Message", displayMode: .inline)
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }, trailing: Button("Save") {
                onSave(message)
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    
    func load(from url: String) {
        guard let imageURL = URL(string: url) else {
            return
        }
        
        let task = URLSession.shared.dataTask(with: imageURL) { data, response, error in
            guard
                let data = data,
                let response = response as? HTTPURLResponse,
                response.statusCode == 200,
                let image = UIImage(data: data)
            else {
                return
            }
            
            DispatchQueue.main.async {
                self.image = image
            }
        }
        
        task.resume()
    }
}

struct ImageMessageView: View {
    @StateObject private var imageLoader = ImageLoader()
    let url: String

    var body: some View {
        Group {
            if imageLoader.image != nil {
                Image(uiImage: imageLoader.image!)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
        .onAppear {
            imageLoader.load(from: url)
        }
    }
}

extension URL {
    func isImageURL() -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "tiff", "bmp"]
        return imageExtensions.contains(self.pathExtension)
    }
}
