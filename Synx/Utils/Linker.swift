//
//  Linker.swift
//  Synx
//
//  Created by Zifan Deng on 11/29/24.
//

import Foundation
import Firebase
import FirebaseAuth

class Linker {
    static func linkAccounts(currentUser: User, credential: AuthCredential, completion: @escaping (Bool, String?) -> Void) {
        currentUser.link(with: credential) { authResult, error in
            if let error = error as NSError? {
                switch error.code {
                case AuthErrorCode.credentialAlreadyInUse.rawValue:
                    completion(false, "The credential is already in use. Please try another account.")
                default:
                    completion(false, "Linking failed: \(error.localizedDescription)")
                }
                return
            }
            
            // Successfully linked accounts
            if let user = authResult?.user, let email = user.email {
                let userRef = FirebaseManager.shared.firestore.collection("users").document(user.uid)
                userRef.setData(["email": email], merge: true) { error in
                    if let error = error {
                        completion(false, "Error saving email to database: \(error.localizedDescription)")
                    } else {
                        print("[Log]: Successfully saved email \(email) to Firestore.")
                        completion(true, nil)
                    }
                }
            } else {
                completion(true, nil)
            }
        }
    }
}
