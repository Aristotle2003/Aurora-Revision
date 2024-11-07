import SwiftUI
import SDWebImageSwiftUI
import Firebase

import SwiftUI
import SDWebImageSwiftUI
import Firebase

struct ProfileView: View {
    let chatUser: ChatUser
    let currentUser: ChatUser
    let isCurrentUser: Bool
    @State var errorMessage = ""
    @State var isFriend: Bool = false
    @State var friendRequestSent: Bool = false
    @State var basicInfo: BasicInfo? = nil // For current user
    @State var otherUserInfo: BasicInfo? = nil // For other users
    @State private var showEditProfile = false // Controls navigation to EditProfileView
    @State private var showMainMessageView = false

    @ObservedObject var chatLogViewModel: ChatLogViewModel
    
    var body: some View {
        NavigationStack {
            VStack {
                // Custom back button to navigate back to MainMessageView
                HStack {
                    Button(action: {
                        showMainMessageView = true
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                    .padding()
                    Spacer()
                }
                
                WebImage(url: URL(string: chatUser.profileImageUrl))
                    .resizable()
                    .scaledToFill()
                    .frame(width: 150, height: 150)
                    .clipShape(Circle())
                    .shadow(radius: 10)
                
                Text(chatUser.email)
                    .font(.title)
                    .padding()
                
                if isCurrentUser, let info = basicInfo {
                    // Display basic info for the current user in a standard style
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Age: \(info.age)")
                        Text("Gender: \(info.gender)")
                        Text("Location: \(info.location)")
                        Text("Bio: \(info.bio)")
                    }
                    .padding()
                } else if let otherInfo = otherUserInfo {
                    // Display basic info for other users in a different style
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Age: \(otherInfo.age)")
                            .font(.headline)
                            .foregroundColor(.blue)
                        Text("Gender: \(otherInfo.gender)")
                            .font(.headline)
                            .foregroundColor(.blue)
                        Text("Location: \(otherInfo.location)")
                            .font(.headline)
                            .foregroundColor(.blue)
                        Text("Bio: \(otherInfo.bio)")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                }
                
                if isCurrentUser {
                    // Edit button for the current user
                    Button(action: {
                        showEditProfile = true
                    }) {
                        Image(systemName: "pencil")
                            .font(.title2)
                    }
                    .position(x: UIScreen.main.bounds.width - 140, y: -100)
                    .padding()
                } else {
                    if isFriend {
                        NavigationLink(destination: ChatLogView(vm: chatLogViewModel)
                            .onAppear {
                                chatLogViewModel.chatUser = chatUser
                            }) {
                            Text("Message")
                                .font(.headline)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .padding()
                    } else {
                        Button(action: {
                            sendFriendRequest()
                        }) {
                            Text(friendRequestSent ? "Request Sent" : "Send Friend Request")
                                .font(.headline)
                                .padding()
                                .background(friendRequestSent ? Color.gray : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .padding()
                        .disabled(friendRequestSent)
                    }
                }
                
                Spacer()
            }
            .padding()
            .onAppear {
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
            .navigationBarBackButtonHidden(true) // Hide the default back button
            .navigationDestination(isPresented: $showEditProfile) {
                EditProfileView(currentUser: currentUser, chatUser: chatUser, chatLogViewModel: chatLogViewModel)
            }
            .navigationDestination(isPresented: $showMainMessageView) {
                MainMessagesView()
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
    
    private func sendFriendRequest() {
        let friendRequestData: [String: Any] = [
            "fromUid": currentUser.uid,
            "fromEmail": currentUser.email,
            "profileImageUrl": currentUser.profileImageUrl,
            "status": "pending",
            "timestamp": Timestamp()
        ]
        
        FirebaseManager.shared.firestore
            .collection("friend_request")
            .document(chatUser.uid)
            .collection("request_list")
            .document()
            .setData(friendRequestData) { error in
                if let error = error {
                    self.errorMessage = "Failed to send friend request: \(error)"
                    print("Failed to send friend request:", error)
                    return
                }
                self.friendRequestSent = true
                self.errorMessage = "Friend request sent successfully!"
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
                        location: data["location"] as? String ?? ""
                    )
                    completion(info)
                } else if let error = error {
                    print("Error fetching basic information: \(error)")
                    completion(nil)
                }
            }
    }
}




struct BasicInfo {
    var age: String
    var gender: String
    var email: String
    var bio: String
    var location: String
}

