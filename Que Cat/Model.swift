import Foundation

struct Message: Codable {
    let role: String
    let content: String
}

struct ExportChat: Codable {
    let timestamp: Date
    let role: String
    let message: String
}

extension Array where Element == Message {
    
    var contentCount: Int { map { $0.content }.count }
}

struct Request: Encodable {
    let model: String
    let temperature: Double
    let messages: [Message]
    let max_tokens: Int
    let presence_penalty: Double
    let frequency_penalty: Double
    var logit_bias: [Int: Int]
    let stop: String
    let user: String
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model
        case temperature
        case messages
        case max_tokens
        case presence_penalty
        case frequency_penalty
        case logit_bias
        case stop
        case user
        case stream
    }
}


struct FreeRequest: Codable {
    let promptName: String
    let messages: [Message]
}

struct ErrorRootResponse: Decodable {
    let error: ErrorResponse
}

struct ErrorResponse: Decodable {
    let message: String
    let type: String?
}

struct StreamCompletionResponse: Decodable {
    let choices: [StreamChoice]
}

struct StreamChoice: Decodable {
    let finishReason: String?
    let delta: StreamMessage
}

struct StreamMessage: Decodable {
    let content: String?
    let role: String?
}

struct Prompt: Codable, Identifiable {
    var id: UUID = UUID()
    var promptName: String
    var promptText: String
    var modelName: String
    var temperature: Double
    var max_tokens: Int
    var presence_penalty: Double
    var frequency_penalty: Double
    var logit_bias: [LogitBias]
    var stop: String
    var user: String
    
    func tokens(forModel modelName: String) -> Int {
        switch modelName {
        case "gpt-3.5-turbo":
            return 4096
        case "gpt-4o-mini":
            return 8192
        case "gpt-4":
            return 8192
        case "gpt-4-turbo":
            return 8192
        case "gpt-4o":
            return 128000
        default:
            return 128000
        }
    }
}

struct RemotePrompt: Decodable {
    let promptName: String
    let promptText: String
    let modelName: String
    let temperature: Double
    let max_tokens: Int
    let presence_penalty: Double
    let frequency_penalty: Double
}

struct SafeCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

struct PartialPrompt: Decodable {
    var id: UUID = UUID()
    var promptName: String = ""
    var promptText: String = ""
    var modelName: String = ""
    var temperature: Double = 0
    var max_tokens: Int = 0
    var presence_penalty: Double = 0
    var frequency_penalty: Double = 0
    var logit_bias: [LogitBias] = []
    var stop: String = ""
    var user: String = ""
    
    enum CodingKeys: String, CodingKey {
        case id
        case promptName
        case promptText
        case modelName
        case temperature
        case max_tokens
        case presence_penalty
        case frequency_penalty
        case logit_bias
        case stop
        case user
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: SafeCodingKey.self)
        for key in container.allKeys {
            if let decodedKey = CodingKeys(stringValue: key.stringValue) {
                switch decodedKey {
                case .id:
                    if let decodedValue = try? container.decode(UUID.self, forKey: key) {
                        id = decodedValue
                    }
                case .promptName:
                    if let decodedValue = try? container.decode(String.self, forKey: key) {
                        promptName = decodedValue
                    }
                case .promptText:
                    if let decodedValue = try? container.decode(String.self, forKey: key) {
                        promptText = decodedValue
                    }
                case .modelName:
                    if let decodedValue = try? container.decode(String.self, forKey: key) {
                        modelName = decodedValue
                    }
                case .temperature:
                    if let decodedValue = try? container.decode(Double.self, forKey: key) {
                        temperature = decodedValue
                    }
                case .max_tokens:
                    if let decodedValue = try? container.decode(Int.self, forKey: key) {
                        max_tokens = decodedValue
                    }
                case .presence_penalty:
                    if let decodedValue = try? container.decode(Double.self, forKey: key) {
                        presence_penalty = decodedValue
                    }
                case .frequency_penalty:
                    if let decodedValue = try? container.decode(Double.self, forKey: key) {
                        frequency_penalty = decodedValue
                    }
                case .logit_bias:
                    if let decodedValue = try? container.decode([LogitBias].self, forKey: key) {
                        logit_bias = decodedValue
                    }
                case .stop:
                    if let decodedValue = try? container.decode(String.self, forKey: key) {
                        stop = decodedValue
                    }
                case .user:
                    if let decodedValue = try? container.decode(String.self, forKey: key) {
                        user = decodedValue
                    }
                }
            }
        }
    }
}
