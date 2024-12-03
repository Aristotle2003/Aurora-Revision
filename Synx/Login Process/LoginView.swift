//
//  CreateNewMessageView.swift
//  Synx
//
//  Created by Francis on 10/30/24.
//



import SwiftUI
import Firebase
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit




struct LoginView: View {
    @Environment(\.window) var window
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @AppStorage("SeenTutorial") private var SeenTutorial: Bool = false
    @State var isLogin = false
    
    @State private var isPostEmailVerification = false
    @State private var isPreEmailVerification = false
    
    @State private var uid = ""
    @State private var email = ""
    
    @State private var countryCode: String = "1"
    @State private var phoneNumber = ""
    // Apple nonce
    @State private var nonce: String?
    
    @State private var loginStatusMessage = ""
    @State var hasSeenTutorial = false
    
    private var countryCodes: [(numericCode: String, isoCode: String, name: String)] {
        Formatter.getAllCountryCodes()
    }
    
    
    var body: some View {
        if isLogin && hasSeenTutorial{
            CustomTabNavigationView()
        }
        else if isLogin && !hasSeenTutorial{
            TutorialView()
        }
        else{
            NavigationView {
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Quick sign in with phone")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Enter your number to instantly sign in or create account")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.bottom, 4)
                            
                            phoneInputView
                        }
                        .padding(.bottom, 10)
                        
                        
                        
                        // Button for phone login
                        Button {
                           verifyPhoneNumber()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Continue")
                                    .foregroundColor(.white)
                                    .padding(.vertical, 12)
                                    .font(.system(size: 16, weight: .semibold))
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        .disabled(phoneNumber.isEmpty)
                        .opacity(phoneNumber.isEmpty ? 0.6 : 1)
                        
                        
                        
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
                        
                        
                        
                        // Button for apple login
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
                        
                        
                        
                        // Status Message
                        Text(self.loginStatusMessage)
                            .foregroundColor(.red)
                    }
                    .padding()
                    
                }
                .navigationTitle("One-step Sign In")
                .background(Color(.init(white: 0, alpha: 0.05))
                    .ignoresSafeArea())
            }
            .navigationViewStyle(StackNavigationViewStyle())
            // Phone verification with no email
            .fullScreenCover(isPresented: $isPreEmailVerification) {
                PhoneVerificationView(
                    isLogin: $isLogin,
                    hasSeenTutorial: $hasSeenTutorial,
                    isPreEmailVerification: true,
                    oldPhone: phoneNumber,
                    email: ""
                )
            }
            // Phone verification after google or apple
            .fullScreenCover(isPresented: $isPostEmailVerification) {
                if let user = FirebaseManager.shared.auth.currentUser {
                    PhoneVerificationView(
                        isLogin: $isLogin,
                        hasSeenTutorial: $hasSeenTutorial,
                        isPreEmailVerification: false,
                        oldPhone: "",
                        email: user.email
                    )
                }
            }
        }
    }
    
    
    private var phoneInputView: some View {
        // Input field for entering a new phone number
        HStack(spacing: 4) {
            // Country Code Dropdown
            Menu {
                ForEach(countryCodes, id: \.numericCode) { code in
                    Button(action: { countryCode = code.numericCode }) {
                        Text("+\(code.numericCode) (\(code.name))") // Show country code and name in the menu
                    }
                }
            } label: {
                HStack {
                    Text("+\(countryCode)") // Only show the number in the button
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.down") // Add a dropdown arrow icon
                        .foregroundColor(.gray)
                }
                .padding(12)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .frame(width: 100)
            .padding(.leading, -6)
            
            
            // Phone Number Input Field
            TextField("Phone Number", text: $phoneNumber)
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .padding(12)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
        }
        .padding(8)
        .background(Color.white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
    
    
    
    
    
    
    // MARK: Functions Start Here
    // Verify using phone number
    private func verifyPhoneNumber() {
        // Format and validate the phone number using the Formatter class
        guard let formattedPhone = Formatter.formatPhoneNumber(phoneNumber, numericCode: countryCode) else {
            loginStatusMessage = "Please enter a valid phone number"
            return
        }
        
        self.phoneNumber = formattedPhone // Update the formatted phone number
        
        if Formatter.isValidPhoneNumber(phoneNumber, numericCode: countryCode) {
            isPreEmailVerification = true
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
                        if (snapshot?.data()) != nil {
                            checkTutorialStatus()
                            self.isLogin = true
                            self.isLoggedIn = true
                        // New user set up profile
                        } else {
                            self.isPostEmailVerification = true
                        }
                    }
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
                        if (snapshot?.data()) != nil {
                            checkTutorialStatus()
                            self.isLogin = true
                            self.isLoggedIn = true
                        // New user set up profile
                        } else {
                            self.isPostEmailVerification = true
                        }
                    }
            }
        }
    }
    
    private func checkTutorialStatus() {
            guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }

            FirebaseManager.shared.firestore
                .collection("users")
                .document(uid)
                .getDocument { snapshot, error in
                    if let error = error {
                        print("Failed to fetch tutorial status: \(error)")
                        hasSeenTutorial = false
                        SeenTutorial = false
                    } else if let data = snapshot?.data(), let seen = data["seen_tutorial"] as? Bool {
                        hasSeenTutorial = seen
                        SeenTutorial = seen
                    } else {
                        hasSeenTutorial = false
                        SeenTutorial = false
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
