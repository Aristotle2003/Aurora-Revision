import UIKit
import Firebase
import FirebaseMessaging
import FirebaseAuth
import UserNotifications
import GoogleSignIn

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("AppDelegate application entered")
        
        // Firebase configuration
        FirebaseApp.configure()
        
        // Set up Messaging delegate
        Messaging.messaging().delegate = self
        
        // Request authorization for notifications
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }
        
        // Check and store FCM token if the user is signed in
        Auth.auth().addStateDidChangeListener { auth, user in
            if let userID = user?.uid {
                self.fetchAndStoreFCMToken(for: userID)
            }
        }

        return true
    }
    
    // Handle device token registration with APNs
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // Set APNs token for Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
        print("APNs token registered with Firebase Messaging.")
        
        // Phone verification APNs token setup
        FirebaseManager.shared.auth.setAPNSToken(deviceToken, type: .sandbox)
    }
    
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification notification: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        if FirebaseManager.shared.auth.canHandleNotification(notification) {
            completionHandler(.noData)
            return
        }
    }
    
    // Google Sign-In URL handling
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
    
    // Refresh FCM token
    private func refreshFCMToken() {
        Messaging.messaging().deleteToken { error in
            if let error = error {
                print("Error deleting FCM token: \(error)")
            } else {
                print("FCM token deleted; refreshing token.")
                Messaging.messaging().token { token, error in
                    if let token = token {
                        print("New FCM token: \(token)")
                    } else if let error = error {
                        print("Error fetching new FCM token: \(error)")
                    }
                }
            }
        }
    }

    // Store FCM token to Firestore
    private func storeFCMTokenToFirestore(_ token: String, userID: String) {
        print("Storing FCM token to Firestore.")
        let userRef = Firestore.firestore().collection("users").document(userID)
        userRef.setData(["fcmToken": token], merge: true) { error in
            if let error = error {
                print("Error updating FCM token in Firestore: \(error)")
            } else {
                print("FCM token updated successfully in Firestore.")
            }
        }
    }

    // Called when a new FCM token is generated or refreshed
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        if let fcmToken = fcmToken, let userID = Auth.auth().currentUser?.uid {
            storeFCMTokenToFirestore(fcmToken, userID: userID)
        }
    }
    
    // Fetch and store FCM token for a signed-in user
    func fetchAndStoreFCMToken(for userID: String) {   
        Messaging.messaging().token { token, error in
            if let token = token {
                self.storeFCMTokenToFirestore(token, userID: userID)
                print("Fetched and stored FCM Token: \(token)")
            } else if let error = error {
                print("Error fetching FCM token: \(error)")
            }
        }
    }
}
