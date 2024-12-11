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

    @StateObject private var chatLogViewModel = ChatLogViewModel(chatUser: nil)
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
        ZStack{
            Color(red: 0.976, green: 0.980, blue: 1.0)
                .ignoresSafeArea()
            VStack {
                let topbarheight = UIScreen.main.bounds.height * 0.055
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image("chatlogviewbackbutton")
                            .resizable()
                            .frame(width: 24, height: 24)
                            .padding(.leading, 20)
                    }
                    
                    Spacer()
                    
                    if isFriend{
                        NavigationLink(destination: CalendarMessagesView(messagesViewModel: messagesViewModel)
                            .onAppear {
                                messagesViewModel.searchSavedMessages(fromId: currentUser.uid, toId: chatUser.uid)
                            }) {
                                Image("searchchathistorybuttoninfriendprofile")
                                    .resizable()
                                    .frame(width: 24, height: 24)
                                    .padding(.trailing, 20)
                            }
                    }
                }
                .frame(height: topbarheight)
                Spacer()
                    .frame(height: UIScreen.main.bounds.height*0.03403755868)
                ScrollView{
                    
                    // Profile Image Section
                    if !showTemporaryImage {
                        WebImage(url: URL(string: chatUser.profileImageUrl))
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
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
                            .onTapGesture {
                                if isCurrentUser {
                                    showImagePicker = true
                                }
                            }
                    }
                    
                    Spacer()
                        .frame(height: 8)
                    
                    Text(chatUser.username)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(red: 0.337, green: 0.337, blue: 0.337))
                    if let otherInfo = otherUserInfo{
                        Text("@\(otherInfo.name)")
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 0.490, green: 0.490, blue: 0.490))
                    }
                    Spacer()
                        .frame(height: 20)
                    
                    if let otherInfo = otherUserInfo {
                        VStack(alignment: .leading) {
                            Text(otherInfo.bio)
                                .font(.system(size: 14))
                                .foregroundColor(Color(red: 0.490, green: 0.490, blue: 0.490))
                                .padding(.horizontal, 12)
                                .lineLimit(nil) // Allow unlimited lines
                                .fixedSize(horizontal: false, vertical: true) // Ensure wrapping for long text
                            HStack {
                                if !otherInfo.age.isEmpty{
                                    Text("\(otherInfo.age)ys old")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(red: 0.490, green: 0.490, blue: 0.490))
                                        .padding(8)
                                        .background(Color(red: 0.898, green: 0.910, blue: 0.996))
                                        .cornerRadius(50)
                                }
                                if !otherInfo.pronouns.isEmpty{
                                    Text(otherInfo.pronouns)
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(red: 0.490, green: 0.490, blue: 0.490))
                                        .padding(8)
                                        .background(Color(red: 0.898, green: 0.910, blue: 0.996))
                                        .cornerRadius(50)
                                }
                                if !otherInfo.location.isEmpty{
                                    Text(otherInfo.location)
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(red: 0.490, green: 0.490, blue: 0.490))
                                        .padding(8)
                                        .background(Color(red: 0.898, green: 0.910, blue: 0.996))
                                        .cornerRadius(50)
                                }
                                Spacer()
                            }
                            .padding(.leading, 12)
                            .frame(maxWidth: .infinity)
                        }
                        .padding(8)
                    }
                    if isFriend{
                        friendOptions
                    } else {
                        strangerOptions
                    }
                    Spacer()
                }
            }
        }
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
        .navigationDestination(isPresented: $showChatLogView) {
            ChatLogView(vm: chatLogViewModel)
                .onAppear {
                    chatLogViewModel.chatUser = self.chatUser
                    chatLogViewModel.initializeMessages()
                }
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

    @State private var showChatLogView = false
    // 好友选项
    private var friendOptions: some View {
        VStack(spacing: 20) {
            Button(action: {
                showChatLogView = true
                    
                }) {
                    Image("messagebuttonforfriends")
                        .resizable()
                        .scaledToFit()
                        .frame(width: UIScreen.main.bounds.width - 40)
                        .padding(20)
                }
            
            // Action Sheet Options
            
                
                
                VStack(spacing: 0){
                    ZStack{
                        Image("muteandpinbuttons")
                        HStack{
                            Spacer()
                            VStack{
                                VStack{
                                    Toggle("", isOn: $isPinned)
                                        .padding(.trailing, 45)
                                        .labelsHidden() // Hides the label so only the switch is visible
                                        .tint(Color(red: 194 / 255.0, green: 196 / 255.0, blue: 240 / 255.0)) // Apply custom purple color (#C2C4F0)
                                        .padding(12)
                                        .onChange(of: isPinned) { newValue in
                                            if newValue {
                                                pinToTop()
                                            } else {
                                                unpinToTop()
                                            }
                                        }
                                }
                                VStack{
                                    Toggle("", isOn: $isMuted)
                                        .padding(.trailing, 45)
                                        .padding(12)
                                        .labelsHidden() // Hide the label to display only the switch
                                        .tint(Color(red: 194 / 255.0, green: 196 / 255.0, blue: 240 / 255.0)) // Apply custom purple color (#C2C4F0)
                                        .onChange(of: isMuted) { newValue in
                                            if newValue {
                                                muteFriend()
                                            } else {
                                                unmuteFriend()
                                            }
                                        }
                                }
                            }
                        }
                    }
                    Button(action: {
                        showReportSheet = true
                    }) {
                        HStack {
                            Image("reportbutton")
                        }
                    }
                    
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        HStack {
                            Image("deletefriendbutton")
                        }
                    }
                }
        }
    }
    
    // 陌生人选项
    /*private var strangerOptions: some View {

        VStack(spacing: 20) {
            Button(action: {
                sendFriendRequest()
            }) {
                Image(friendRequestSent?, "requestedbuttonforstrangerprofile", : "addfriendbuttonforprofileview"）
                 .resizable()
                 .scaledToFit()
                 .frame(width: UIScreen.main.bounds.width - 40)
                 .padding(20)
            }
        }*/
    private var strangerOptions: some View {
        VStack(spacing: 20) {
            Button(action: {
                sendFriendRequest()
            }) {
                Image(friendRequestSent ? "requestedbuttonforstrangerprofile" : "addfriendbuttonforstrangerprofile")
                    .resizable()
                    .scaledToFit()
                    .frame(width: UIScreen.main.bounds.width - 40)
                    .padding(20)
            }
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


