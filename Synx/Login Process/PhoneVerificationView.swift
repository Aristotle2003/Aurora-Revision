import SwiftUI
import Firebase
import FirebaseAuth


struct PhoneVerificationView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var isLogin: Bool
    let isPreEmailVerification: Bool
    
    let oldPhone: String?
    let email: String?
    @State private var newPhone: String = ""
    
    @State private var verificationID: String = ""
    @State private var verificationCode: String = ""
    @State private var showVerificationField: Bool = false
    @State private var errorMessage: String = ""
    @State private var showProfileSetup: Bool = false
    @State private var showingPrompt: Bool = false
    @State private var promptMessage: String = ""
    @State private var promptCompletionBlock: ((Bool, String) -> Void)?
    
    @State private var previousUser: User? = nil
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isPreEmailVerification
                             ? "Send code to your phone number"
                             : "Let's register your phone number to find friends!")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    if !showVerificationField {
                        if isPreEmailVerification {
                            HStack(spacing: 8) {
                                // Display the `oldPhone` as text
                                Text("+1")
                                    .font(.title2)
                                    .padding(12)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                                Text(oldPhone?.isEmpty == false ? oldPhone! : "No phone number provided")
                                    .font(.title2)
                                    .padding(12)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        } else {
                            // Input field for entering a new phone number
                            HStack(spacing: 8) {
                                Text("+1")
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 12)
                                
                                TextField("(123) 456-7890", text: $newPhone)
                                    .keyboardType(.phonePad)
                                    .textContentType(.telephoneNumber)
                            }
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                        }
                        
                        
                        // Friendly reminder
                        Text("You will receive an SMS verification code.")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        
                        // Button for sending code
                        Button {
                            requestVerificationCode()
                        } label: {
                            Text("Send Code")
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        .disabled(newPhone.isEmpty && !isPreEmailVerification)
                        .opacity((newPhone.isEmpty && !isPreEmailVerification) ? 0.6 : 1)
                        
                        
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
            }
            .navigationTitle(isPreEmailVerification ? "One-step Sign In" : "Phone Verification")
            .background(Color(.init(white: 0, alpha: 0.05)).ignoresSafeArea())
        }
        .fullScreenCover(isPresented: $showProfileSetup) {
            if let user = FirebaseManager.shared.auth.currentUser {
                ProfileSetupView(
                    isLogin: $isLogin,
                    uid: user.uid,
                    phone: isPreEmailVerification ? oldPhone ?? "" : newPhone,
                    email: isPreEmailVerification ? "" : email ?? ""
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
        let formattedPhone = isPreEmailVerification ? formatPhoneNumber(oldPhone ?? "") : formatPhoneNumber(newPhone)
        
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
        
        if !isPreEmailVerification, let currentUser = FirebaseManager.shared.auth.currentUser {
            // Store the current user
            previousUser = currentUser
            print("[Log]: Attempting to link credential to user \(currentUser.uid)") // EDIT: Added log
            
            self.linkAccounts(currentUser: currentUser, credential: credential)
        } else {
            // Regular phone sign-in flow
            FirebaseManager.shared.auth.signIn(with: credential) { authResult, error in
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
    }
    
    private func linkAccounts(currentUser: User, credential: AuthCredential) {
        currentUser.link(with: credential) { authResult, error in
            if let error = error as NSError? {
                if error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
                    print("[Log]: Credential already in use.") // Log for debugging
                    
                    // Handle case where the credential is already in use
                    if let updatedCredential = error.userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? PhoneAuthCredential {
                        print("[Log]: Attempting to sign in with existing phone account.") // Log for debugging
                        
                        // Sign in with the existing phone account
                        FirebaseManager.shared.auth.signIn(with: updatedCredential) { result, error in
                            if let error = error {
                                self.errorMessage = "Error signing in with phone: \(error.localizedDescription)"
                                return
                            }
                            
                            print("[Log]: Successfully signed in with existing phone account.") // Log for debugging
                            
                            // Now merge the accounts
                            self.mergeAccounts()
                        }
                    } else {
                        self.errorMessage = "Failed to retrieve updated phone credential"
                        print("[Error]: \(self.errorMessage)") // Log for debugging
                    }
                } else {
                    self.errorMessage = error.localizedDescription
                    print("[Error]: \(self.errorMessage)") // Log for debugging
                }
                return
            }
            
            // Successfully linked accounts
            print("[Log]: Successfully linked credential to user \(currentUser.uid)") // Log for debugging
            self.handleSuccessfulSignIn(authResult?.user)
        }
    }

    
    // Deletable later
    private func mergeAccounts() {
        guard let currentUser = FirebaseManager.shared.auth.currentUser,
              let previousUser = self.previousUser else {
            self.errorMessage = "Missing user information for merge"
            print("[Error]: Missing user information for merge.") // EDIT: Added log
            return
        }
        
            
        
        // Create a batch to update all references
        let batch = FirebaseManager.shared.firestore.batch()
        let previousUserDoc = FirebaseManager.shared.firestore.collection("users").document(previousUser.uid)
        let currentUserDoc = FirebaseManager.shared.firestore.collection("users").document(currentUser.uid)
        
        // Fetch and merge previous user's data
        currentUserDoc.getDocument { snapshot, error in
            if let error = error {
                self.errorMessage = "Error fetching previous user data: \(error.localizedDescription)"
                print("[Error]: \(self.errorMessage)") // EDIT: Added log
                return
            }
            
            if let currentData = snapshot?.data() {
                var mergedData = currentData
                mergedData["email"] = previousUser.email
                mergedData["phoneNumber"] = currentUser.phoneNumber
                
                // Update current user's document
                batch.setData(mergedData, forDocument: currentUserDoc)
                
                // Commit the batch operation
                batch.commit { error in
                    if let error = error {
                        self.errorMessage = "Error committing merge batch: \(error.localizedDescription)"
                        print("[Error]: \(self.errorMessage)") // EDIT: Added log
                        return
                    }
                    
                    print("[Log]: Accounts successfully merged.") // EDIT: Added log
                    self.isLogin = true
                    self.dismiss()
                }
            } else {
                self.errorMessage = "Previous user data not found."
                print("[Error]: \(self.errorMessage)") // EDIT: Added log
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
        FirebaseManager.shared.firestore
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
    @State var isLogin = false
    PhoneVerificationView(isLogin: $isLogin, isPreEmailVerification: true, oldPhone: "1234567890", email: "")
}
