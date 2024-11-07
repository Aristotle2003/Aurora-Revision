import SwiftUI
import Firebase
import SDWebImageSwiftUI

struct FriendRequestsView: View {
    
    @State var currentUser: ChatUser
    @State private var friendRequests = [FriendRequest]()
    @State private var errorMessage = ""
    @State private var navigateToMainMessage = false
    
    

    var body: some View {
        NavigationStack{
            VStack {
                // Custom back button to navigate back to MainMessageView
                HStack {
                    Button(action: {
                        navigateToMainMessage = true
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                    .padding()
                    Spacer()
                }
                
                if friendRequests.isEmpty {
                    Text("No friend requests")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                } else {
                    List(friendRequests) { request in
                        HStack {
                            WebImage(url: URL(string: request.profileImageUrl))
                                .resizable()
                                .scaledToFill()
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                                .shadow(radius: 5)
                            
                            VStack(alignment: .leading) {
                                Text(request.fromEmail)
                                    .font(.headline)
                            }
                            
                            Spacer()
                            
                            Button("Accept") {
                                acceptFriendRequest(request)
                            }
                            .padding(.horizontal)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            
                            Button("Reject") {
                                rejectFriendRequest(request)
                            }
                            .padding(.horizontal)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                }
                Spacer()
            }
            .padding()
            .onAppear{
                fetchFriendRequests()
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToMainMessage) {
                MainMessagesView()
            }
            
        }
    }

    // Fetch friend requests
    private func fetchFriendRequests() {
        print(1)
        print("Fetching friend requests for user ID: \(currentUser.uid)")

        FirebaseManager.shared.firestore
            .collection("friend_request")
            .document(currentUser.uid)
            .collection("request_list")
            .getDocuments { snapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to fetch friend requests: \(error)"
                    print("Error fetching friend requests:", error) // Debug: Print error
                    return
                }

                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    self.errorMessage = "No friend requests found"
                    print("No friend requests found for user \(currentUser.uid)") // Debug: Print no requests
                    return
                }

                self.friendRequests = documents.map { document in
                    let data = document.data()
                    return FriendRequest(documentId: document.documentID, data: data)
                }

                print("Fetched friend requests:", self.friendRequests) // Debug: Print fetched requests
            }
    }


    // Accept friend request
    private func acceptFriendRequest(_ request: FriendRequest) {

        // Delete the friend request document
        FirebaseManager.shared.firestore
            .collection("friend_request")
            .document(currentUser.uid)
            .collection("request_list")
            .document(request.documentId)
            .delete { error in
                if let error = error {
                    self.errorMessage = "Failed to delete friend request: \(error)"
                    return
                }

                // Save sender's data in current user's Friends collection
                let senderData: [String: Any] = [
                    "uid": request.fromId,
                    "email": request.fromEmail,
                    "profileImageUrl": request.profileImageUrl
                ]

                FirebaseManager.shared.firestore
                    .collection("friends")
                    .document(currentUser.uid)
                    .collection("friend_list")
                    .document(request.fromId)
                    .setData(senderData) { error in
                        if let error = error {
                            self.errorMessage = "Failed to save sender as friend: \(error)"
                            return
                        }

                        // Save current user's data in sender's Friends collection
                        let currentUserData: [String: Any] = [
                            "uid": currentUser.uid,
                            "email": currentUser.email,
                            "profileImageUrl": currentUser.profileImageUrl
                        ]

                        FirebaseManager.shared.firestore
                            .collection("friends")
                            .document(request.fromId)
                            .collection("friend_list")
                            .document(currentUser.uid)
                            .setData(currentUserData) { error in
                                if let error = error {
                                    self.errorMessage = "Failed to save current user as friend: \(error)"
                                    return
                                }

                                // Remove from friendRequests list
                                self.friendRequests.removeAll { $0.documentId == request.documentId }
                            }
                    }
            }
    }

    // Reject friend request
    private func rejectFriendRequest(_ request: FriendRequest) {
        
        FirebaseManager.shared.firestore
            .collection("friend_request")
            .document(currentUser.uid)
            .collection("request_list")
            .document(request.documentId)
            .delete { error in
                if let error = error {
                    self.errorMessage = "Failed to delete friend request: \(error)"
                    return
                }

                // Remove from friendRequests list
                self.friendRequests.removeAll { $0.documentId == request.documentId }
            }
    }

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

            self.currentUser = ChatUser(data: data)
        }
    }
}

// Model for Friend Request
struct FriendRequest: Identifiable {
    let id = UUID()
    let documentId: String
    let fromId, fromEmail, profileImageUrl: String
    
    init(documentId: String, data: [String: Any]) {
        self.documentId = documentId
        self.fromId = data["fromUid"] as? String ?? ""
        self.fromEmail = data["fromEmail"] as? String ?? ""
        self.profileImageUrl = data["profileImageUrl"] as? String ?? ""
    }
}
