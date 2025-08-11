import Foundation
import SwiftUI
import UIKit

struct DevPromptList: View {
    
    enum ActiveAlert {
        case export, delete
    }
    
    @EnvironmentObject private var viewModel: PromptManager
    @State var isNewPrompt: Bool = false
    @State private var isShareSheetShowing = false
    @State private var jsonData: String? = nil
    @State private var isDocumentPickerShowing = false
    @State private var activeAlert: ActiveAlert = .delete

    var body: some View {
        List {
            ForEach(viewModel.prompts, id: \.id) { promptData in
                DisclosureGroup(
                    content: {
                        Text(promptData.promptText)
                            .foregroundColor(.green)
                    },
                    label: {
                        Text(promptData.promptName)
                    }
                )
                .swipeActions(edge: .leading) {
                    Button(action: {
                        activeAlert = .delete
                        isShareSheetShowing = true
                        viewModel.showDeletionAlert(for: promptData)
                    }) {
                        Image(systemName: "trash")
                    }
                    .tint(.red)
                }
                .swipeActions(edge: .trailing) {
                    Button(action: {
                        viewModel.showEditPrompt(for: promptData)
                    }) {
                        Image(systemName: "pencil")
                    }
                    .tint(.blue)
                }
            }
        }
        .listStyle(GroupedListStyle())
        .navigationTitle("Prompt List")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarItems(trailing:
            HStack {
                Button(action: {
                    isDocumentPickerShowing = true
                }) {
                    Image(systemName: "tray.and.arrow.up.fill")
                }
                Button(action: {
                    activeAlert = .export
                    isShareSheetShowing = true
                    jsonData = viewModel.exportPromptsToJson()
                }) {
                    Image(systemName: "tray.and.arrow.down.fill")
                }
                Button(action: {
                    viewModel.addNewPrompt()
                }) {
                    Image(systemName: "plus")
                }
            }
        )
        .onAppear {
            viewModel.loadPromptList()
        }
        .sheet(isPresented: $viewModel.showEditPromptView) {
            EditPrompt(promptData: $viewModel.selectedPrompt, isNewPrompt: $isNewPrompt)
                .environmentObject(viewModel)
        }
        .alert(isPresented: $isShareSheetShowing) {
              switch activeAlert {
              case .delete:
                  return Alert(
                      title: Text("Delete Prompt"),
                      message: Text("Are you sure you want to delete this prompt?"),
                      primaryButton: .destructive(Text("Delete")) {
                          viewModel.deleteSelectedPrompt()
                      },
                      secondaryButton: .cancel()
                  )
              case .export:
                  if let data = jsonData {
                      return Alert(
                          title: Text("Export Prompts"),
                          message: Text("You are about to export the prompts data as JSON."),
                          primaryButton: .default(Text("Export")) {
                              shareJsonData(jsonData: data)
                          },
                          secondaryButton: .cancel()
                      )
                  } else {
                      return Alert(
                          title: Text("Export Failed"),
                          message: Text("Failed to export the prompts data as JSON.")
                      )
                  }
              }
          }
        .fileImporter(
             isPresented: $isDocumentPickerShowing,
             allowedContentTypes: [.json],
             allowsMultipleSelection: false
         ) { result in
             switch result {
             case .success(let urls):
                 guard let url = urls.first else { return }
                 importJsonFile(url: url)
             case .failure(let error):
                 debugPrint("Error importing JSON: \(error.localizedDescription)")
             }
         }
    }
    
    func shareJsonData(jsonData: String) {
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempFile = tempDirectory.appendingPathComponent("promptList.json")
        do {
            try jsonData.write(to: tempFile, atomically: true, encoding: .utf8)
            let activityVC = UIActivityViewController(activityItems: [tempFile], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.windows.first?.rootViewController?.present(activityVC, animated: true, completion: nil)
            }
        } catch {
            debugPrint("Failed to write JSON data to temporary file: \(error.localizedDescription)")
        }
    }
    
    private func importJsonFile(url: URL) {
        do {
            let jsonData = try String(contentsOf: url)
            showImportPromptOptions(jsonData: jsonData)
        } catch {
            debugPrint("Error reading JSON file: \(error.localizedDescription)")
        }
    }

    private func showImportPromptOptions(jsonData: String) {
        let alertController = UIAlertController(
            title: "Import Options",
            message: "Would you like to append or overwrite the existing data?",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Append", style: .default) { _ in
            viewModel.importPromptsFromJson(jsonData: jsonData, appendData: true)
        })
        alertController.addAction(UIAlertAction(title: "Overwrite", style: .destructive) { _ in
            viewModel.importPromptsFromJson(jsonData: jsonData, appendData: false)
        })
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.windows.first?.rootViewController?.present(alertController, animated: true)
        }
    }
}
