import SwiftUI
import CoreData

// MARK: - ViewModel
class TitleScreenViewModel: ObservableObject {
    @AppStorage("sessionName") var sessionName: String = ""
    @AppStorage("isLoggedIn") var isLoggedIn: Bool = true
    @AppStorage("selectedSessionID") var selectedSessionID: String?

    @Published var showDonationPage = false
    @Published var showAlert = false
    @Published var showUserSettings = false
    @Published var showLoginButton = false
    @Published var showLabels = false
}

// MARK: - AuthManager for Global Login State
class AuthManager: ObservableObject {
    @Published var isLoggedIn = true
}

// MARK: - Shadow Modifier
struct ShadowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: Color(red: 200 / 255, green: 200 / 255, blue: 255 / 255).opacity(0.5), radius: 5, x: -2, y: -2)
            .shadow(color: Color(red: 150 / 255, green: 150 / 255, blue: 255 / 255).opacity(0.5), radius: 5, x: 2, y: 2)
    }
}

extension View {
    func applyShadow() -> some View {
        self.modifier(ShadowModifier())
    }
}

// MARK: - TitleScreenView
struct TitleScreenView: View {
    @Environment(\.sizeCategory) private var sizeCategory
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var promptManager: PromptManager
    @EnvironmentObject private var openAI: OpenAIService
    @EnvironmentObject private var authManager: AuthManager

    @ScaledMetric private var imageSize: CGFloat = 70
    @ScaledMetric private var labelFontSize: CGFloat = 24
    @ScaledMetric private var toggleButtonSize: CGFloat = 30

    @StateObject private var errorHandler = ErrorHandler()
    @StateObject private var viewModel = TitleScreenViewModel()

    var body: some View {
        ZStack {
            NavigationStack {
                VStack(spacing: 2) {
                    titleText
                    navigationLinks
                    settingsAndButtons
                }
                .navigationBarTitle("Menu", displayMode: .inline)
                .onAppear {
                    promptManager.loadPromptList()
                }
            }
        }
        .alert(isPresented: $errorHandler.showAlert) {
            errorAlert
        }
    }

    // MARK: - Components
    private var titleText: some View {
        Text("Que Cat")
            .font(.custom("Chalkduster", size: 60))
            .foregroundColor(.primary)
            .opacity(0.8)
            .shadow(radius: 4)
    }

    private var navigationLinks: some View {
        VStack {
            HStack(spacing: 40) {
                titleLink(imageName: "plus.bubble.fill", label: "New",
                          destination: ContentView(session: ChatSession(), isCreatingNewSession: true)
                    .environmentObject(promptManager)
                    .environmentObject(openAI)
                    .environmentObject(errorHandler)
                    .environment(\.managedObjectContext, viewContext))
                titleLink(imageName: "ellipsis.bubble.fill", label: "Chat",
                          destination: ContentView(session: ChatSession(), isCreatingNewSession: false)
                    .environmentObject(promptManager)
                    .environmentObject(openAI)
                    .environmentObject(errorHandler)
                    .environment(\.managedObjectContext, viewContext))
            }

            HStack(spacing: 40) {
                titleLink(imageName: "folder.fill", label: "Archive",
                          destination: ChatSessionList(
                            onSessionSelected: { selectedSession in
                                viewModel.sessionName = selectedSession.name ?? ""
                            },
                            promptManager: PromptManager()
                        ).environment(\.managedObjectContext, viewContext)
                         .environmentObject(promptManager))
                titleLink(imageName: "text.badge.star", label: "Saved",
                          destination: AnswerList(answerData: AnswerEntity()))
            }

        }
    }

    private var settingsAndButtons: some View {
        VStack {
            HStack(spacing: 40) {
                titleLink(imageName: "gearshape.fill", label: "Settings",
                          destination: SettingsPage())
            }
            Spacer()
            HStack {
                Spacer()
                toggleButton()
                    .padding([.trailing, .bottom], horizontalSizeClass == .compact && verticalSizeClass == .compact ? 40 : 20)
            }
        }
    }

    private func titleLink<Destination: View>(imageName: String, label: String, destination: Destination) -> some View {
        NavigationLink(destination: destination) {
            VStack {
                Image(systemName: imageName)
                    .font(.system(size: imageSize))
                    .applyShadow()
                if viewModel.showLabels {
                    Text(label)
                        .font(.custom("Genos", size: labelFontSize))
                        .applyShadow()
                }
            }
            .padding(.top, 20)
        }
    }

    private func toggleButton() -> some View {
        Button(action: {
            withAnimation {
                viewModel.showLabels.toggle()
            }
        }) {
            Image(systemName: viewModel.showLabels ? "xmark.circle.fill" : "questionmark.circle.fill")
                .font(.custom("Genos", size: toggleButtonSize))
                .foregroundColor(.white)
                .padding(2)
                .background(Color.black.opacity(0))
                .clipShape(Circle())
                .applyShadow()
        }
    }

    private var errorAlert: Alert {
        Alert(title: Text("Error"),
              message: Text(errorHandler.errorMessage ?? ""),
              primaryButton: .default(Text("Send Error & Screenshot")) {
            errorHandler.sendErrorMessageWithScreenshot()
        },
              secondaryButton: .cancel())
    }
}
