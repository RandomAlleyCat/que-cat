import Foundation
import SwiftUI
import Combine
import CoreData

public class OpenAIService: ObservableObject {
    
    @AppStorage("adShown") var adShown: Bool = false
    @AppStorage("selectedName") var selectedName: String = ""
    @Published var assistantMessageUpdated = false
    public let streamingText = PassthroughSubject<String, Never>()
    private let systemMessage: Message
    private let apiKey: String
    private let viewContext: NSManagedObjectContext
    private let selectedPrompt: Prompt
    private let selectedSessionID: String
    private let urlSession = URLSession.shared
    private var urlRequest: URLRequest {
        var urlRequest = URLRequest(url: Network.url)
        urlRequest.httpMethod = "POST"
        headers.forEach {  urlRequest.setValue($1, forHTTPHeaderField: $0) }
        return urlRequest
    }
        
    private let jsonDecoder: JSONDecoder = {
        let jsonDecoder = JSONDecoder()
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
        return jsonDecoder
    }()
    
    private var headers: [String: String] {
        [
            "Content-Type": "application/json",
            "Authorization": "Bearer \(apiKey)"
        ]
    }
    
    init(apiKey: String, viewContext: NSManagedObjectContext, selectedPrompt: Prompt, selectedSessionID: String) {
        self.apiKey = apiKey
        self.selectedSessionID = selectedSessionID
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let dateTime = dateFormatter.string(from: Date())
        
        self.systemMessage = .init(role: "system", content: "The current date and time is \(dateTime). \(selectedPrompt.promptText)")
        self.viewContext = viewContext
        self.selectedPrompt = selectedPrompt
    }
    
    private func generateMessages(from text: String, maxTotalCharacters: Int? = nil) -> [Message] {
        var messages = [Message]()
        let maxChars = maxTotalCharacters ?? (selectedPrompt.max_tokens * 6)
        var currentTotalCharacters = systemMessage.content.count
        
        let fetchRequest: NSFetchRequest<ChatMessage> = ChatMessage.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "session.id == %@", selectedSessionID)
        
        do {
            let fetchedChatHistory = try viewContext.fetch(fetchRequest)
            for chatMessage in fetchedChatHistory.reversed() {
                let message = Message(role: chatMessage.role ?? "user", content: chatMessage.message ?? "")
                let messageCharacters = message.content.count
                
                if currentTotalCharacters + messageCharacters <= maxChars {
                    messages.insert(message, at: 0)
                    currentTotalCharacters += messageCharacters
                } else {
                    break
                }
            }
        } catch {
            debugPrint("Failed to fetch chat history: \(error)")
        }
        
        messages.insert(systemMessage, at: 0)
        debugPrint(maxChars)
        debugPrint(currentTotalCharacters)
        return messages
    }
    
    private func generateLogitBiasString() -> String {
        let logitBiasString = selectedPrompt.logit_bias.map { "\($0.token): \($0.bias)" }.joined(separator: ", ")
        return "{\(logitBiasString)}"
    }
    
    private func jsonBody(text: String, stream: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        var encodedData: Data

        if UserDefaults.standard.bool(forKey: "devMode") {
            let logit_bias_dictionary = Dictionary(uniqueKeysWithValues: selectedPrompt.logit_bias.map { ($0.token, ($0.bias)) })

            let request = Request(
                model: selectedPrompt.modelName,
                temperature: selectedPrompt.temperature,
                messages: generateMessages(from: text),
                max_tokens: selectedPrompt.max_tokens,
                presence_penalty: selectedPrompt.presence_penalty,
                frequency_penalty: selectedPrompt.frequency_penalty,
                logit_bias: logit_bias_dictionary,
                stop: selectedPrompt.stop,
                user: selectedPrompt.user,
                stream: stream)

            debugPrint(apiKey)
            debugPrint(request)
            encodedData = try encoder.encode(request)
        } else {
            let request = FreeRequest(
                promptName: selectedName,
                messages: generateMessages(from: text))
            debugPrint(apiKey)
            debugPrint(request)
            encodedData = try encoder.encode(request)
        }

        return encodedData
    }
    
    public func sendMessageStream(text: String) async throws -> AsyncThrowingStream<String, Error> {
        var urlRequest = self.urlRequest
        urlRequest.httpBody = try jsonBody(text: text)
        let url = UserDefaults.standard.bool(forKey: "devMode") ? Network.devUrl : Network.url
        urlRequest.url = url
        let (result, response) = try await urlSession.bytes(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw "Invalid response"
        }

        guard 200...299 ~= httpResponse.statusCode else {
            var errorText = ""
            for try await line in result.lines {
                errorText += line
            }
            if let data = errorText.data(using: .utf8), let errorResponse = try? jsonDecoder.decode(ErrorRootResponse.self, from: data).error {
                errorText = "\n\(errorResponse.message)"
            }
            throw "Bad Response: \(httpResponse.statusCode). \(errorText)"
        }

        if UserDefaults.standard.bool(forKey: "devMode") {
            return AsyncThrowingStream<String, Error> { continuation in
                Task(priority: .userInitiated) { [weak self] in
                    do {
                        for try await line in result.lines {
                            if line.hasPrefix("data: "),
                               let data = line.dropFirst(6).data(using: .utf8),
                               let response = try? self?.jsonDecoder.decode(StreamCompletionResponse.self, from: data),
                               let text = response.choices.first?.delta.content {
                                continuation.yield(text)
                            }
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            }
        } else {
            return AsyncThrowingStream<String, Error> { continuation in
                Task(priority: .userInitiated) { [weak self] in
                    do {
                        var serverResponseData = Data()
                        for try await chunk in result {
                            serverResponseData.append(chunk)
                        }
                        if let serverResponse = try? self?.jsonDecoder.decode(ServerResponse.self, from: serverResponseData) {
                            continuation.yield(serverResponse.response)
                        }
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            }
        }
    }
}

struct ServerResponse: Decodable {
    let response: String
}

extension String: @retroactive Error {}
extension String: @retroactive CustomNSError {
    
    public var errorUserInfo: [String : Any] {
        [
            NSLocalizedDescriptionKey: self
        ]
    }
}

struct Network {
    static let url = URL(string: "https://qcs.majesticav.com/")!
    static let devUrl = URL(string: "https://api.openai.com/v1/chat/completions")!
    static let apiKey = UserDefaults.standard.string(forKey: "devKey") ?? ""

    static func getApiKey() -> String {
        let devMode = UserDefaults.standard.bool(forKey: "devMode")
        let devKey = UserDefaults.standard.string(forKey: "devKey") ?? ""
        return devMode ? devKey : apiKey
    }
}
