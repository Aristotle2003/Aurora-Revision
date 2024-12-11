//
//  ChangePhoneView.swift
//  Synx
//
//  Created by Zifan Deng on 12/1/24.
//

import SwiftUI
import Firebase
import FirebaseAuth




struct ChangePhoneView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var countryCode: String = "1"
    @State private var phoneNumber: String = ""
    
    @State private var verificationID: String? = nil
    @State private var verificationCode: String = ""
    @State private var showVerificationField: Bool = false
    
    @State private var newPhoneCredential: PhoneAuthCredential?
    @State private var isLoading: Bool = false

    @State private var errorMessage: String = ""
    
    private var countryCodes: [(numericCode: String, isoCode: String, name: String)] {
        Formatter.getAllCountryCodes()
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    headerView
                    
                    if !showVerificationField {
                        PhoneInputView
                        
                        // Friendly reminder
                        Text("You will receive an SMS verification code.")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        sendCodeButton
                    } else {
                        // Verification code input
                        TextField("Enter verification code", text: $verificationCode)
                            .keyboardType(.numberPad)
                            .padding(12)
                            .background(Color.white)
                            .cornerRadius(8)
                            .multilineTextAlignment(.center)
                        
                        verifyCodeButton
                        
                        Button("Change Phone Number") {
                            dismiss()
                        }
                        .foregroundColor(.blue)
                    }
                    
                    if isLoading {
                        ProgressView()
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
            .navigationTitle("Change Phone Number")
            .navigationBarItems(leading: Button("Cancel") {
                dismiss()
            })
            .background(Color(.init(white: 0, alpha: 0.05)).ignoresSafeArea())
        }
    }
    
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Send code to your phone number")
            .font(.headline)
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    
    private var PhoneInputView: some View {
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

    
    private var sendCodeButton: some View {
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
        .disabled(phoneNumber.isEmpty)
        .opacity((phoneNumber.isEmpty) ? 0.6 : 1)
    }
    
    private var verifyCodeButton: some View {
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
    }
    
    
    
    
    
    
    
    
    // MARK: Functions Start Here
    private func requestVerificationCode() {
        errorMessage = ""
        isLoading = true
        
        let formattedPhone = Formatter.formatPhoneNumber(phoneNumber, numericCode: countryCode)
        guard let formattedPhone = formattedPhone else {
            errorMessage = "Please enter a valid phone number"
            isLoading = false
            return
        }
        self.phoneNumber = formattedPhone
        
        // Check if the phone number already exists in the database
        checkIfPhoneNumberExists(phoneNumber: phoneNumber) { exists in
            if exists {
                self.errorMessage = "This phone number is already in use. Log in or choose another one"
                self.isLoading = false
            } else {
                // Send the verification code
                PhoneAuthProvider.provider().verifyPhoneNumber(phoneNumber, uiDelegate: nil) { verificationID, error in
                    self.isLoading = false
                    if let error = error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    self.verificationID = verificationID
                    self.showVerificationField = true
                }
            }
        }
    }


    private func verifyCode() {
        errorMessage = ""
        isLoading = true
        
        // Crucial Line
        guard let verificationID = verificationID else {
            errorMessage = "Verification ID not found"
            isLoading = false
            return
        }
        
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: verificationCode
        )
        
        guard let currentUser = FirebaseManager.shared.auth.currentUser else {
            errorMessage = "No current user found"
            isLoading = false
            return
        }
        
        
        // Unlink all previous phone numbers first
        unlinkAllPhoneProviders(currentUser: currentUser) { success in
            if success {
                // Link and update phone number after unlinking
                self.linkCredentialAndUpdatePhone(currentUser: currentUser, credential: credential)
            } else {
                self.errorMessage = "Failed to unlink previous phone numbers."
                self.isLoading = false
            }
        }
    }
    
    
    private func unlinkAllPhoneProviders(currentUser: User, completion: @escaping (Bool) -> Void) {
        // Identify phone-based providers
        let phoneProviders = currentUser.providerData.filter { $0.providerID == PhoneAuthProviderID }
        let group = DispatchGroup()
        var unlinkingError: Error?
        
        for provider in phoneProviders {
            group.enter()
            currentUser.unlink(fromProvider: provider.providerID) { _, error in
                if let error = error {
                    unlinkingError = error
                    print("Error unlinking provider \(provider.providerID): \(error.localizedDescription)")
                } else {
                    print("Successfully unlinked provider: \(provider.providerID)")
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if let error = unlinkingError {
                self.errorMessage = "Error unlinking providers: \(error.localizedDescription)"
                completion(false)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    print("All phone providers unlinked successfully.")
                    completion(true)
                }
            }
        }
    }
    
    
    // Link credentials, update Firebase, update Firestore
    private func linkCredentialAndUpdatePhone(currentUser: User, credential: PhoneAuthCredential) {
        let newPhoneNumber = phoneNumber
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            // Link the provided phone credential
            currentUser.link(with: credential) { authResult, error in
                if let error = error {
                    self.errorMessage = "Error linking phone number: \(error.localizedDescription)"
                    print("Error linking phone number: \(error.localizedDescription)")
                    return
                }
                print("Phone number immediately after link: \(authResult?.user.phoneNumber ?? "nil")")
                
                
                // Reload user to verify the update
                currentUser.reload { error in
                    if let error = error {
                        self.errorMessage = "Error reloading user: \(error.localizedDescription)"
                        print("Error reloading user: \(error.localizedDescription)")
                        return
                    }
                    
                    // Verify the phone number was updated
                    if let freshUser = FirebaseManager.shared.auth.currentUser,
                       let updatedPhoneNumber = freshUser.phoneNumber {
                        print("Verified phone number in Firebase Auth: \(updatedPhoneNumber)")
                        
                        // Update Firestore
                        let db = Firestore.firestore()
                        let userId = currentUser.uid
                        
                        db.collection("users").document(userId).updateData([
                            "phoneNumber": newPhoneNumber
                        ]) { error in
                            if let error = error {
                                self.errorMessage = "Error updating phone number in Firestore: \(error.localizedDescription)"
                                print("Error updating phone number in Firestore: \(error.localizedDescription)")
                            } else {
                                print("Successfully updated phone number in Firestore to \(newPhoneNumber)")
                                dismiss()
                            }
                        }
                    } else {
                        self.errorMessage = "Phone number not updated in Firebase Auth"
                        print("No phone number available after update.")
                    }
                }
            }
        }
    }

    
    
    // Check if Phone is in the database
    private func checkIfPhoneNumberExists(phoneNumber: String?, completion: @escaping (Bool) -> Void) {
        guard let phoneNumber = phoneNumber else {
            completion(false)
            return
        }
        
        let usersRef = FirebaseManager.shared.firestore.collection("users")
        usersRef.whereField("phoneNumber", isEqualTo: phoneNumber).getDocuments { snapshot, error in
            if let error = error {
                print("[Error]: Failed to query Firestore for phone number: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let documents = snapshot?.documents, !documents.isEmpty else {
                print("[Log]: Phone number not found in Firestore.")
                completion(false) // No matching phone number found
                return
            }
            
            print("[Log]: Phone number already exists in Firestore.")
            completion(true) // Phone number already exists
        }
    }

    
    
    
    
    
    
    
    
}


#Preview {
    ChangePhoneView()
}
