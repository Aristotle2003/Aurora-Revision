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
    @State private var showCalendarView = false
    @State private var showReportSheet = false
    @State private var reportContent = ""
    

    @ObservedObject var chatLogViewModel: ChatLogViewModel
    @StateObject private var messagesViewModel = MessagesViewModel()
    
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
            .navigationDestination(isPresented: $showCalendarView){
                CalendarMessagesView(messagesViewModel: messagesViewModel)
            }
            .navigationDestination(isPresented: $showMainMessageView) {
                MainMessagesView()
            }
            .sheet(isPresented: $showReportSheet) {
                VStack(spacing: 20) {
                    Text("Report User")
                        .font(.headline)
                    
                    TextField("Enter your report reason", text: $reportContent)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()
                    
                    HStack {
                        Button(action: {
                            // Close the sheet without submitting
                            showReportSheet = false
                        }) {
                            Text("Cancel")
                                .padding()
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            // Call the function to report the friend
                            reportFriend()
                            
                            // Close the sheet
                            showReportSheet = false
                        }) {
                            Text("Submit")
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
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
                    HStack {
                        Image(systemName: "pin.fill")
                        Text("Pin")
                    }
                }
                .padding()
                
                Button(action: {
                    unpinToTop()
                }) {
                    HStack {
                        Image(systemName: "pin.fill")
                        Text("unPin")
                    }
                }
                .padding()
                
                Button(action: {
                    messagesViewModel.searchSavedMessages(fromId: currentUser.uid, toId: chatUser.uid)
                    self.showCalendarView = true
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
                    unmuteFriend()
                }) {
                    Text("unMute Friend")
                }
                .padding()
                
                Button(action: {
                    deleteFriend{
                        showMainMessageView = true
                    }
                }) {
                    Text("Delete Friend")
                }
                .padding()
            }
            HStack{
                Button(action: {
                    showReportSheet = true
                }) {
                    Text("Report Friend")
                }
                .padding()
            }
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
     
     private func unpinToTop() {
         // 实现置顶逻辑
         FirebaseManager.shared.firestore
             .collection("friends")
             .document(currentUser.uid)
             .collection("friend_list")
             .document(chatUser.uid)
             .updateData(["isPinned": false]) { error in
                 if let error = error {
                     print("Failed to pin friend to top: \(error)")
                 } else {
                     print("Successfully unpinned friend to top")
                 }
             }
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
    
    private func unmuteFriend() { // 与pin逻辑相似
        // 实现静音好友的逻辑
        FirebaseManager.shared.firestore
            .collection("friends")
            .document(currentUser.uid)
            .collection("friend_list")
            .document(chatUser.uid)
            .updateData(["isMuted": false]) { error in
                if let error = error {
                    print("Failed to unmute friend: \(error)")
                } else {
                    print("Friend unmuted successfully")
                }
            }
    }
    
    private func deleteFriend(completion: @escaping () -> Void) {
        let dispatchGroup = DispatchGroup()

        // Begin tracking the first deletion
        dispatchGroup.enter()
        FirebaseManager.shared.firestore
            .collection("friends")
            .document(currentUser.uid)
            .collection("friend_list")
            .document(chatUser.uid)
            .delete { error in
                if let error = error {
                    print("Failed to delete friend: \(error)")
                } else {
                    print("Friend deleted successfully")
                }
                dispatchGroup.leave()
            }

        // Begin tracking the second deletion
        dispatchGroup.enter()
        FirebaseManager.shared.firestore
            .collection("friends")
            .document(chatUser.uid)
            .collection("friend_list")
            .document(currentUser.uid)
            .delete { error in
                if let error = error {
                    print("Failed to be deleted by friend: \(error)")
                } else {
                    print("Friend delete you successfully")
                }
                dispatchGroup.leave()
            }

        // Notify when both operations are complete
        dispatchGroup.notify(queue: .main) {
            // Introduce a slight delay before executing the completion handler
            DispatchQueue.main.asyncAfter(deadline: .now() + 10) { // 0.5 seconds delay
                completion()
            }
        }
    }



    
    private func reportFriend() {
            let reportData: [String: Any] = [
                "reporterUid": chatUser.uid,
                "reporteeUid": currentUser.uid,
                "timestamp": Timestamp(),
                "content": reportContent // Use the input from the text field
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
