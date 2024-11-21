//
//  CreateNewMessageView.swift
//  Synx
//
//  Wrote by Francis on 10/30/24.
//



import SwiftUI
import Firebase
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit

struct LoginView: View {
    @Environment(\.window) var window
    
    @State var isLogin = false
    @State private var isSignUpMode = false
    @State private var isPhoneLogin = true
    
    @State private var showProfileSetup = false
    @State private var showPhoneVerification = false
    
    @State private var uid = ""
    @State private var email = ""
    @State private var password = ""
    @State private var phoneNumber = "" {
        didSet {
            phoneNumber = phoneNumber.trimmingCharacters(in: .whitespaces)
        }
    }
    @State private var loginStatusMessage = ""
    @State var haveUserName = false
    
    
    // Apple nonce
    @State private var nonce: String?
    
    var body: some View {
        if isLogin && haveUserName{
            MainMessagesView()
        } else if isLogin && !haveUserName{
            // 进入设置用户名界面
            SetUsernameView(haveUserName: $haveUserName)
        }
        
        else{
            NavigationView {
                ScrollView {
                    
                    VStack(spacing: 20) {
                        
                        if isPhoneLogin {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Quick sign in with phone")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Enter your number to instantly sign in or create account")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.bottom, 4)
                                
                                HStack(spacing: 8) {
                                    Text("+1")
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 12)
                                    
                                    TextField("(123) 456-7890", text: $phoneNumber)
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
                            .padding(.bottom, 10)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Sign in with email")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .padding(.bottom, 4)
                                
                                VStack(spacing: 12) {
                                    TextField("Email", text: $email)
                                        .keyboardType(.emailAddress)
                                        .textContentType(.emailAddress)
                                        .autocapitalization(.none)
                                        .padding(12)
                                        .background(Color.white)
                                        .cornerRadius(8)
                                    
                                    SecureField("Password", text: $password)
                                        .textContentType(.password)
                                        .padding(12)
                                        .background(Color.white)
                                        .cornerRadius(8)
                                }
                            }
                        }
                        
                        // Button depending on user choice
                        Button {
                           if isPhoneLogin {
                               verifyPhoneNumber()
                           } else {
                               loginWithEmail()
                           }
                        } label: {
                            HStack {
                                Spacer()
                                if isPhoneLogin {
                                    Text("Continue")
                                        .foregroundColor(.white)
                                        .padding(.vertical, 12)
                                        .font(.system(size: 16, weight: .semibold))
                                } else {
                                    Text("Sign In")
                                        .foregroundColor(.white)
                                        .padding(.vertical, 12)
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        .disabled(isPhoneLogin ? phoneNumber.isEmpty : (email.isEmpty || password.isEmpty))
                        .opacity(isPhoneLogin ? (phoneNumber.isEmpty ? 0.6 : 1) : (email.isEmpty || password.isEmpty ? 0.6 : 1))
                        
                        
                        // Button for switching
                        Button {
                            withAnimation {
                                isPhoneLogin.toggle()
                                loginStatusMessage = ""
                            }
                        } label: {
                            Text(isPhoneLogin ? "Use email instead" : "Use phone number instead")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                        }
                        
                        
                        
                        // Divider
                        HStack {
                            VStack { Divider() }.padding(.horizontal, 8)
                            Text("or").foregroundColor(.gray)
                            VStack { Divider() }.padding(.horizontal, 8)
                        }
                        
                        
                        
                        // Button for google login
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
                                loginStatusMessage = "Error signing in with Apple: \(error.localizedDescription)"
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .cornerRadius(12)
                        
                        
                        // Create new account button
                        if !isPhoneLogin {
                            Button {
                                isSignUpMode = true
                            } label: {
                                Text("Create New Account with email")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .padding(.top, 8)
                        }
                        
                        
                        // Status Message
                        Text(self.loginStatusMessage)
                            .foregroundColor(.red)
                    }
                    .padding()
                    
                }
                // .onAppear{
                //     checkIfUserHasUsername()
                // }
                
                .navigationTitle(isPhoneLogin ? "One-step Sign In" : "Email Sign In")
                .background(Color(.init(white: 0, alpha: 0.05))
                    .ignoresSafeArea())
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .animation(.easeInOut, value: isPhoneLogin)
            // Switch to sign up view
            .fullScreenCover(isPresented: $isSignUpMode) {
                SignUpView(isLogin: $isLogin)
            }
            // Switch to profile set up view
            .fullScreenCover(isPresented: $showProfileSetup) {
                if let user = FirebaseManager.shared.auth.currentUser,
                   let email = user.email {
                    ProfileSetupView(
                        isLogin: $isLogin,
                        uid: user.uid,
                        identifier: email
                    )
                }
            }
            // Switch to phone verification view
            .fullScreenCover(isPresented: $showPhoneVerification) {
                PhoneVerificationView(
                    isLogin: $isLogin,
                    phoneNumber: phoneNumber
                )
            }
        }
        
    }
    
    
    
    // Sign in using Apple account
    func handleAppleSignIn(_ authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            // Showing loading screen later
            
            guard let nonce else {
                fatalError("Invalid state: A login callback was received, but no login request was sent.")
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                print("Unable to fetch identity token")
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                return
            }
            // Initialize a Firebase credential, including the user's full name.
            let credential = OAuthProvider.appleCredential(withIDToken: idTokenString,
                                                           rawNonce: nonce,
                                                           fullName: appleIDCredential.fullName)
            // Sign in with Firebase.
            FirebaseManager.shared.auth.signIn(with: credential) { (authResult, error) in
                if let error {
                    // Error. If error.code == .MissingOrInvalidNonce, make sure
                    // you're sending the SHA256-hashed nonce as a hex string with
                    // your request to Apple.
                    self.loginStatusMessage = "Apple sign in error: \(error.localizedDescription)"
                    return
                }
                // User is signed in to Firebase with Apple.
                guard let user = authResult?.user else { return }
                FirebaseManager.shared.firestore.collection("users")
                    .document(user.uid).getDocument { snapshot, error in
                        if let error = error {
                            self.loginStatusMessage = "\(error)"
                            return
                        }
                        
                        // User exists
                        if let data = snapshot?.data() {
                            let chatUser = ChatUser(data: data)
                            self.loginStatusMessage = "Successfully logged in as \(chatUser.email)"
                            self.checkIfUserHasUsername { hasUsername in
                                self.haveUserName = hasUsername
                                self.isLogin = true
                            }
                        // New user set up profile
                        } else {
                            self.showProfileSetup = true
                        }
                    }
            }
        }
    }
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError(
                "Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)"
            )
        }
        
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        
        let nonce = randomBytes.map { byte in
            // Pick a random character from the set, wrapping around if needed.
            charset[Int(byte) % charset.count]
        }
        
