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
    @State private var showReportSheet = false
    @State private var reportContent = ""
    @State private var showDeleteConfirmation = false
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage? = nil
    @State private var showConfirmationDialog = false
    @State private var savingImageUrl = ""
    @State private var showTemporaryImage = false
    @State private var shouldShowLogOutOptions = false
    @State private var isUserCurrentlyLoggedOut = false
    @State private var isPinned = false
    @State private var isMuted = false

    @ObservedObject var chatLogViewModel: ChatLogViewModel
    @StateObject private var messagesViewModel = MessagesViewModel()
    @Environment(\.presentationMode) var presentationMode
    
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
        VStack {
            // Custom Back Button
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .padding()
                Spacer()
            }
            
            // Profile Image Section
            if !showTemporaryImage {
                WebImage(url: URL(string: chatUser.profileImageUrl))
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .shadow(radius: 10)
                    .onTapGesture {
                        if isCurrentUser {
                            showImagePicker = true
                        }
                    }
            } else {
                WebImage(url: URL(string: self.savingImageUrl))
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .shadow(radius: 10)
                    .onTapGesture {
                        if isCurrentUser {
                            showImagePicker = true
                        }
                    }
            }
            
            Text(chatUser.username)
                .font(.title)
            
            Text(chatUser.email)
                .font(.headline)
                .foregroundColor(.gray)
            
            if let otherInfo = otherUserInfo {
                VStack(alignment: .leading) {
                    Text(otherInfo.bio)
                        .font(.headline)
                        .padding()
                    HStack {
                        if !otherInfo.age.isEmpty{
                            Text("\(otherInfo.age)ys old")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .padding(.horizontal, 10)
                                .background(Color.purple.opacity(0.2))
                                .cornerRadius(12)
                        }
                        if !otherInfo.pronouns.isEmpty{
                            Text(otherInfo.pronouns)
                                .font(.headline)
                                .foregroundColor(.gray)
                                .padding(.horizontal, 10)
                                .background(Color.purple.opacity(0.2))
                                .cornerRadius(12)
                        }
                        if !otherInfo.location.isEmpty{
                            Text(otherInfo.location)
                                .font(.headline)
                                .foregroundColor(.gray)
                                .padding(.horizontal, 10)
                                .background(Color.purple.opacity(0.2))
                                .cornerRadius(12)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
            }
            if isFriend{
                friendOptions
            } else {
                strangerOptions
            }
            Spacer()
        }
        .padding()
        .onAppear {
            checkIfFriend()
            fetchFriendSettings()
            fetchBasicInfo(for: chatUser.uid) { info in
                self.otherUserInfo = info
            }
        }
        .onDisappear{
            self.showTemporaryImage = false
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
                        // 关闭报告视图
                        showReportSheet = false
                    }) {
                        Text("Cancel")
                            .padding()
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        // 提交报告
                        reportFriend()
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
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("Confirm Deletion"),
                message: Text("Are you sure you want to delete this friend?"),
                primaryButton: .destructive(Text("Delete")) {
                    deleteFriend()
                },
                secondaryButton: .cancel()
            )
        }

        .navigationBarBackButtonHidden(true)
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

    
    // 好友选项
    private var friendOptions: some View {
        VStack(spacing: 20) {
            NavigationLink(destination: ChatLogView(vm: chatLogViewModel)
                .onAppear {
                    chatLogViewModel.chatUser = chatUser
                    chatLogViewModel.initializeMessages()
                    chatLogViewModel.startAutoSend()
                }) {
                    Image(systemName: "paperplane.fill") // 您可以使用系统图标或自定义图像
                    Text("Message")
                        .padding()
                }
                .font(.headline)
                .frame(maxWidth: .greatestFiniteMagnitude/2)
                .foregroundColor(Color.purple)
                .background(Color.purple.opacity(0.5))
                .cornerRadius(24)
            
            // Action Sheet Options
            VStack(spacing: 10) {
                Toggle(isOn: $isPinned) {
                    HStack {
                        Image(systemName: "pin.fill")
                        Text("Pin")
                    }
                }
                .padding()
                .onChange(of: isPinned) { newValue in
                    if newValue {
                        pinToTop()
                    } else {
                        unpinToTop()
                    }
                }
                
                Toggle(isOn: $isMuted) {
                    HStack {
                        Image(systemName: "bell.slash.fill")
                        Text("Mute")
                    }
                }
                .padding()
                .onChange(of: isMuted) { newValue in
                    if newValue {
                        muteFriend()
                    } else {
                        unmuteFriend()
                    }
                }
                
                Button(action: {
                    showReportSheet = true
                }) {
                    HStack {
                        Image(systemName: "exclamationmark.bubble.fill")
                        Text("Report")
                    }
                    .foregroundColor(.red)
                }
                .padding()
                
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("Delete")
                    }
                    .foregroundColor(.red)
                }
                .padding()
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
        }
    }
    
    // 陌生人选项
    private var strangerOptions: some View {
        VStack(spacing: 20) {
            Button(action: {
                sendFriendRequest()
            }) {
                Image(systemName: "person.badge.plus.fill")
                Text(friendRequestSent ? "Friend Request Sent" : "Add Friend")
                    .padding()
            }
            .font(.headline)
            .frame(maxWidth: .greatestFiniteMagnitude/2)
            .foregroundColor(.purple)
            .background(Color.purple.opacity(0.5))
            .cornerRadius(24)
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
            "username": currentUser.username,
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

    
    private func pinToTop() {
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
        FirebaseManager.shared.firestore
            .collection("friends")
            .document(currentUser.uid)
            .collection("friend_list")
            .document(chatUser.uid)
            .updateData(["isPinned": false]) { error in
                if let error = error {
                    print("Failed to unpin friend: \(error)")
                } else {
                    print("Successfully unpinned friend")
                }
            }
    }
    
    private func muteFriend() {
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
    
    private func unmuteFriend() {
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
    
    private func deleteFriend() {
        // 删除好友逻辑
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
                    // 删除成功后，跳转到 MainMessagesView
                    presentationMode.wrappedValue.dismiss()                }
            }
        FirebaseManager.shared.firestore
            .collection("friends")
            .document(chatUser.uid)
            .collection("friend_list")
            .document(currentUser.uid)
            .delete { error in
                if let error = error {
                    print("Failed to be deleted by friend: \(error)")
                } else {
                    print("Friend deleted you successfully")
                }
            }
    }
    
    private func reportFriend() {
        let reportData: [String: Any] = [
            "reporterUid": currentUser.uid,
            "reporteeUid": chatUser.uid,
            "timestamp": Timestamp(),
            "content": reportContent // 用户输入的举报内容
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

     // 添加获取 isPinned 和 isMuted 状态的方法
    func fetchFriendSettings() {
        guard let currentUserID = FirebaseManager.shared.auth.currentUser?.uid else { return }
        let friendRef = FirebaseManager.shared.firestore
            .collection("friends")
            .document(currentUserID)
            .collection("friend_list")
            .document(chatUser.uid)

        friendRef.getDocument { snapshot, error in
            if let error = error {
                print("Failed to fetch user settings: \(error)")
                return
            }

            if let data = snapshot?.data() {
                self.isPinned = data["isPinned"] as? Bool ?? false
                self.isMuted = data["isMuted"] as? Bool ?? false
                print(isPinned, isMuted)
            } else {
                print("No data found for user settings")
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
    var username: String
    var birthdate: String
    var pronouns: String
    var name: String
}


