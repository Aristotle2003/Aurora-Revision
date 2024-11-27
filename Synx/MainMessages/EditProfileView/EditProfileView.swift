import SwiftUI
import Firebase

struct EditProfileView: View {
    let currentUser: ChatUser
    let chatUser: ChatUser
    @State private var age: String = ""
    @State private var gender: String = ""
    @State private var email: String = ""
    @State private var bio: String = ""
    @State private var location: String = ""
    @State private var username: String = ""
    @Environment(\.dismiss) var dismiss
    @State private var backToProfileView = false
    @ObservedObject var chatLogViewModel: ChatLogViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        Form {
            Section(header: Text("Basic Information")) {
                TextField("Username", text: $username)
                TextField("Age", text: $age)
                TextField("Gender", text: $gender)
                TextField("Email", text: $email)
                TextField("Bio", text: $bio)
                TextField("Location", text: $location)
            }
            
            Button("Submit") {
                saveProfileInfo()
                presentationMode.wrappedValue.dismiss()
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .onAppear {
            loadCurrentInfo()
        }
        .navigationDestination(isPresented: $backToProfileView) {
            ProfileView(chatUser: chatUser, currentUser: currentUser, isCurrentUser: true, chatLogViewModel: chatLogViewModel)
        }
    }
    
    private func loadCurrentInfo() {
        FirebaseManager.shared.firestore
            .collection("basic_information")
            .document(currentUser.uid)
            .collection("information")
            .document("profile")
            .getDocument { snapshot, error in
                if let data = snapshot?.data() {
                    self.age = data["age"] as? String ?? ""
                    self.gender = data["gender"] as? String ?? ""
                    self.email = data["email"] as? String ?? ""
                    self.bio = data["bio"] as? String ?? ""
                    self.location = data["location"] as? String ?? ""
                    self.username = data["username"] as? String ?? ""
                } else if let error = error {
                    print("Error loading current information: \(error)")
                }
            }
    }
    
    private func saveProfileInfo() {
        let profileData: [String: Any] = [
            "age": age,
            "gender": gender,
            "email": email,
            "bio": bio,
            "location": location,
            "username": username
        ]
        
        FirebaseManager.shared.firestore
            .collection("basic_information")
            .document(currentUser.uid)
            .collection("information")
            .document("profile")
            .setData(profileData) { error in
                if let error = error {
                    print("Failed to save profile information: \(error)")
                } else {
                    print("Profile information saved successfully!")
                }
            }
        self.updateUsername()
    }
    
    private func updateUsername(){
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        
        let updatedData: [String: Any] = ["username": username]
        
        saveUsernameToCentralDb(uid: uid, data: updatedData)
    }
    
    private func saveUsernameToCentralDb(uid: String, data: [String: Any]) {
        let userRef = FirebaseManager.shared.firestore.collection("users").document(uid)
        userRef.updateData(data) { error in
            if let error = error {
                print("Failed to update profile: \(error)")
                return
            }
            print("Profile updated successfully")
            // 更新好友列表中的用户名和头像
            saveUsernameToFriends(uid: uid, data: data)
        }
    }

    private func saveUsernameToFriends(uid: String, data: [String: Any]) {
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
}
