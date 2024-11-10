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
                        friendOptions
                    } else {
                        strangerOptions
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
    
    // Friend Profile 选项
    private var friendOptions: some View {
        VStack(spacing: 20) {
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
            
            HStack(spacing: 20) {
                Button(action: {
                    pinToTop()
                }) {
                    Text("Pin to Top")
                }
                .padding()
                
                Button(action: {
                    searchSavedMessages()
                }) {
                    Text("Search Saved Messages")
                }
                .padding()
            }
            
            HStack(spacing: 20) {
                Button(action: {
                    muteFriend()
                }) {
                    Text("Mute Friend")
                }
                .padding()
                
                Button(action: {
                    blockFriend()
                }) {
                    Text("Block Friend")
                }
                .padding()
            }
            
            Button(action: {
                reportFriend()
            }) {
                Text("Report Friend")
            }
            .padding()
        }
    }
    
    // Stranger Profile 选项
    private var strangerOptions: some View {
        VStack(spacing: 20) {
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
    
    // 各种操作的函数逻辑, 这里我觉得pinned friend 应当为一个field在friend_list的document里
    private func pinToTop() {
        // 实现置顶逻辑
        FirebaseManager.shared.firestore
            .collection("friends")
            .document(currentUser.uid)
            .collection("friend_list")
            .document(chatUser.uid)
            .updateData(["isPinned": true]) { error in
                if let error = error {
                    print("Failed to pin friend to top: \(error)")
                } else {
                    print("Successfully pinned friend to top")
                }
            }
    }
    
    private func searchSavedMessages() { //还没有实现，先装饰一下， 没想好，要不要直接转跳到SavedMessagesView？还是说先找到那条消息，然后现实那条消息的上下文？
        // 实现查看保存的消息记录的逻辑
        FirebaseManager.shared.firestore
            .collection("saving_messages")
            .document(currentUser.uid)
            .collection(chatUser.uid)

            
            
    }
    
    private func muteFriend() { // 与pin逻辑相似
        // 实现静音好友的逻辑
        FirebaseManager.shared.firestore
            .collection("friends")
            .document(currentUser.uid)
            .collection("friend_list")
            .document(chatUser.uid)
            .updateData(["isMuted": true]) { error in
                if let error = error {
                    print("Failed to mute friend: \(error)")
                } else {
                    print("Friend muted successfully")
                }
            }
    }
    
    private func blockFriend() { //目前只是单纯删除一下好友
        // 实现屏蔽好友的逻辑
        FirebaseManager.shared.firestore
            .collection("friends")
            .document(currentUser.uid)
            .collection("friend_list")
            .document(chatUser.uid)
            .delete { error in
                if let error = error {
                    print("Failed to block friend: \(error)")
                } else {
                    print("Friend blocked successfully")
                }
            }
    }
    
    private func reportFriend() {
        // 实现举报好友的逻辑
        let reportData: [String: Any] = [
            "reporterUid": chatUser.uid,
            "reporteeUid": currentUser.uid,
            "timestamp": Timestamp(),
            "content": "This user is spamming" //这边后面要增加一个输入框来写举报原因
        ]
        
        FirebaseManager.shared.firestore
            .collection("reports")
            .document()
            .setData(reportData) { error in
                if let error = error {
                    print("Failed to report friend: \(error)")
                } else {
                    print("Friend reported successfully")
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
