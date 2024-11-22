import SwiftUI
import SDWebImageSwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth
import Lottie

struct FirebaseConstants {
    static let fromId = "fromId"
    static let toId = "toId"
    static let text = "text"
    static let seen = "seen"
    static let sender = "sender"
    static let timestamp = "timestamp"
}

struct ChatMessage: Identifiable {
    var id: String { documentId }
    let documentId: String
    let fromId, toId, text: String
    let timeStamp: Timestamp
    var seen: Bool
    let sender: String
    
    init(documentId: String, data: [String: Any]) {
        self.documentId = documentId
        self.fromId = data[FirebaseConstants.fromId] as? String ?? ""
        self.toId = data[FirebaseConstants.toId] as? String ?? ""
        self.text = data[FirebaseConstants.text] as? String ?? ""
        self.timeStamp = data["timeStamp"] as? Timestamp ?? Timestamp()
        self.seen = data[FirebaseConstants.seen] as? Bool ?? false
        self.sender = data[FirebaseConstants.sender] as? String ?? "Unknown"
    }
}

class ChatLogViewModel: ObservableObject {
    @Published var chatText = ""
    @Published var errorMessage = ""
    @Published var latestSenderMessage: ChatMessage?
    @Published var latestRecipientMessage: ChatMessage?
    @Published var chatUser: ChatUser?
    @Published var showSavedMessagesWindow = false
    @Published var savedMessages = [ChatMessage]()
    
    var timer: Timer?
    var seenCheckTimer: Timer?
    
    init(chatUser: ChatUser?) {
        self.chatUser = chatUser
    }

