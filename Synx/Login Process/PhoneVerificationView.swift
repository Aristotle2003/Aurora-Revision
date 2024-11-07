//
//  PhoneVerificationView.swift
//  Synx
//
//  Created by Zifan Deng on 11/3/24.
//

import SwiftUI
import Firebase
import FirebaseAuth




struct PhoneVerificationView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var isLogin: Bool
    let phoneNumber: String
    
    @State private var showProfileSetup = false
    
    @State private var verificationCode: String = ""
    @State private var verificationID: String = ""
    @State private var showVerificationField: Bool = false
    @State private var errorMessage: String = ""
    
    @State private var showingPrompt: Bool = false
    @State private var promptMessage: String = ""
    @State private var promptCompletionBlock: ((Bool, String) -> Void)?
    
    private var firebaseManager: FirebaseManager {
        return FirebaseManager.shared
    }
    
    var body: some View {
        VStack(spacing: 20) {
            
            // For showing phone numbr
            if !showVerificationField {
                Text(phoneNumber)
                    .font(.title2)
                    .padding(12)
                
                Text("You will receive an SMS verification code.")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                // Send verification
                Button{
                    requestVerificationCode()
                } label: {
                    Text("Send Code")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                
            // For entering verification code
            } else {
                // Verification code input
                TextField("Enter verification code", text: $verificationCode)
                    .keyboardType(.numberPad)
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(8)
                    .multilineTextAlignment(.center)
                
                // Verify code
                Button {
                    verifyCode()
                } label: {
                    Text("Verify")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
                
                Button("Change Phone Number") {
                    dismiss()
                }
                .foregroundColor(.blue)
            }
            
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .navigationTitle("Phone Verification")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingPrompt) {
            if let completionBlock = promptCompletionBlock {
                TextInputPrompt(
                    isPresented: $showingPrompt,
                    message: promptMessage,
                    completionBlock: completionBlock
                )
            }
        }
        .fullScreenCover(isPresented: $showProfileSetup) {
            if let user = FirebaseManager.shared.auth.currentUser {
                ProfileSetupView(
                    isLogin: $isLogin,
                    uid: user.uid,
                    identifier: phoneNumber
                )
            }
        }
    }
    
    
    private func showTextInputPrompt(withMessage message: String, completionBlock: @escaping (Bool, String) -> Void) {
            self.promptMessage = message
            self.promptCompletionBlock = completionBlock
            self.showingPrompt = true
        }
    
    private func requestVerificationCode() {
        errorMessage = ""
        let formattedPhone = formatPhoneNumber(phoneNumber)
        
        // Phone verification flow
        PhoneAuthProvider.provider()
            .verifyPhoneNumber(formattedPhone, uiDelegate: nil) { verificationID, error in
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                
                if let verificationID = verificationID {
                    self.verificationID = verificationID
                    UserDefaults.standard.set(verificationID, forKey: "authVerificationID")
                    self.showVerificationField = true
                } else {
                    self.errorMessage = "Failed to receive verification code. Please try again."
                }
            }
    }

    private func verifyCode() {
        errorMessage = ""
        
        guard let verificationID = UserDefaults.standard.string(forKey: "authVerificationID") else {
            errorMessage = "Verification ID not found"
            return
        }
        
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: verificationCode
        )
        
        firebaseManager.auth.signIn(with: credential) { authResult, error in
            DispatchQueue.main.async {
                if let error = error as NSError? {
                    // Handle MFA if required
                    if error.code == AuthErrorCode.secondFactorRequired.rawValue {
                        // Handle MFA
                        if let resolver = error.userInfo[AuthErrorUserInfoMultiFactorResolverKey] as! MultiFactorResolver? {
                            // Build display string of factors
                            var displayNameString = ""
                            for tmpFactorInfo in resolver.hints {
                                displayNameString += tmpFactorInfo.displayName ?? ""
                                displayNameString += " "
                            }
                            
                            // Show MFA prompt
                            self.showTextInputPrompt(
                                withMessage: "Select factor to sign in\n\(displayNameString)",
                                completionBlock: { userPressedOK, displayName in
                                    var selectedHint: PhoneMultiFactorInfo?
                                    for tmpFactorInfo in resolver.hints {
                                        if displayName == tmpFactorInfo.displayName {
                                            selectedHint = tmpFactorInfo as? PhoneMultiFactorInfo
                                        }
                                    }
                                    
                                    // Verify the phone number for MFA
                                    PhoneAuthProvider.provider()
                                        .verifyPhoneNumber(with: selectedHint!, uiDelegate: nil,
                                                         multiFactorSession: resolver.session) { verificationID, error in
                                            if error != nil {
                                                self.errorMessage = "Multi factor start sign in failed."
                                            } else {
                                                // Get verification code for MFA
                                                self.showTextInputPrompt(
                                                    withMessage: "Verification code for \(selectedHint?.displayName ?? "")",
                                                    completionBlock: { userPressedOK, verificationCode in
                                                        let credential = PhoneAuthProvider.provider()
                                                            .credential(withVerificationID: verificationID!,
                                                                        verificationCode: verificationCode)
                                                        let assertion = PhoneMultiFactorGenerator.assertion(with: credential)
                                                        
                                                        // Complete MFA sign in
                                                        resolver.resolveSignIn(with: assertion) { authResult, error in
                                                            if let error = error {
                                                                self.errorMessage = error.localizedDescription
                                                            } else {
                                                                // Successfully signed in with MFA
                                                                self.handleSuccessfulSignIn(authResult?.user)
                                                            }
                                                        }
                                                    }
                                                )
                                            }
                                        }
                                }
                            )
                        }
                    } else {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    return
                }
                
                // Handle successful sign in
                self.handleSuccessfulSignIn(authResult?.user)
            }
        }
    }

    // Helper function to handle successful sign in
    private func handleSuccessfulSignIn(_ user: User?) {
        guard let user = user else {
            self.errorMessage = "Failed to get user information"
            return
        }
        
        // Check for existing user
        self.firebaseManager.firestore
            .collection("users")
            .document(user.uid)
            .getDocument { snapshot, error in
                if let error = error {
                    print("Firestore error: \(error)")
                    self.errorMessage = error.localizedDescription
                    return
                }
                
                // User exists
                if snapshot?.exists == true {
                    isLogin = true
                    self.dismiss()
                // User doesn't exist, choose profile
                } else {
                    self.showProfileSetup = true
                }
            }
    }

    // Format phone number for US ONLY RIGHT NOW
    private func formatPhoneNumber(_ number: String) -> String {
        let cleaned = number.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return cleaned.hasPrefix("1") ? "+" + cleaned : "+1" + cleaned
    }
}


struct TextInputPrompt: View {
    @Binding var isPresented: Bool
    let message: String
    let completionBlock: (Bool, String) -> Void
    
    @State private var inputText: String = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(message)
                    .multilineTextAlignment(.center)
                    .padding()
                
                TextField("Enter code", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
                    .padding()
                
                HStack(spacing: 20) {
                    Button("Cancel") {
                        isPresented = false
                        completionBlock(false, "")
                    }
                    .foregroundColor(.red)
                    
                    Button("OK") {
                        isPresented = false
                        completionBlock(true, inputText)
                    }
                    .disabled(inputText.isEmpty)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}





#Preview {
    LoginView()
}
