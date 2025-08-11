import Foundation
import SwiftUI
import UIKit
import CoreData
import AuthenticationServices

@main
struct QueCatApp: App {
    @StateObject private var promptManager = PromptManager()
    @StateObject private var errorHandler = ErrorHandler()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    // Dependency injection for CoreData
    private let coreDataManager = CoreDataManager.shared

    var body: some Scene {
        WindowGroup {
            let selectedSessionID = UserDefaults.standard.string(forKey: "selectedSessionID") ?? ""

            TitleScreenView()
                .environmentObject(promptManager)
                .environmentObject(
                    OpenAIService(
                        apiKey: Network.getApiKey(),
                        viewContext: coreDataManager.viewContext,
                        selectedPrompt: promptManager.selectedPrompt,
                        selectedSessionID: selectedSessionID
                    )
                )
                .environment(\.managedObjectContext, coreDataManager.viewContext)
        }
    }
}

class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    // Shared persistent container
    lazy var persistentContainer: NSPersistentContainer = CoreDataManager.shared.persistentContainer

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        appleIDProvider.getCredentialState(forUserID: KeychainItem.currentUserIdentifier) { credentialState, error in
            switch credentialState {
            case .authorized:
                break // The Apple ID credential is valid.
            case .revoked, .notFound:
                // The Apple ID credential is either revoked or not found, show login.
                DispatchQueue.main.async {
                    self.window?.rootViewController?.showLoginViewController()
                }
            default:
                break
            }
        }
        return true
    }
}

// CoreDataManager: Centralized CoreData Handling
class CoreDataManager {
    static let shared = CoreDataManager()

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "ChatModel")
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        return container
    }()

    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    func saveContext() {
        if viewContext.hasChanges {
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

// CoreData PropertyWrapper for Cleaner Initialization
@propertyWrapper
struct CoreDataHandler<Entity: NSManagedObject> {
    var wrappedValue: Entity

    init(context: NSManagedObjectContext) {
        self.wrappedValue = Entity(context: context)
    }

    func save(context: NSManagedObjectContext) {
        do {
            try context.save()
        } catch {
            debugPrint("Error saving \(Entity.self): \(error.localizedDescription)")
        }
    }
}

// SceneDelegate for Older iOS Compatibility
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        let contentView = ContentView(session: ChatSession(), isCreatingNewSession: false)
            .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)

        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: contentView)
            self.window = window
            window.makeKeyAndVisible()
        }
    }
}