    // Fetch the saved messages between the current user and the chat user
    func fetchSavedMessages() {
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = chatUser?.uid else { return }

        FirebaseManager.shared.firestore
            .collection("saving_messages")
            .document(fromId)
            .collection(toId)
            .order(by: "timestamp")
            .getDocuments { snapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to fetch saved messages: \(error)"
                    return
                }
                self.savedMessages = snapshot?.documents.compactMap { doc in
                    let data = doc.data()
                    return ChatMessage(documentId: doc.documentID, data: data)
                } ?? []
            }
    }

    func initializeMessages() {
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = chatUser?.uid else { return }

        // Fetch the latest message sent by the current user
        FirebaseManager.shared.firestore
            .collection("messages")
            .document(fromId)
            .collection(toId)
            .order(by: "timeStamp", descending: true)
            .limit(to: 1)
            .getDocuments { querySnapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to fetch sender's latest message: \(error)"
                    return
                }
                if let document = querySnapshot?.documents.first {
                    let data = document.data()
                    self.latestSenderMessage = ChatMessage(documentId: document.documentID, data: data)
                    self.chatText = self.latestSenderMessage?.text ?? ""
                }
            }

        // Fetch the latest message sent by the recipient
        FirebaseManager.shared.firestore
            .collection("messages")
            .document(toId)
            .collection(fromId)
            .order(by: "timeStamp", descending: true)
            .limit(to: 1)
            .getDocuments { querySnapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to fetch recipient's latest message: \(error)"
                    return
                }
                if let document = querySnapshot?.documents.first {
                    let data = document.data()
                    self.latestRecipientMessage = ChatMessage(documentId: document.documentID, data: data)
                }
            }
    }

    func startAutoSend() {
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            print(self.chatText)
            self.handleSend()
        }
    }

    func stopAutoSend() {
        timer?.invalidate()
        timer = nil
    }
    
    func markLatestMessageAsSeen() {
        guard let currentUserId = FirebaseManager.shared.auth.currentUser?.uid,
              let chatUserId = chatUser?.uid else { return }

        // Fetch only the latest message from the recipient
        FirebaseManager.shared.firestore
            .collection("messages")
            .document(chatUserId)
            .collection(currentUserId)
            .order(by: "timeStamp", descending: true)
            .limit(to: 1) // Limit to the latest message
            .getDocuments { querySnapshot, error in
                if let error = error {
                    print("Failed to fetch recipient's latest message: \(error)")
                    return
                }

                guard let document = querySnapshot?.documents.first else {
                    print("No messages found")
                    return
                }

                let data = document.data()
                if let seen = data["seen"] as? Bool, !seen {
                    // Mark the latest message as seen
                    document.reference.updateData(["seen": true]) { error in
                        if let error = error {
                            print("Failed to update the latest message as seen: \(error)")
                        } else {
                            print("Successfully marked the latest message as seen")
                        }
                    }
                } else {
                    print("The latest message is already marked as seen")
                }
            }
    }

    
    /// Set active status to `true` for the current user to a specific chatUser
        func setActiveStatusToTrue() {
            
            guard let currentUserId = FirebaseManager.shared.auth.currentUser?.uid,
                  let chatUserId = chatUser?.uid else { return }

            let activeStatusRef = FirebaseManager.shared.firestore
                .collection("activeStatus")
                .document(currentUserId)
                .collection("activeList")
                .document(chatUserId)

            activeStatusRef.setData(["isActive": true], merge: true) { error in
                if let error = error {
                    print("Failed to set active status to true: \(error)")
                } else {
                    print("Active status set to true for \(chatUserId)")
                }
            }
        }

        /// Set active status to `false` for the current user to a specific chatUser
        func setActiveStatusToFalse() {
            guard let currentUserId = FirebaseManager.shared.auth.currentUser?.uid,
                  let chatUserId = chatUser?.uid else { return }

            let activeStatusRef = FirebaseManager.shared.firestore
                .collection("activeStatus")
                .document(currentUserId)
                .collection("activeList")
                .document(chatUserId)

            activeStatusRef.setData(["isActive": false], merge: true) { error in
                if let error = error {
                    print("Failed to set active status to false: \(error)")
                } else {
                    print("Active status set to false for \(chatUserId)")
                }
            }
        }
    
    func markMessageAsSeen(for userId: String) {
            guard let currentUserId = FirebaseManager.shared.auth.currentUser?.uid else {
                self.errorMessage = "Could not find firebase uid"
                return
            }

            // Reference to the user's friend list
            let friendRef = FirebaseManager.shared.firestore
                .collection("friends")
                .document(currentUserId)
                .collection("friend_list")
                .document(userId)

            // Update `hasUnseenLatestMessage` to false
            friendRef.updateData(["hasUnseenLatestMessage": false]) { error in
                if let error = error {
                    print("Failed to update hasUnseenLatestMessage: \(error)")
                    return
                }
                print("Successfully updated hasUnseenLatestMessage to false")
            }
        }
    
    func fetchLatestMessages() {
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = chatUser?.uid else { return }
        
        // Fetch latest message sent by the current user
        FirebaseManager.shared.firestore
            .collection("messages")
            .document(fromId)
            .collection(toId)
            .order(by: "timeStamp", descending: true)
            .limit(to: 1)
            .getDocuments { querySnapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to fetch sender's latest message: \(error)"
                    return
                }
                if let document = querySnapshot?.documents.first {
                    let data = document.data()
                    self.latestSenderMessage = ChatMessage(documentId: document.documentID, data: data)
                }
            }
        // Fetch the latest message sent by the recipient
        FirebaseManager.shared.firestore
            .collection("messages")
            .document(toId)
            .collection(fromId)
            .order(by: "timeStamp", descending: true)
            .limit(to: 1)
            .getDocuments { querySnapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to fetch recipient's latest message: \(error)"
                    return
                }
                if let document = querySnapshot?.documents.first {
                    let data = document.data()
                    self.latestRecipientMessage = ChatMessage(documentId: document.documentID, data: data)
                }
            }
    }

    func handleSend() {
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = chatUser?.uid else { return }
        
        let recipientActiveStatusRef = FirebaseManager.shared.firestore
            .collection("activeStatus")
            .document(toId)
            .collection("activeList")
            .document(fromId)
        
        recipientActiveStatusRef.getDocument { snapshot, error in
            if let error = error {
                print("Failed to fetch recipient active status: \(error)")
                return
            }
            
            let isRecipientActiveToMe = snapshot?.data()?["isActive"] as? Bool ?? false
            
            let messageData: [String: Any] = [
                "fromId": fromId,
                "toId": toId,
                "text": self.chatText,
                "timeStamp": Timestamp(),
                "seen": isRecipientActiveToMe, // Mark as seen if the recipient is active
                "sender": "Me"
            ]
            
            if self.chatText == self.latestSenderMessage?.text {
                self.fetchLatestMessages()
                return  // Skip sending if the message is the same as the previous one
            }
            
            FirebaseManager.shared.firestore
                .collection("messages")
                .document(fromId)
                .collection(toId)
                .addDocument(data: messageData) { error in
                    if let error = error {
                        self.errorMessage = "Failed to send message: \(error)"
                        return
                    }
                    
                    // 更新当前用户好友列表中的好友的 latestMessageTimestamp
                    self.updateFriendLatestMessageTimestampForRecipient(friendId: toId)
                    self.updateFriendLatestMessageTimestampForSelf(friendId: toId)
                    self.fetchLatestMessages()
                }
        }
    }

         // 更新当前用户好友列表中的好友的 latestMessageTimestamp
        private func updateFriendLatestMessageTimestampForSelf(friendId: String) {
            guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
            let timestamp = Timestamp()
        
            let friendRef = FirebaseManager.shared.firestore
                .collection("friends")
                .document(uid)
                .collection("friend_list")
                .document(friendId)
        
            friendRef.updateData(["latestMessageTimestamp": timestamp]) { error in
                if let error = error {
                    print("Failed to update latestMessageTimestamp for friend: \(error)")
                    return
                }
                print("Successfully updated latestMessageTimestamp for friend")
            }
        }
        
        private func updateFriendLatestMessageTimestampForRecipient(friendId: String) {
            guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
            let timestamp = Timestamp()
        
            let friendRef = FirebaseManager.shared.firestore
                .collection("friends")
                .document(friendId)
                .collection("friend_list")
                .document(uid)
        
            friendRef.updateData(["latestMessageTimestamp": timestamp]) { error in
                if let error = error {
                    print("Failed to update latestMessageTimestamp for friend: \(error)")
                    return
                }
                print("Successfully updated latestMessageTimestamp for friend")
            }
        }
    // Save the message to Firebase
    func saveMessage(sender: String, messageText: String, timestamp: Timestamp) {
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = chatUser?.uid else { return }

        let saveData: [String: Any] = [
            FirebaseConstants.sender: sender,
            FirebaseConstants.text: messageText,
            "timestamp": timestamp,
            "fromId": fromId,
            "toId": toId
        ]

        FirebaseManager.shared.firestore
            .collection("saving_messages")
            .document(fromId)
            .collection(toId)
            .addDocument(data: saveData) { error in
                if let error = error {
                    self.errorMessage = "Failed to save message: \(error)"
                    return
                }
                print("Message saved successfully.")
            }
    }
}

