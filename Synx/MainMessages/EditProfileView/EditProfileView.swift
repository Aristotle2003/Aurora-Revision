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
    @Environment(\.dismiss) var dismiss 
    @State private var backToProfileView = false
    @ObservedObject var chatLogViewModel: ChatLogViewModel
    
    var body: some View {
        Form {
            Section(header: Text("Basic Information")) {
                TextField("Age", text: $age)
                TextField("Gender", text: $gender)
                TextField("Email", text: $email)
                TextField("Bio", text: $bio)
                TextField("Location", text: $location)
            }
            
            Button("Submit") {
                saveProfileInfo()
                backToProfileView = true
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
            "location": location
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
    }
}
