import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

struct FirebaseConstants {
    static let fromId = "fromId"
    static let toId = "toId"
    static let text = "text"
    static let seen = "seen"
    static let sender = "sender"
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
        startAutoSend()
        startSeenCheckTimer()
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
            self.handleSend()
        }
    }

    func stopAutoSend() {
        timer?.invalidate()
        timer = nil
    }

    func startSeenCheckTimer() {
        markMessagesAsSeen()  // Mark as seen when the timer starts
        seenCheckTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            self.markMessagesAsSeen()
        }
    }

    func stopSeenCheckTimer() {
        seenCheckTimer?.invalidate()
        seenCheckTimer = nil
    }

    func markMessagesAsSeen() {
        guard let fromId = chatUser?.uid else { return }
        guard let toId = FirebaseManager.shared.auth.currentUser?.uid else { return }

        FirebaseManager.shared.firestore
            .collection("messages")
            .document(fromId)
            .collection(toId)
            .whereField(FirebaseConstants.seen, isEqualTo: false)
            .getDocuments { snapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to mark messages as seen: \(error)"
                    return
                }

                snapshot?.documents.forEach { document in
                    document.reference.updateData([FirebaseConstants.seen: true])
                }
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

    // Handle sending a message
    func handleSend() {
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = chatUser?.uid else { return }

        let messageData = ["fromId": fromId, "toId": toId, "text": chatText, "timeStamp": Timestamp(), "seen": false] as [String: Any]
        if chatText == latestSenderMessage?.text {
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
                self.fetchLatestMessages()
            }
    }

    // Save the message to Firebase
    func saveMessage(sender: String, messageText: String, timestamp: Timestamp) {
        guard let fromId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        guard let toId = chatUser?.uid else { return }

        let saveData: [String: Any] = [
            FirebaseConstants.sender: sender,
            FirebaseConstants.text: messageText,
            "timestamp": timestamp
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

/*struct ChatLogView: View {
    @ObservedObject var vm: ChatLogViewModel
    @State private var navigateToMainMessageView = false
    @State private var backgroundOffset: CGFloat = -UIScreen.main.bounds.width / 2

    var body: some View {
        ZStack {
            Color.black
                .edgesIgnoringSafeArea(.all)
            BackdropImageView(offset: $backgroundOffset, imageName: "backgrounddrop")
                .opacity(0.4)
            NavigationStack {
                HStack {
                    // Back button to navigate to MainMessagesView
                    Button(action: {
                        navigateToMainMessageView = true
                        backgroundOffset = 0
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
                }
            }
            .navigationTitle(vm.chatUser?.email ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                vm.initializeMessages()
            }
            .onDisappear {
                vm.stopAutoSend()
                vm.stopSeenCheckTimer()
            }
            .navigationBarBackButtonHidden(true) // Hide the default back button
            .navigationDestination(isPresented: $navigateToMainMessageView) {
                MainMessagesView()
            }
        }
    }
    
    private var messagesView: some View {
        VStack(spacing: 16) {
            if let recipientMessage = vm.latestRecipientMessage {
                // Recipient's message on top of the recipientGlass image
                ZStack {
                    Image("recipientglass")
                        .resizable()
                        .frame(height: 192)
                    Text(recipientMessage.text)
                        .font(.custom("SF Pro", size: 18))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    // Save button for recipient's message
                    if !recipientMessage.text.isEmpty {
                        Button(action: {
                            vm.saveMessage(sender: "You", messageText: recipientMessage.text, timestamp: recipientMessage.timeStamp)
                        }) {
                            Image(systemName: "square.and.arrow.down")
                                .padding()
                        }
                        .position(x: UIScreen.main.bounds.width - 50, y: 20)
                    }
                }
                .padding(.horizontal)
            }

            if let senderMessage = vm.latestSenderMessage {
                // Sender's message on top of the senderGlass image
                ZStack {
                    Image("senderglass")
                        .resizable()
                        .frame(height: 192)
                    Text(senderMessage.text)
                        .font(.custom("SF Pro", size: 18))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    // Save button for sender's message
                    if !senderMessage.text.isEmpty {
                        Button(action: {
                            vm.saveMessage(sender: "Me", messageText: senderMessage.text, timestamp: senderMessage.timeStamp)
                        }) {
                            Image(systemName: "square.and.arrow.down")
                                .padding()
                        }
                        .position(x: UIScreen.main.bounds.width - 50, y: 20)
                    }
                }
                .padding(.horizontal)
                
                // Seen/unseen indicator
                Text(senderMessage.seen ? "Seen" : "Unseen")
                    .font(.caption)
                    .foregroundColor(senderMessage.seen ? .green : .gray)
                    .padding(.top, 4)
            }
        }
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
}*/

/*struct ChatLogView: View {
    @ObservedObject var vm: ChatLogViewModel
    @State private var navigateToMainMessageView = false
    @State private var backgroundOffset: CGFloat = -UIScreen.main.bounds.width / 2
    @FocusState private var isInputFocused: Bool // Focus state for input field

    var body: some View {
        ZStack {
            Color.black
                .edgesIgnoringSafeArea(.all)
            BackdropImageView(offset: $backgroundOffset, imageName: "backgrounddrop")
                .opacity(0.4)
            
            NavigationStack {
                HStack {
                    Button(action: {
                        navigateToMainMessageView = true
                        backgroundOffset = 0
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
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
                }
                .sheet(isPresented: $vm.showSavedMessagesWindow) {
                    SavedMessagesView(vm: vm)
                }
            }
            .navigationTitle(vm.chatUser?.email ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                vm.initializeMessages()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isInputFocused = true // Automatically focus input
                }
            }
            .onDisappear {
                vm.stopAutoSend()
                vm.stopSeenCheckTimer()
            }
            .navigationBarBackButtonHidden(true)
            .navigationDestination(isPresented: $navigateToMainMessageView) {
                MainMessagesView()
            }
        }
    }
    
    private var messagesView: some View {
        VStack(spacing: 16) {
            if let recipientMessage = vm.latestRecipientMessage {
                ZStack(alignment: .bottomTrailing) {
                    Image("recipientglass")
                        .resizable()
                        .frame(height: 192)
                    
                    Text(recipientMessage.text)
                        .font(.custom("SF Pro", size: 18))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    if !recipientMessage.text.isEmpty {
                        Button(action: {
                            vm.saveMessage(sender: "You", messageText: recipientMessage.text, timestamp: recipientMessage.timeStamp)
                        }) {
                            Image(systemName: "square.and.arrow.down")
                                .padding()
                                .foregroundColor(.blue)
                        }
                        .offset(x: -20, y: -20)
                    }
                }
                .padding(.horizontal)
            }

            ZStack(alignment: .bottomTrailing) {
                Image("senderglass")
                    .resizable()
                    .frame(height: 192)
                
                ScrollView { // Scroll view wraps the TextEditor for scrolling when text exceeds bounds
                    TextEditor(text: $vm.chatText)
                        .font(.custom("SF Pro", size: 18))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .focused($isInputFocused)
                        .padding(.horizontal, 16)
                        .frame(height: 160, alignment: .center) // Ensures TextEditor stays within image
                        .onChange(of: vm.chatText) { _ in
                            if vm.chatText.count > 300 {
                                vm.chatText.removeLast() // Limit character count if needed
                            }
                        }
                        .onSubmit {
                            vm.handleSend()
                            vm.chatText = "" // Clear input after sending
                        }
                }
                .frame(height: 160) // Keep the scroll view within senderGlass boundaries
                
                if !vm.chatText.isEmpty {
                    Button(action: {
                        vm.saveMessage(sender: "Me", messageText: vm.chatText, timestamp: Timestamp())
                    }) {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundColor(.blue)
                            .padding()
                    }
                    .offset(x: -20, y: -20)
                }
            }
            .padding(.horizontal)
            
            if let senderMessage = vm.latestSenderMessage {
                Text(senderMessage.seen ? "Seen" : "Unseen")
                    .font(.caption)
                    .foregroundColor(senderMessage.seen ? .green : .gray)
                    .padding(.top, 4)
            }
        }
    }*/

struct ChatLogView: View {
    @ObservedObject var vm: ChatLogViewModel
    @State private var navigateToMainMessageView = false
    @State private var backgroundOffset: CGFloat = -UIScreen.main.bounds.width / 2
    @FocusState private var isInputFocused: Bool

    var body: some View {
        ZStack {
            Color.black
                .edgesIgnoringSafeArea(.all)
            BackdropImageView(offset: $backgroundOffset, imageName: "chatlogviewbackground")
                .opacity(0.4)
            
            NavigationStack {
                HStack {
                    Button(action: {
                        navigateToMainMessageView = true
                        backgroundOffset = 0
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                    .padding()
                    
                    Spacer()
                    
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
                }
                .sheet(isPresented: $vm.showSavedMessagesWindow) {
                    SavedMessagesView(vm: vm)
                }
            }
            .navigationTitle(vm.chatUser?.email ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                vm.initializeMessages()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isInputFocused = true
                }
            }
            .onDisappear {
                vm.stopAutoSend()
                vm.stopSeenCheckTimer()
            }
            .navigationBarBackButtonHidden(true)
            .navigationDestination(isPresented: $navigateToMainMessageView) {
                MainMessagesView()
            }
        }
    }
    
    private var messagesView: some View {
        VStack(spacing: 16) {
            if let recipientMessage = vm.latestRecipientMessage {
                ZStack(alignment: .bottomTrailing) {
                    Image("recipientglass")
                        .resizable()
                        .frame(height: 192)
                    Text(recipientMessage.text)
                        .font(.custom("SF Pro", size: 18))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    // Save button for recipient's message
                    if !recipientMessage.text.isEmpty {
                        Button(action: {
                            vm.saveMessage(sender: "You", messageText: recipientMessage.text, timestamp: recipientMessage.timeStamp)
                        }) {
                            Image(systemName: "square.and.arrow.down")
                                .foregroundColor(.blue)
                                .padding(10)
                        }
                    }
                }
                .padding(.horizontal)
            }

            ZStack(alignment: .bottomTrailing) {
                Image("senderglass")
                    .resizable()
                    .frame(height: 192)
                
                ScrollView {
                    TextField("Type your message...", text: $vm.chatText)
                        .font(.custom("SF Pro", size: 18))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .focused($isInputFocused)
                        .padding(.horizontal)
                        .background(Color.clear)
                        .frame(maxHeight: 160, alignment: .center)
                        .onChange(of: vm.chatText) { _ in
                            if vm.chatText.count > 300 {
                                vm.chatText.removeLast()
                            }
                        }
                }
                .padding(.horizontal)

                // Save button for input message
                if !vm.chatText.isEmpty {
                    Button(action: {
                        vm.saveMessage(sender: "Me", messageText: vm.chatText, timestamp: Timestamp())
                    }) {
                        Image(systemName: "square.and.arrow.down")
                            .foregroundColor(.blue)
                            .padding(10)
                    }
                }
            }
            .padding(.horizontal)

            if let senderMessage = vm.latestSenderMessage {
                Text(senderMessage.seen ? "Seen" : "Unseen")
                    .font(.caption)
                    .foregroundColor(senderMessage.seen ? .green : .gray)
                    .padding(.top, 4)
            }
        }
    }


    private var messageInputBar: some View {
        HStack(spacing: 16) {
            TextEditor(text: $vm.chatText)
                .frame(height: 40)
                .padding(8)
                .background(Color.clear)
                .cornerRadius(8)
                .focused($isInputFocused)

            if !vm.chatText.isEmpty {
                Button(action: {
                    vm.saveMessage(sender: "Me", messageText: vm.chatText, timestamp: Timestamp())
                }) {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(.blue)
                }
            }

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

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
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
