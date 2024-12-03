//
//  ProfileSetupView.swift
//  Synx
//
//  Created by Zifan Deng on 11/5/24.
//

import SwiftUI
import Firebase
import FirebaseAuth
import GoogleSignIn


// Profile picture selection view
struct ProfileSetupView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var isLogin: Bool
    let uid: String
    let phone: String
    let email: String
    
    @State private var showImagePicker = false
    @State private var statusMessage = ""
    @State private var image: UIImage?
    @State private var username: String = ""
    
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Complete Your Profile")
                        .font(.headline)
                        .padding(.top)
                    
                    Text("Add a profile picture to continue")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button {
                        showImagePicker.toggle()
                    } label: {
                        VStack {
                            if let image = self.image {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 128, height: 128)
                                    .cornerRadius(64)
                            } else {
                                Image(systemName: "person.fill")
                                    .font(.system(size: 64))
                                    .padding()
                                    .foregroundColor(Color(.label))
                            }
                        }
                        .overlay(RoundedRectangle(cornerRadius: 64)
                            .stroke(Color.black, lineWidth: 3)
                        )
                    }
                    
                    TextField("Enter your username", text: $username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    Button {
                        validateAndPersistUserProfile()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Continue")
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }
                        .background(Color.blue)
                        .cornerRadius(8)
                    }
                    .disabled(image == nil || username.isEmpty)
                    .opacity((image == nil || username.isEmpty) ? 0.6 : 1)
                    
                    
                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .foregroundColor(.red)
                            .font(.system(size: 14))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding()
            }
            .navigationTitle("Set Up Profile")
            .navigationBarItems(leading: Button("Cancel") {
                dismiss()
            })
            .background(Color(.init(white: 0, alpha: 0.05)).ignoresSafeArea())
        }
        .fullScreenCover(isPresented: $showImagePicker) {
            ImagePicker(image: $image)
        }
    }
    
    
    private func validateAndPersistUserProfile() {
        guard !username.isEmpty else {
            statusMessage = "Username cannot be empty"
            return
        }
        handleImage()
    }
    
    
    private func handleImage() {
        guard let image = self.image else {
            statusMessage = "Please select a profile picture"
            return
        }
        
        let ref = FirebaseManager.shared.storage.reference(withPath: uid)
        guard let imageData = image.jpegData(compressionQuality: 0.5) else { return }
        
        ref.putData(imageData, metadata: nil) { metadata, err in
            if let err = err {
                self.statusMessage = "Failed to upload profile picture: \(err.localizedDescription)"
                return
            }
            
            ref.downloadURL { url, err in
                if let err = err {
                    self.statusMessage = "Failed to process profile picture: \(err.localizedDescription)"
                    return
                }
                
                self.statusMessage = "Successfully stored image with url: \(url?.absoluteString ?? "")"
                guard let url = url else { return }
                self.storeUserInformation(imageProfileUrl: url)
            }
        }
    }
    
    
    private func storeUserInformation(imageProfileUrl: URL) {
        let userData: [String: Any] = [
            "uid": uid,
            "phoneNumber": phone,
            "email": email,
            "profileImageUrl": imageProfileUrl.absoluteString,
            "username": username
        ]
        
        FirebaseManager.shared.firestore.collection("users")
            .document(uid).setData(userData) { err in
                if let err = err {
                    self.statusMessage = "Failed to save user data: \(err.localizedDescription)"
                    return
                }
                
                saveUsernameToBasicInfo()
                
                self.isLogin = true
                dismiss()
            }
    }
    
    private func saveUsernameToBasicInfo() {
        let userRef = FirebaseManager.shared.firestore
            .collection("basic_information")
            .document(uid)
            .collection("information")
            .document("profile")
        
        userRef.setData(["username": username], merge: true) { error in
            if let error = error {
                self.statusMessage = "Failed to save username to basic information: \(error.localizedDescription)"
            } else {
                print("Saving username to basic information successfully")
            }
        }
    }
}



#Preview {
    LoginView()
}
