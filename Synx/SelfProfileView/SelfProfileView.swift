//
//  SelfProvileView.swift
//  Synx
//
//  Created by Shawn on 11/26/24.
//

import SwiftUI
import SDWebImageSwiftUI
import FirebaseCore

struct SelfProfileView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    let chatUser: ChatUser
    @State var currentUser: ChatUser
    let isCurrentUser: Bool
    let showTemporaryImg: Bool
    @State var errorMessage = ""
    @State var isFriend: Bool = false
    @State var friendRequestSent: Bool = false
    @State var basicInfo: BasicInfo? = nil // For current user
    @State var otherUserInfo: BasicInfo? = nil // For other users
    @State private var showReportSheet = false
    @State private var reportContent = ""
    @State private var showDeleteConfirmation = false
    @State private var navigateToMainMessagesView = false
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage? = nil
    @State private var showConfirmationDialog = false
    @State private var savingImageUrl = ""
    @State private var showTemporaryImage = false
    @State private var shouldShowLogOutOptions = false
    @State private var isUserCurrentlyLoggedOut = false
    @State private var showPrivacyPage = false
    
    @ObservedObject var chatLogViewModel: ChatLogViewModel
    @StateObject private var messagesViewModel = MessagesViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    private func fetchCurrentUser() {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {
            self.errorMessage = "Could not find firebase uid"
            return
        }
        
        FirebaseManager.shared.firestore.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                self.errorMessage = "Failed to fetch current user: \(error)"
                print("Failed to fetch current user:", error)
                return
            }
            
            guard let data = snapshot?.data() else {
                self.errorMessage = "No data found"
                return
            }
            
            DispatchQueue.main.async {
                self.currentUser = ChatUser(data: data)
            }
        }
    }
    
    private func handleSignOut() {
        guard let currentUserID = FirebaseManager.shared.auth.currentUser?.uid else { return }
        
        // Reference to the user's FCM token in Firestore
        let userRef = FirebaseManager.shared.firestore.collection("users").document(currentUserID)
        
        // Update the FCM token to an empty string
        userRef.updateData(["fcmToken": ""]) { error in
            if let error = error {
                print("Failed to update FCM token: \(error)")
                return
            }
            
            // Proceed to sign out if the FCM token update is successful
            self.isUserCurrentlyLoggedOut.toggle()
            try? FirebaseManager.shared.auth.signOut()
        }
    }
    
    var body: some View {
        NavigationStack{
            VStack {
                if !showTemporaryImage{
                    WebImage(url: URL(string: self.currentUser.profileImageUrl))
                        .resizable()
                        .scaledToFill()
                        .frame(width: 150, height: 150)
                        .clipShape(Circle())
                        .shadow(radius: 10)
                        .onTapGesture {
                            if isCurrentUser {
                                showImagePicker = true
                            }
                        }
                }
                else{
                    WebImage(url: URL(string: self.savingImageUrl))
                        .resizable()
                        .scaledToFill()
                        .frame(width: 150, height: 150)
                        .clipShape(Circle())
                        .shadow(radius: 10)
                        .onTapGesture {
                            if isCurrentUser {
                                showImagePicker = true
                            }
                        }
                }
                
                if isCurrentUser, let info = basicInfo {
                    Text("\(info.username)")
                        .font(.title)
                    // 当前用户的基本信息
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Age: \(info.age)")
                        Text("Gender: \(info.gender)")
                        Text("Location: \(info.location)")
                        Text("Email: \(info.email)")
                        Text("Bio: \(info.bio)")
                        
                    }
                    .padding()
                }
                
                Spacer()
                
                // New Rectangle Buttons
                VStack(spacing: 10) {
                    NavigationLink(destination: EditProfileView(currentUser: currentUser, chatLogViewModel: chatLogViewModel)) {
                        Text("Change Basic Info")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                    
                    Button(action: {
                        showPrivacyPage.toggle()
                    }) {
                        Text("Privacy")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                    // Navigate to Change Email View
                    NavigationLink(destination: ChangeEmailView()) {
                        Text("Security")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                    
                    // Logout Button
                    Button(action: {
                        shouldShowLogOutOptions.toggle()
                    }) {
                        Text("Sign Out")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                }
                .padding()
                .actionSheet(isPresented: $shouldShowLogOutOptions) {
                    ActionSheet(
                        title: Text("Settings"),
                        message: Text("What do you want to do?"),
                        buttons: [
                            .destructive(Text("Sign Out"), action: {
                                isLoggedIn = false
                                handleSignOut()
                            }),
                            .cancel()
                        ]
                    )
                }
                .fullScreenCover(isPresented: $isUserCurrentlyLoggedOut) {
                    LoginView()
                }
                .fullScreenCover(isPresented: $showPrivacyPage){
                    PrivacyView()
                }
                
                Spacer()
            }
            .padding()
            .onAppear {
                fetchCurrentUser()
                checkIfFriend()
                if isCurrentUser {
                    fetchBasicInfo(for: currentUser.uid) { info in
                        self.basicInfo = info
                    }
                } else {
                    fetchBasicInfo(for: chatUser.uid) { info in
                        self.otherUserInfo = info
                    }
                }
            }
            .onDisappear{
                self.showTemporaryImage = false
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage)
                    .onDisappear {
                        if selectedImage != nil {
                            updateProfilePhoto()
                            print("Image selected successfully!")
                            showConfirmationDialog = true
                        } else {
                            print("No image selected.")
                        }
                    }
            }
            .alert(isPresented: $showConfirmationDialog) {
                Alert(
                    title: Text("Confirm Photo"),
                    message: Text("Are you sure you want to use this photo?"),
                    primaryButton: .default(Text("Yes"), action: updateProfilePhoto),
                    secondaryButton: .cancel()
                )
            }
            .onDisappear{
                self.showTemporaryImage = false
            }
            
            .navigationBarBackButtonHidden(true)
        }
        .onDisappear{
            self.showTemporaryImage = false
        }
    }
    
    private func updateProfilePhoto() {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        
        var updatedData: [String: Any] = [:]
        
        if let selectedImage = selectedImage {
            // 上传新头像
            let ref = FirebaseManager.shared.storage.reference(withPath: uid)
            if let imageData = selectedImage.jpegData(compressionQuality: 0.5) {
                ref.putData(imageData, metadata: nil) { metadata, error in
                    if let error = error {
                        print("Failed to upload image: \(error)")
                        return
                    }
                    ref.downloadURL { url, error in
                        if let error = error {
                            print("Failed to get download URL: \(error)")
                            return
                        }
                        if let url = url {
                            updatedData["profileImageUrl"] = url.absoluteString
                            self.savingImageUrl = url.absoluteString
                            self.showTemporaryImage = true
                            self.saveProfilePhotoToCentralDb(uid: uid, data: updatedData)
                        }
                    }
                }
            }
        } else {
            print("Wrong")
        }
    }
    
    private func saveProfilePhotoToCentralDb(uid: String, data: [String: Any]) {
        let userRef = FirebaseManager.shared.firestore.collection("users").document(uid)
        userRef.updateData(data) { error in
            if let error = error {
                print("Failed to update profile: \(error)")
                return
            }
            print("Profile updated successfully")
            self.updateProfilePhotoToFriends(uid: uid, data: data)
        }
    }
    
    private func updateProfilePhotoToFriends(uid: String, data: [String: Any]) {
        let friendsRef = FirebaseManager.shared.firestore.collection("friends").document(uid).collection("friend_list")
        friendsRef.getDocuments { snapshot, error in
            if let error = error {
                print("Failed to fetch friends: \(error)")
                return
            }
            guard let documents = snapshot?.documents else { return }
            for document in documents {
                let friendId = document.documentID
                let friendRef = FirebaseManager.shared.firestore.collection("friends").document(friendId).collection("friend_list").document(uid)
                friendRef.updateData(data) { error in
                    if let error = error {
                        print("Failed to update friend profile: \(error)")
                    } else {
                        print("Friend profile updated successfully")
                    }
                }
            }
        }
    }
    
    private func checkIfFriend() {
        FirebaseManager.shared.firestore
            .collection("friends")
            .document(currentUser.uid)
            .collection("friend_list")
            .document(chatUser.uid)
            .getDocument { snapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to check friendship status: \(error)"
                    print("Failed to check friendship status:", error)
                    return
                }
                self.isFriend = snapshot?.exists ?? false
            }
    }
    
    private func fetchBasicInfo(for userId: String, completion: @escaping (BasicInfo?) -> Void) {
        FirebaseManager.shared.firestore
            .collection("basic_information")
            .document(userId)
            .collection("information")
            .document("profile")
            .getDocument { snapshot, error in
                if let data = snapshot?.data() {
                    let info = BasicInfo(
                        age: data["age"] as? String ?? "",
                        gender: data["gender"] as? String ?? "",
                        email: data["email"] as? String ?? "",
                        bio: data["bio"] as? String ?? "",
                        location: data["location"] as? String ?? "",
                        username: data["username"] as? String ?? "",
                        birthdate: data["birthdate"] as? String ?? "",
                        pronouns: data["pronouns"] as? String ?? "",
                        name: data["name"] as? String ?? ""
                    )
                    completion(info)
                } else if let error = error {
                    print("Error fetching basic information: \(error)")
                    completion(nil) // Explicitly return nil if an error occurs
                } else {
                    print("No data found for userId: \(userId)")
                    completion(nil) // Explicitly return nil if no data is found
                }
            }
    }
}
