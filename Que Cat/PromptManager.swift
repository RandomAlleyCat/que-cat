import Foundation
import SwiftUI
import CoreData

class PromptManager: ObservableObject {
    
    @Environment(\.managedObjectContext) private var context

    @State var isNewPrompt: Bool = false

    @AppStorage("devMode") private var devMode: Bool = false
    @AppStorage("devPrompts") private var devPrompts: Data = Data()
    @AppStorage("selectedName") var selectedName: String = ""
    @AppStorage("selectedIndex") var selectedIndex: Int = 0
    @AppStorage("experimentalPrompts") var experimentalPrompts = false
    @AppStorage("selectedSessionID") private var selectedSessionID: String?

    @Published var prompts: [Prompt] = []
    @Published var showAlert = false
    @Published var showEditPromptView = false
    @Published var selectedPrompt: Prompt = Prompt(promptName: "", promptText: "", modelName: "", temperature: 0, max_tokens: 0, presence_penalty: 0, frequency_penalty: 0, logit_bias: [], stop: "", user: "")
 
    func importPromptsFromJson(jsonData: String, appendData: Bool) {
        let decoder = JSONDecoder()
        do {
            var newPartialPrompts = try decoder.decode([PartialPrompt].self, from: Data(jsonData.utf8))
            
            for (index, _) in newPartialPrompts.enumerated() {
                // Check if id already exists
                while prompts.contains(where: { $0.id == newPartialPrompts[index].id }) {
                    // Generate a new id
                    newPartialPrompts[index].id = UUID()
                }

                // Check if name already exists and add an incremental suffix
                var suffix = 1
                while prompts.contains(where: { $0.promptName == newPartialPrompts[index].promptName + (suffix > 1 ? "_\(suffix)" : "") }) {
                    suffix += 1
                }
                if suffix > 1 {
                    newPartialPrompts[index].promptName = newPartialPrompts[index].promptName + "_\(suffix)"
                }
            }

            var newPrompts = [Prompt]()
            newPartialPrompts.forEach {
                let newPrompt = Prompt(id: $0.id, promptName: $0.promptName, promptText: $0.promptText, modelName: $0.modelName, temperature: $0.temperature, max_tokens: $0.max_tokens, presence_penalty: $0.presence_penalty, frequency_penalty: $0.frequency_penalty, logit_bias: $0.logit_bias, stop: $0.stop, user: $0.user)
                newPrompts.append(newPrompt)
            }
            
            if appendData {
                prompts += newPrompts
            } else {
                prompts = newPrompts
            }
            
            // Save imported prompts
            if let encodedPrompts = try? JSONEncoder().encode(prompts) {
                devPrompts = encodedPrompts
            }

        } catch {
            debugPrint("Failed to decode JSON to prompts: \(error.localizedDescription)")
        }
    }
    
    func exportPromptsToJson() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        do {
            let jsonData = try encoder.encode(prompts)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
        } catch {
            debugPrint("Failed to encode prompts to JSON: \(error.localizedDescription)")
        }
        return nil
    }

    private func fetchChatSession(id: String) -> ChatSession? {
        let request: NSFetchRequest<ChatSession> = ChatSession.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1

        do {
            let sessions = try context.fetch(request)
            return sessions.first
        } catch {
            debugPrint("Error fetching ChatSession: \(error)")
            return nil
        }
    }
    
    private func updateChatSession() {
        guard let sessionId = selectedSessionID,
              let session = fetchChatSession(id: sessionId) else { return }

        session.promptName = selectedName

        do {
            try context.save()
        } catch {
            debugPrint("Error updating ChatSession: \(error)")
        }
    }
    
    func loadPromptList() {
        if devMode {
            if let decodedPrompts = try? JSONDecoder().decode([Prompt].self, from: devPrompts) {
                prompts = decodedPrompts
            } else {
                prompts = []
            }
        } else {
            prompts = StaticPrompts.promptList
            if experimentalPrompts {
                prompts.append(contentsOf: StaticPrompts.expPromptList)
            }
        }
    }
    
    func updateSelectedPrompt(with promptName: String?) {

        guard let promptName = promptName else { return }
        
        if let index = prompts.firstIndex(where: { $0.promptName == promptName }) {
            selectedIndex = index
            selectedPrompt = prompts[index]
        } else {
            selectedIndex = -1
            selectedPrompt = Prompt(promptName: "", promptText: "", modelName: "", temperature: 0, max_tokens: 0, presence_penalty: 0, frequency_penalty: 0, logit_bias: [], stop: "", user: "")
        }
        selectedName = promptName
    }
    
    func saveSelectedPrompt() {
        if let index = prompts.firstIndex(where: { $0.id == selectedPrompt.id }) {
            prompts[index] = selectedPrompt
            do {
                devPrompts = try JSONEncoder().encode(prompts)
            } catch {
                debugPrint("Error encoding prompts: \(error)")
            }
        }
    }
    
    func deleteSelectedPrompt() {
        if let index = prompts.firstIndex(where: { $0.id == selectedPrompt.id }) {
            prompts.remove(at: index)
            do {
                devPrompts = try JSONEncoder().encode(prompts)
            } catch {
                debugPrint("Error encoding prompts: \(error)")
            }
        }
    }
    
    func addNewPrompt() {
        let newPrompt = Prompt(promptName: "", promptText: "", modelName: "gpt-5-nano", temperature: 0.5, max_tokens: 128000, presence_penalty: 0.0, frequency_penalty: 0.0, logit_bias: [], stop: "", user: "")
        prompts.append(newPrompt)
        selectedPrompt = newPrompt
        isNewPrompt = true
        showEditPromptView = true
    }
    
    func showEditPrompt(for promptData: Prompt) {
        selectedPrompt = promptData
        isNewPrompt = false
        withAnimation {
            showEditPromptView = true
        }
    }
    
    func showDeletionAlert(for promptData: Prompt) {
        selectedPrompt = promptData
        withAnimation {
            showAlert = true
        }
    }
    
    func savePrompt() {
        // As your selectedPrompt is @Published, updating it should
        // reflect the changes in your views automatically
        if isNewPrompt {
            addNewPrompt()
        } else {
            saveSelectedPrompt()
        }
    }

     // Discards any changes to the selectedPrompt
    func cancelEdit() {
        if isNewPrompt {
            deleteSelectedPrompt()
        } else {
            // If it's not a new prompt, re-fetch the original state of the prompt
            updateSelectedPrompt(with: selectedPrompt.promptName)
        }
    }
}
