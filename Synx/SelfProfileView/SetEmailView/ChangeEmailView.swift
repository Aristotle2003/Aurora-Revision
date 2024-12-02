//
//  VerifyView.swift
//  Synx
//
//  Created by Zifan Deng on 11/29/24.
//

import SwiftUI
import Firebase
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit

struct ChangeEmailView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var currentUser: User? = FirebaseManager.shared.auth.currentUser
    
    @State private var nonce: String? // Apple Sign-In nonce
    
    @State private var errorMessage: String = ""
    
    
    
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Link your Google or Apple Account")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.top)
                
                Text("Link accounts so you have another way to verify just in case you lose your phone number.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                
                VStack(spacing: 20) {
                    googleSignInButton
                    appleSignInButton
                    changePhoneNumberButton
                }
                .padding(.horizontal)
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.top)
                }
            }
            .padding()
            .navigationTitle("Link Accounts")
        }
    }
    
    // MARK: Google Sign-In Button
    private var googleSignInButton: some View {
        Button {
            handleGoogleSignIn()
        } label: {
            HStack {
                Image(systemName: "g.circle.fill")
                    .font(.system(size: 20))
                Text("Continue with Google")
                    .font(.system(size: 16, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.5), lineWidth: 1)
            )
        }
    }
    
    // MARK: Apple Sign-In Button
    private var appleSignInButton: some View {
        SignInWithAppleButton(.continue) { request in
            let nonce = randomNonceString()
            self.nonce = nonce
            request.requestedScopes = [.email, .fullName]
            request.nonce = sha256(nonce)
        } onCompletion: { result in
            switch result {
            case .success(let authorization):
                handleAppleSignIn(authorization)
            case .failure(let error):
                errorMessage = "Error signing in with Apple: \(error.localizedDescription)"
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .cornerRadius(12)
    }
    
    // MARK: Change Phone Number Button
    private var changePhoneNumberButton: some View {
        Button {
            handleChangePhoneNumber()
        } label: {
            HStack {
                Image(systemName: "phone")
                    .foregroundColor(.blue)
                Text("Change Phone Number")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue, lineWidth: 1)
            )
        }
    }
    
    
    
    
    
    
    
    

    
    // MARK: Google Sign-In Handler
    private func handleGoogleSignIn() {
        guard let clientID = FirebaseManager.shared.auth.app?.options.clientID else {
            errorMessage = "Error getting client ID"
            return
        }
        
        // Create Google Sign-In configuration object.
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "Error getting root view controller"
            return
        }
        
        // Start the sign-in flow.
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            if let error = error {
                errorMessage = "Error signing in with Google: \(error.localizedDescription)"
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                errorMessage = "Error getting user data"
                return
            }
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )
            
            if let currentUser = currentUser {
                Linker.linkAccounts(currentUser: currentUser, credential: credential) { success, error in
                    if success {
                        dismiss()
                    } else {
                        errorMessage = error ?? "Unknown error occurred."
                    }
                }
            } else {
                errorMessage = "No logged-in user found for linking."
            }
        }
    }
        
    
    // MARK: Apple Sign-In Handler
    private func handleAppleSignIn(_ authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = nonce else {
                fatalError("Invalid state: A login callback was received, but no login request was sent.")
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                errorMessage = "Unable to fetch identity token"
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                errorMessage = "Unable to serialize token string from data: \(appleIDToken.debugDescription)"
                return
            }
            
            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )
            
            // Immediately link accounts
            if let currentUser = currentUser {
                Linker.linkAccounts(currentUser: currentUser, credential: credential) { success, error in
                    if success {
                        dismiss()
                    } else {
                        errorMessage = error ?? "Unknown error occurred."
                    }
                }
            } else {
                errorMessage = "No logged-in user found for linking."
            }
        }
    }
    
    
    // MARK: Change Phone Number Handler
    private func handleChangePhoneNumber() {
        print("Change Phone Number tapped")
    }
    
    
    
    
    
    
    
    // Helper: Generate Random Nonce
    private func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }
    
    // Helper: SHA256 Hashing
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.map { String(format: "%02x", $0) }.joined()
    }
}

