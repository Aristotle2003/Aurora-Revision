import SwiftUI
import Firebase
import FirebaseAuth
import GoogleSignIn


struct SignUpView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var isLogin: Bool
    
    @State private var email = ""
    @State private var password = ""
    @State private var showProfileSetup = false
    @State private var loginStatusMessage = ""
    
    func generateHapticFeedbackMedium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func generateHapticFeedbackHeavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Group {
                        TextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                        SecureField("Password", text: $password)
                            .textContentType(.newPassword)
                    }
                    .padding(12)
                    .background(Color.white)
                    .cornerRadius(8)
                    
                    Button {
                        createNewAccount()
                        generateHapticFeedbackMedium()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Create Account")
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                    .disabled(email.isEmpty || password.isEmpty)
                    .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1)
                    
                    Text(loginStatusMessage)
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("Create Account")
            .navigationBarItems(leading: Button("Cancel") {
                dismiss()
            })
            .background(Color(.init(white: 0, alpha: 0.05))
                .ignoresSafeArea())
        }
//        .fullScreenCover(isPresented: $showProfileSetup) {
//            if let uid = FirebaseManager.shared.auth.currentUser?.uid {
//                ProfileSetupView(
//                    isLogin: $isLogin,
//                    uid: uid,  // Use the directly retrieved UID
//                    username: email
//                )
//            }
//        }
    }
    
    
    
    // Create a new account with email and password
    private func createNewAccount() {
        // Basic validation
        guard !email.isEmpty, !password.isEmpty else {
            loginStatusMessage = "Please fill in all fields"
            return
        }
        
        guard email.contains("@") && email.contains(".") else {
            loginStatusMessage = "Please enter a valid email address"
            return
        }
        
        guard password.count >= 6 else {
            loginStatusMessage = "Password must be at least 6 characters"
            return
        }
        
        // Creating user in Firebase
        FirebaseManager.shared.auth.createUser(withEmail: email, password: password) { result, err in
            DispatchQueue.main.async {
                if let err = err {
                    if err.localizedDescription.contains("email already in use") {
                        self.loginStatusMessage = "This email is already registered. Please sign in instead."
                    } else if err.localizedDescription.contains("badly formatted") {
                        self.loginStatusMessage = "Please enter a valid email address"
                    } else {
                        self.loginStatusMessage = "Failed to create account: \(err.localizedDescription)"
                    }
                    return
                }
                self.showProfileSetup = true
            }
        }
    }
        
}

#Preview {
    LoginView()
}
