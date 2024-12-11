//
//  SynxApp.swift
//  Synx
//
//  Created by Shawn on 10/13/24.
//

import SwiftUI


//@main
//struct SynxApp: App {
//    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
//    var body: some Scene {
//        WindowGroup {
//            LoginView()
//        }
//    }
//}

//
//  SynxApp.swift
//  Synx
//
//  Created by Shawn on 10/13/24.
//

import SwiftUI
import UIKit
import Firebase
import GoogleSignIn
import UserNotifications
import FirebaseAuth


@main
struct AuroraApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            LoginView()
        }
    }
}


import UIKit
import Firebase
import FirebaseMessaging
import FirebaseAuth
import UserNotifications
import GoogleSignIn

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    
    private let firebaseManager = FirebaseManager.shared
    
    // Firebase AppDelegate
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("AppDelegate: Application did finish launching.")
        
        // Ensure FirebaseApp is only configured once
                if FirebaseApp.app() == nil {
                    FirebaseApp.configure()
                }
        
        // Messaging delegate setup
        Messaging.messaging().delegate = self
        
        // Notification center delegate setup
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }
        
        return true
    }
    
    // Phone Verification
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("AppDelegate: Registered for remote notifications.")
        
        // Set APNs token for Firebase Authentication
        firebaseManager.auth.setAPNSToken(deviceToken, type: .sandbox)
        
        // Set APNs token for Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
        print("AppDelegate: APNs token set for Firebase Messaging.")
    }
    
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification notification: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("AppDelegate: Received remote notification.")
        
        if firebaseManager.auth.canHandleNotification(notification) {
            completionHandler(.noData)
            return
        }
        completionHandler(.newData)
    }
    
    // Google Sign-In AppDelegate
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        print("AppDelegate: Handling Google Sign-In URL.")
        return GIDSignIn.sharedInstance.handle(url)
    }
    
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
            print("Received new FCM token: \(fcmToken ?? "No Token")")
        }
    
}


