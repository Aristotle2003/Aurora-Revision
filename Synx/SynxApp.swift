//
//  SynxApp.swift
//  Synx
//
//  Created by Shawn on 10/13/24.
//

import SwiftUI


@main
struct SynxApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            LoginView()
        }
    }
}
