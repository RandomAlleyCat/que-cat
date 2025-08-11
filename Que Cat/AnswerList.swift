import SwiftUI
import CoreData

struct CoreDataController {
    var context: NSManagedObjectContext

    func saveContext() -> Result<Void, Error> {
        do {
            try context.save()
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    func delete(_ object: NSManagedObject) -> Result<Void, Error> {
        context.delete(object)
        return saveContext()
    }
}

struct AnswerList: View {
    let answerData: AnswerEntity

    @Environment(\.managedObjectContext) private var viewContext

    private var coreDataController: CoreDataController {
        CoreDataController(context: viewContext)
    }

    @FetchRequest(
        entity: AnswerEntity.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \AnswerEntity.timestamp, ascending: false)],
        animation: .default)
    var answerList: FetchedResults<AnswerEntity>
    
    @AppStorage("searchText") private var searchText = ""
    @State private var isShowingDeleteAlert = false

    var filteredAnswers: [AnswerEntity] {
        if searchText.isEmpty {
            return Array(answerList)
        } else {
            return answerList.filter { answer in
                let question = answer.question?.lowercased() ?? ""
                let answerText = answer.answer?.lowercased() ?? ""
                return question.contains(searchText.lowercased()) || answerText.contains(searchText.lowercased())
            }
        }
    }

    @State private var selectedAnswer: AnswerEntity?
    
    var body: some View {
        VStack {
            SearchBar(text: $searchText)
                .padding(.horizontal)
            List {
                ForEach(filteredAnswers) { answer in
                    NavigationLink(destination: DetailView(answerData: answer)) {
                        AnswerRow(answer: answer)
                    }
                    .swipeActions {
                        Button(role: .destructive, action: {
                            selectedAnswer = answer
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .alert(item: $selectedAnswer) { answerToBeDeleted in
                        Alert(
                            title: Text("Delete Message"),
                            message: Text("Are you sure you want to delete this message?"),
                            primaryButton: .destructive(Text("Delete")) {
                                deleteAnswerData(answerToBeDeleted)
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .navigationTitle("Saved Messages")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func deleteAnswerData(_ answer: AnswerEntity) {
        switch coreDataController.delete(answer) {
        case .success:
            debugPrint("Delete successful")
        case .failure(let error):
            debugPrint("Failed to delete: \(error)")
        }
    }
}

struct AnswerRow: View {
    let answer: AnswerEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .top) {
                Text(answer.name ?? "")
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundColor(answer.read == false ? Color.blue : Color.primary)
                Spacer()
                Text(timestampText(for: answer.timestamp))
                    .font(.footnote)
                    .foregroundColor(.gray)
            }
            Text(answer.question ?? "")
                .font(.subheadline)
                .lineLimit(1)
                .foregroundColor(.primary)
            Text(answer.answer ?? "")
                .font(.subheadline)
                .lineLimit(2)
                .foregroundColor(.gray)
        }
    }

    private func timestampText(for date: Date?) -> String {
        guard let date = date else { return "" }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct DetailView: View {
    let answerData: AnswerEntity
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode

    private var coreDataController: CoreDataController {
        CoreDataController(context: viewContext)
    }

    @State private var showDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(answerData.name ?? "")
                    .font(.title)
                    .fontWeight(.bold)

                Text(answerData.question ?? "")
                    .font(.title2)

                Text(answerData.answer ?? "")
                    .font(.body)
                    .foregroundColor(.green)

                Spacer()
            }
            .padding()
        }
        .navigationBarTitle("Message Details", displayMode: .inline)
        .navigationBarItems(trailing: HStack {
            ShareButton(answerData: answerData)
            DeleteAlerts(answerData: answerData, deleteAction: deleteAnswerData)
        })
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("Delete Message"),
                message: Text("Are you sure you want to delete this message?"),
                primaryButton: .destructive(Text("Delete")) {
                    deleteAnswerData()
                    presentationMode.wrappedValue.dismiss()
                },
                secondaryButton: .cancel()
            )
        }
        .onAppear {
            markAsRead()
        }
    }

    private func markAsRead() {
        answerData.read = true
        saveContext()
    }

    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            let error = error as NSError
            fatalError("Unresolved error \(error), \(error.userInfo)")
        }
    }
    
    private func deleteAnswerData() {
        switch coreDataController.delete(answerData) {
        case .success:
            presentationMode.wrappedValue.dismiss()
        case .failure(let error):
            // show an alert with the error
            debugPrint("Failed to delete: \(error)")
        }
    }
}

struct ShareButton: View {
    let answerData: AnswerEntity
    @State var includeQuestion = true
    @State var showIncludeQuestionAlert = false
    @State var showShareSheet = false

    var body: some View {
        Button(action: {
            showIncludeQuestionAlert = true
        }) {
            Image(systemName: "square.and.arrow.up")
        }
        .tint(.blue)
        .alert(isPresented: $showIncludeQuestionAlert) {
            Alert(title: Text("Include User Message?"),
                  message: Text("Do you want to include the user message when sharing?"),
                  primaryButton: .default(Text("Yes"), action: {
                      includeQuestion = true
                      shareAssistantMessage(answerData)
                  }),
                  secondaryButton: .default(Text("No"), action: {
                      includeQuestion = false
                      shareAssistantMessage(answerData)
                  }))
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [exportImage(includeQuestion: includeQuestion)].compactMap { $0 })
        }
    }

    func shareAssistantMessage(_ assistantMessage: AnswerEntity) {
        let question = includeQuestion ? assistantMessage.question ?? "" : ""
        let answer = assistantMessage.answer ?? ""
        UserDefaults.standard.set(question, forKey: "questionPic")
        UserDefaults.standard.set(answer, forKey: "answerPic")
        showShareSheet = true
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct DeleteAlerts: View {
    let answerData: AnswerEntity
    let deleteAction: () -> Void
    
    @State private var isShowingDeleteAlert = false
    @Environment(\.presentationMode) private var presentationMode
    @Environment(\.managedObjectContext) private var viewContext

    private var coreDataController: CoreDataController {
        CoreDataController(context: viewContext)
    }

    var body: some View {
        Button(action: {
            isShowingDeleteAlert = true
        }) {
            Image(systemName: "trash")
        }
        .tint(.red)
        .alert(isPresented: $isShowingDeleteAlert) {
            Alert(
                title: Text("Delete Message"),
                message: Text("Are you sure you want to delete this message?"),
                primaryButton: .destructive(Text("Delete")) {
                    deleteAnswerData()
                    presentationMode.wrappedValue.dismiss()
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private func saveContext() {
        do {
            try viewContext.save()
        } catch {
            let error = error as NSError
            fatalError("Unresolved error \(error), \(error.userInfo)")
        }
    }
    
    private func deleteAnswerData() {
        switch coreDataController.delete(answerData) {
        case .success:
            presentationMode.wrappedValue.dismiss()
        case .failure(let error):
            debugPrint("Failed to delete: \(error)")
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    @State private var isEditing = false
    
    var body: some View {
        HStack {
            TextField("Search", text: $text)
                .padding(7)
                .padding(.horizontal, 25)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 8)
                        if isEditing {
                            Button(action: {
                                text = ""
                                isEditing = false
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }) {
                                Image(systemName: "multiply.circle.fill")
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 8)
                            }
                        }
                    }
                )
                .onTapGesture {
                    withAnimation {
                        isEditing = true
                    }
                }
            if isEditing {
                EmptyView()
                    .transition(.move(edge: .trailing))
                    .animation(.easeInOut, value: isEditing) // use the new animation(_:value:) method
            }
        }
    }
}