        return String(nonce)
    }
    
    @available(iOS 13, *)
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    
    
    
    
    
    
    // Sign in using email and password
    private func loginWithEmail() {
        
        // Sign in email user!!
        FirebaseManager.shared.auth.signIn(withEmail: email, password: password) { result, err in
            if let err = err {
                self.loginStatusMessage = "Failed to login user: \(err)"
                return
            }
            self.loginStatusMessage = "Successfully logged in as user: \(result?.user.uid ?? "")"
            self.checkIfUserHasUsername { hasUsername in
                self.haveUserName = hasUsername
                self.isLogin = true
            }
        }
    }
    
    
    
    // Verify using phone number
    private func verifyPhoneNumber() {
        let cleanedPhone = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if cleanedPhone.count == 10 || (cleanedPhone.count == 11 && cleanedPhone.hasPrefix("1")) {
            showPhoneVerification = true
        } else {
            loginStatusMessage = "Please enter a valid phone number"
        }
    }
    
    
    
    // Sign in using Google sign in
    private func handleGoogleSignIn() {
        guard let clientID = FirebaseManager.shared.auth.app?.options.clientID else {
            self.loginStatusMessage = "Error getting client ID"
            return
        }
        
        // Create Google Sign In configuration object.
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            self.loginStatusMessage = "Error getting root view controller"
            return
        }

        
        // Start the sign in flow!
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            if let error = error {
                self.loginStatusMessage = "Error signing in with Google: \(error.localizedDescription)"
                return
            }
            
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString
            else {
                self.loginStatusMessage = "Error getting user data"
                return
            }
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: user.accessToken.tokenString
            )
            
            // Sign in google user!!
            FirebaseManager.shared.auth.signIn(with: credential) { result, error in
                if let error = error {
                    self.loginStatusMessage = "Firebase sign in error: \(error.localizedDescription)"
                    return
                }
                
                // Check if user exists
                guard let user = result?.user else { return }
                FirebaseManager.shared.firestore.collection("users")
                    .document(user.uid).getDocument { snapshot, error in
                        if let error = error {
                            self.loginStatusMessage = "\(error)"
                            return
                        }
                        
                        // User exists
                        if let data = snapshot?.data() {
                            let chatUser = ChatUser(data: data)
                            self.loginStatusMessage = "Successfully logged in as \(chatUser.email)"
                            self.checkIfUserHasUsername { hasUsername in
                                self.haveUserName = hasUsername
                                self.isLogin = true
                            }
                        // New user set up profile
                        } else {
                            self.showProfileSetup = true
                        }
                    }
            }
        }
    }

    func checkIfUserHasUsername(completion: @escaping (Bool) -> Void) {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        let userRef = FirebaseManager.shared.firestore.collection("users").document(uid)
        userRef.getDocument { snapshot, error in
            if let data = snapshot?.data(), let username = data["username"] as? String, !username.isEmpty {
                print(username)
                completion(true)
            } else {
                print("No username")
                completion(false)
            }
        }
    }
    
    
    
}



extension EnvironmentValues {
    var window: UIWindow? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return nil }
        return scene.windows.first
    }
}



#Preview {
    LoginView()
}