struct ChatLogView: View {
    @ObservedObject var vm: ChatLogViewModel
    @State private var navigateToMainMessageView = false
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack{
                Image("chatlogviewbackground")
                    .resizable()
                    .ignoresSafeArea(.all, edges: .all)
                VStack{
                    let topbarheight = UIScreen.main.bounds.height * 0.07
                    HStack{
                        Button(action: {
                            navigateToMainMessageView = true
                        }) {
                            Image("chatlogviewbackbutton")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .padding(.leading, 20)
                                //.padding(8)
                        }
                        
                        Spacer()
                        Image("auroratext")
                            .resizable()
                            .scaledToFill()
                            .frame(width: UIScreen.main.bounds.width * 0.1832, height: UIScreen.main.bounds.height * 0.0198)
                            //.padding(12)
                        
                        Spacer()
                        
                        Button(action: {
                            print("Three dots button tapped")
                        }) {
                            Image("chatlogviewthreedotsbutton")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .padding(.trailing, 20)
                                //.padding(8)
                        }
                    }
                    //.background(Color.white)
                    .frame(height: topbarheight)
                    
                    let geoheight = UIScreen.main.bounds.height - topbarheight - UIScreen.main.bounds.height * 0.455 //不许动
                    GeometryReader { geometry in
                        let width = geometry.size.width * 0.895 // 90% of screen width
                        let height = width * 0.549
                        VStack(spacing: 16){
                            ZStack {
                                // Background Image
                                Image("chatlogviewwhitebox")
                                    .resizable()
                                    .frame(width: width, height: height)

                                // Content
                                VStack(spacing: 12) { // 12 points of spacing between sections
                                    // HStack for Profile Photo
                                    HStack {
                                        if let chatUser = vm.chatUser {
                                            NavigationLink(destination: ProfileView(
                                                chatUser: chatUser,
                                                currentUser: getCurrentUser(),
                                                isCurrentUser: false,
                                                chatLogViewModel: vm
                                            )) {
                                                WebImage(url: URL(string: vm.chatUser?.profileImageUrl ?? ""))
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 42, height: 42)
                                                    .clipShape(Circle())
                                            }
                                        }
                                        VStack(alignment: .leading, spacing: 4) {
                                            if let username = vm.chatUser?.username {
                                                Text(username)
                                                    .font(.headline) // Customize font style
                                                    .foregroundColor(.primary) // Set text color
                                            } else {
                                                Text("Unknown User") // Fallback text
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(.leading, 20)
                                    .padding(.top, 20)

                                    // Scrollable Text Section
                                    GeometryReader { geometry in
                                        VStack {
                                            Spacer(minLength: 0) // Top Spacer

                                            if let recipientMessage = vm.latestRecipientMessage {
                                                ScrollView {
                                                    VStack {
                                                        // Calculate dynamic spacing based on the number of lines
                                                        Spacer(minLength: {
                                                            let maxWidth = geometry.size.width - 40
                                                            let fontHeight = UIFont.systemFont(ofSize: 18).lineHeight
                                                            let lineCount = recipientMessage.text.boundingRect(
                                                                with: CGSize(width: maxWidth, height: .infinity),
                                                                options: [.usesLineFragmentOrigin, .usesFontLeading],
                                                                attributes: [.font: UIFont.systemFont(ofSize: 18)],
                                                                context: nil
                                                            ).height / fontHeight

                                                            if lineCount <= 1 {
                                                                return max((geometry.size.height - 20) / 2, 0)
                                                            } else if lineCount == 2 {
                                                                return max((geometry.size.height - 45) / 1.7, 0)
                                                            } else {
                                                                return 0 // For 3+ lines, no additional spacer
                                                            }
                                                        }())

                                                        Text(recipientMessage.text)
                                                            .font(Font.system(size: 18))
                                                            .multilineTextAlignment(.center)
                                                            .foregroundColor(Color(red: 0.553, green: 0.525, blue: 0.525))
                                                            .frame(maxWidth: geometry.size.width - 40)
                                                            .padding(.horizontal, 20)
                                                    }
                                                }
                                            }
                                            
                                            Spacer(minLength: 0) // Bottom Spacer
                                        }
                                    }
                                    
                                    // HStack for Save Button
                                    HStack {
                                        Spacer()
                                        if let recipientMessage = vm.latestRecipientMessage, !recipientMessage.text.isEmpty {
                                            Button(action: {
                                                vm.saveMessage(sender: vm.chatUser?.username ?? "", messageText: recipientMessage.text, timestamp: recipientMessage.timeStamp)
                                            }) {
                                                if #available(iOS 18.0, *) {
                                                    // iOS 18.0 or newer: Only show the first frame of the Lottie file
                                                    LottieAnimationViewContainer(filename: "Save Button", isInteractive: false)
                                                        .frame(width: 24, height: 24)
                                                } else {
                                                    // iOS versions below 18.0: Use full Lottie animation with interactivity
                                                    LottieAnimationViewContainer(filename: "Save Button", isInteractive: true)
                                                        .frame(width: 24, height: 24)
                                                }
                                            }
                                            .padding(.trailing, 20)
                                        }
                                    }
                                    .padding(.bottom, 24)
                                }
                            }
                            //.background(Color.blue) // ZStack background color
                            .frame(width: width, height: height)

                            
                            ZStack {
                                // Background Image
                                Image("chatlogviewpurplebox")
                                    .resizable()
                                    .frame(width: width, height: height)

                                // Top-left Seen/Unseen Button
                                VStack {
                                    HStack {
                                        if let senderMessage = vm.latestSenderMessage {
                                            if senderMessage.seen {
                                                Image("Seen")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 52, height: 19)
                                            } else {
                                                Image("Unseen")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 44, height: 20)
                                            }
                                        }
                                        Spacer()
                                    }
                                    .padding(.leading, 20)
                                    .padding(.top, 20)

                                    Spacer() // Push everything else below
                                }

                                // Centered Text Input
                                VStack {
                                    Spacer() // Push TextEditor down

                                    ScrollView {
                                        TextEditor(text: $vm.chatText)
                                            .font(Font.system(size: 18))
                                            .foregroundColor(Color(red: 0.553, green: 0.525, blue: 0.525))
                                            .focused($isInputFocused)
                                            .multilineTextAlignment(.center) // Center-align text inside TextEditor
                                            .background(Color.clear) // Transparent background
                                            .scrollContentBackground(.hidden) // Ensures scrollable area is transparent
                                            .frame(maxWidth: .infinity, minHeight: 50) // Flexible width and minimum height
                                            .padding(.horizontal, 20) // Add spacing from sides
                                    }
                                    .frame(height: 60) // Set the height of the ScrollView
                                    .padding(.top, 5)
                                    .padding(.horizontal, 20)

                                    Spacer() // Push TextEditor
                                }
                                .onAppear {
                                    isInputFocused = true // Auto-focus the TextEditor
                                }

                                // Bottom Save and Clear Buttons
                                VStack {
                                    Spacer() // Push buttons to the bottom
                                    HStack(spacing: 16) { // 20-point spacing between buttons
                                        Spacer()
                                        if !vm.chatText.isEmpty {
                                            Button(action: {
                                                vm.saveMessage(sender: "Me", messageText: vm.chatText, timestamp: Timestamp())
                                            }) {
                                                if #available(iOS 18.0, *) {
                                                    // iOS 18.0 or newer: Only show the first frame of the Lottie file
                                                    LottieAnimationViewContainer(filename: "Save Button", isInteractive: false)
                                                        .frame(width: 24, height: 24)
                                                } else {
                                                    // iOS versions below 18.0: Use full Lottie animation with interactivity
                                                    LottieAnimationViewContainer(filename: "Save Button", isInteractive: true)
                                                        .frame(width: 24, height: 24)
                                                }
                                            }
                                        }

                                        Button(action: {
                                                    vm.chatText = ""
                                                }) {
                                                    if #available(iOS 18.0, *) {
                                                        // iOS 18.0 or newer: Only show the first frame of the Lottie file
                                                        LottieAnimationViewContainer(filename: "Clear Button", isInteractive: false)
                                                            .frame(width: 24, height: 24)
                                                    } else {
                                                        // iOS versions below 18.0: Use full Lottie animation with interactivity
                                                        LottieAnimationViewContainer(filename: "Clear Button", isInteractive: true)
                                                            .frame(width: 24, height: 24)
                                                    }
                                                }
                                    }
                                    .padding(.trailing, 20) // Align to the right
                                    .padding(.bottom, 24)  // Spacing from bottom edge
                                }
                            }
                            //.background(Color.blue)
                            .frame(width: width, height: height)


                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    //.background(Color.blue)
                    .frame(height: geoheight)
                    
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            }
            /*HStack {
                // Back button to navigate to MainMessagesView
                Button(action: {
                    navigateToMainMessageView = true
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
                .padding()
                
                Spacer()
                
                // Button to open the saved messages window
                Button(action: {
                    vm.fetchSavedMessages()
                    vm.showSavedMessagesWindow.toggle()
                }) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .padding()
                }
            }
            
            VStack {
                messagesView
                Spacer()
                messageInputBar
            }
            .sheet(isPresented: $vm.showSavedMessagesWindow) {
                SavedMessagesView(vm: vm)
            }*/
        }
        .onAppear {
            vm.initializeMessages()
            vm.startAutoSend()
            vm.setActiveStatusToTrue()
            vm.markLatestMessageAsSeen()
        }
        .onDisappear {
            vm.stopAutoSend()
            vm.markMessageAsSeen(for: vm.chatUser?.uid ?? "")
            vm.setActiveStatusToFalse()
        }
        .navigationBarBackButtonHidden(true) // Hide the default back button
        .navigationDestination(isPresented: $navigateToMainMessageView) {
            MainMessagesView()
        }
    }
    
    private func getCurrentUser() -> ChatUser {
            guard let currentUser = FirebaseManager.shared.auth.currentUser else {
                return ChatUser(data: ["uid": "", "email": "", "profileImageUrl": ""])
            }
            return ChatUser(data: [
                "uid": currentUser.uid,
                "email": currentUser.email ?? "",
                "profileImageUrl": currentUser.photoURL?.absoluteString ?? ""
            ])
        }


    private var messagesView: some View {
        VStack {
            if let chatUser = vm.chatUser {
                NavigationLink(destination: ProfileView(
                    chatUser: chatUser,
                    currentUser: getCurrentUser(),
                    isCurrentUser: false,
                    chatLogViewModel: vm
                )) {
                    WebImage(url: URL(string: vm.chatUser?.profileImageUrl ?? ""))
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                }
            }

            if let recipientMessage = vm.latestRecipientMessage {
                HStack {
                    Text(recipientMessage.text)
                        .font(.title)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                        .multilineTextAlignment(.center)

                    // Save button for recipient's message
                    if  !recipientMessage.text.isEmpty {
                        Button(action: {
                                    vm.chatText = ""
                                }) {
                                    if #available(iOS 18.0, *) {
                                        // iOS 18.0 or newer: Only show the first frame of the Lottie file
                                        LottieAnimationViewContainer(filename: "Clear Button", isInteractive: false)
                                            .frame(width: 24, height: 24)
                                    } else {
                                        // iOS versions below 18.0: Use full Lottie animation with interactivity
                                        LottieAnimationViewContainer(filename: "Clear Button", isInteractive: true)
                                            .frame(width: 24, height: 24)
                                    }
                                }
                    }
                }
                .padding()
            }

            Spacer()

            if let senderMessage = vm.latestSenderMessage {
                VStack {
                    HStack {
                        Text(senderMessage.text)
                            .font(.title)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(radius: 5)
                            .multilineTextAlignment(.center)
                    }
                    .padding()

                    Text(senderMessage.seen ? "Seen" : "Unseen")
                        .font(.caption)
                        .foregroundColor(senderMessage.seen ? .green : .gray)
                        .padding(.bottom, 8)
                }
            }
        }
        .background(Color(.init(white: 0.95, alpha: 1)))
        .edgesIgnoringSafeArea(.bottom)
    }

    private var messageInputBar: some View {
        HStack(spacing: 16) {
            TextEditor(text: $vm.chatText)
                .frame(height: 40)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)

            if !vm.chatText.isEmpty {
                Button(action: {
                    vm.saveMessage(sender: "Me", messageText: vm.chatText, timestamp: Timestamp())
                }) {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(.blue)
                }
            }

            // Clear button for clearing the text field
            if !vm.chatText.isEmpty {
                Button(action: {
                    vm.chatText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

struct SavedMessagesView: View {
    @ObservedObject var vm: ChatLogViewModel

    var body: some View {
        ScrollView {
            VStack {
                ForEach(vm.savedMessages.sorted { $0.timeStamp.dateValue() < $1.timeStamp.dateValue() }) { message in
                    HStack {
                        if message.sender == "Me" {  // Ensure 'sender' is a String and correctly stored
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Me")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(message.text)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        } else if message.sender == "You" {  // Ensure 'sender' is a String and correctly stored
                            VStack(alignment: .leading) {
                                Text(vm.chatUser?.email ?? "You")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(message.text)
                                    .padding()
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                            Spacer()
                        }
                    }
                    .padding()
                }
            }
        }
        .padding()
    }
}

struct LottieAnimationViewContainer: UIViewRepresentable {
    var filename: String
    var isInteractive: Bool

    class Coordinator: NSObject {
        var animationView: LottieAnimationView?

        @objc func handleTap() {
            animationView?.play()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView(frame: .zero)
        let animationView = LottieAnimationView(name: filename)
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = .playOnce
        animationView.isUserInteractionEnabled = false // Disable direct interaction
        
        containerView.addSubview(animationView)
        animationView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            animationView.widthAnchor.constraint(equalTo: containerView.widthAnchor),
            animationView.heightAnchor.constraint(equalTo: containerView.heightAnchor)
        ])

        context.coordinator.animationView = animationView

        if isInteractive {
            // Add tap gesture recognizer to the containerView
            let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
            containerView.addGestureRecognizer(tapGesture)
        }

        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let animationView = context.coordinator.animationView {
            if !isInteractive {
                animationView.currentFrame = 0
            }
        }
    }
}
