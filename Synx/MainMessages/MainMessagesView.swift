import SwiftUI
import SDWebImageSwiftUI
import Firebase

struct RecentMessage: Identifiable{
    var id: String{documentId}
    let text, fromId, toId: String
    let timestamp: Timestamp
    let documentId: String
    let email, profileImageUrl: String
    
    init(documentId: String, data:[String: Any]){
        
        self.documentId = documentId
        self.text = data["text"] as? String ?? ""
        self.timestamp = data["timestamp"] as? Timestamp ?? Timestamp(date: Date())
        self.fromId = data["fromId"] as? String ?? ""
        self.toId = data["toId"] as? String ?? ""
        self.profileImageUrl = data["profileImageUrl"] as? String ?? ""
        self.email = data["email"] as? String ?? ""
    }
    
}

class MainMessagesViewModel: ObservableObject {
    
    @Published var errorMessage = ""
    @Published var chatUser: ChatUser?
    @Published var isUserCurrentlyLoggedOut = false
    @Published var users = [ChatUser]()
    
    var listener: ListenerRegistration?
    
    init() {
        DispatchQueue.main.async{
            self.isUserCurrentlyLoggedOut =
            FirebaseManager.shared.auth.currentUser?.uid == nil
        }
        fetchCurrentUser()
        setupFriendListListener()
    }
    
    @Published var recentMessages = [RecentMessage]()
        
    func setupFriendListListener() {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {
            self.errorMessage = "Could not find firebase uid"
            return
        }

        listener = FirebaseManager.shared.firestore
            .collection("friends")
            .document(uid)
            .collection("friend_list")
            .addSnapshotListener { querySnapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to listen for friend list changes: \(error)"
                    print("Failed to listen for friend list changes: \(error)")
                    return
                }

                guard let documents = querySnapshot?.documents else {
                    self.errorMessage = "No friend list documents found"
                    return
                }

                var users: [ChatUser] = []

                for document in documents {
                    let data = document.data()
                    let user = ChatUser(data: data)
                    if user.uid != uid {
                        users.append(user)
                    }
                }

                // 分组并排序
                let pinnedUsers = users.filter { $0.isPinned }.sorted {
                    ($0.latestMessageTimestamp?.dateValue() ?? Date.distantPast) > ($1.latestMessageTimestamp?.dateValue() ?? Date.distantPast)
                }

                let unpinnedUsers = users.filter { !$0.isPinned }.sorted {
                    ($0.latestMessageTimestamp?.dateValue() ?? Date.distantPast) > ($1.latestMessageTimestamp?.dateValue() ?? Date.distantPast)
                }

                DispatchQueue.main.async {
                    self.users = pinnedUsers + unpinnedUsers
                }
            }
    }
    func stopListening() {
        listener?.remove()
        listener = nil
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
            
            self.chatUser = ChatUser(data: data)
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
    
    func handleSignOut() {
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
}

struct MainMessagesView: View {
    @State private var shouldShowLogOutOptions = false
    @State private var shouldNavigateToChatLogView = false
    @State private var shouldNavigateToAddFriendView = false
    @State private var shouldShowFriendRequests = false
    @State private var shouldShowProfileView = false
    @State private var selectedUser: ChatUser? = nil
    @State private var chatUser: ChatUser? = nil
    @State private var isCurrentUser = false
    @State var errorMessage = ""
    @State var latestSenderMessage: ChatMessage?
    @State private var shouldShowFriendGroupView = false
    
    @ObservedObject private var vm = MainMessagesViewModel()
    @StateObject private var chatLogViewModel = ChatLogViewModel(chatUser: nil)
    
    var body: some View {
        NavigationStack {
                    VStack {
                        customNavBar
                        usersListView
                    }
                    
                    .overlay(newMessageButton, alignment: .bottom)
                    .navigationBarHidden(true)
                    .navigationDestination(isPresented: $shouldShowProfileView) {
                        if let chatUser = self.chatUser, let selectedUser = self.selectedUser {
                            ProfileView(
                                chatUser: chatUser,
                                currentUser: selectedUser,
                                isCurrentUser: self.isCurrentUser,
                                chatLogViewModel: chatLogViewModel
                            )
                        }
                    }
                    .navigationDestination(isPresented: $shouldShowFriendRequests) {
                        if let user = self.selectedUser {
                            FriendRequestsView(currentUser: user)
                        }
                    }
                    .navigationDestination(isPresented: $shouldNavigateToChatLogView) {
                        ChatLogView(vm: chatLogViewModel)
                            .onAppear {
                                chatLogViewModel.chatUser = self.chatUser
                                chatLogViewModel.initializeMessages()
                            }
                    }
                    .navigationDestination(isPresented: $shouldShowFriendGroupView) {
                        if let user = self.selectedUser {
                            FriendGroupView(selectedUser: user)
                        }
                    }
                }
        .onAppear{
            vm.setupFriendListListener()
        }
        .onDisappear{
            vm.stopListening()
        }
    }
    
    private var customNavBar: some View {
        HStack(spacing: 16) {
            // Profile Image Button - Navigates to ProfileView with chatUser and selectedUser
            Button(action: {
                if let chatUser = vm.chatUser {
                    self.selectedUser = chatUser
                    self.chatUser = chatUser
                    self.isCurrentUser = true
                    shouldShowProfileView.toggle()
                }
            }) {
                WebImage(url: URL(string: vm.chatUser?.profileImageUrl ?? ""))
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .cornerRadius(50)
                    .overlay(RoundedRectangle(cornerRadius: 44).stroke(Color(.label), lineWidth: 1))
                    .shadow(radius: 5)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(vm.chatUser?.email.replacingOccurrences(of: "@gmail.com", with: "") ?? "")
                    .font(.system(size: 24, weight: .bold))
                HStack {
                    Circle()
                        .foregroundColor(.green)
                        .frame(width: 14, height: 14)
                    Text("online")
                        .font(.system(size: 12))
                        .foregroundColor(Color(.lightGray))
                }
            }
            Spacer()
            
            Button(action: {
                if let chatUser = vm.chatUser {
                    self.selectedUser = chatUser
                    shouldShowFriendGroupView.toggle()
                }
            }) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(.label))
            }

            // Mail Button - Navigates to FriendRequestsView
            Button(action: {
                if let chatUser = vm.chatUser{
                    self.selectedUser = chatUser
                    shouldShowFriendRequests.toggle()
                }
            }) {
                Image(systemName: "envelope")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(.label))
            }
            
            // Gear Button - Shows Sign-Out Options
            Button(action: {
                shouldShowLogOutOptions.toggle()
            }) {
                Image(systemName: "gear")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(.label))
            }
            .actionSheet(isPresented: $shouldShowLogOutOptions) {
                ActionSheet(
                    title: Text("Settings"),
                    message: Text("What do you want to do?"),
                    buttons: [
                        .destructive(Text("Sign Out"), action: {
                            vm.handleSignOut()
                        }),
                        .cancel()
                    ]
                )
            }
            .fullScreenCover(isPresented: $vm.isUserCurrentlyLoggedOut) {
                LoginView()
            }
        }
        .padding()
    }
    
    private var usersListView: some View {
        ScrollView {
            ForEach(vm.users) { user in
                VStack {
                    Button {
                        if let chatUser = vm.chatUser {
                            self.selectedUser = chatUser
                            self.chatUser = user
                            self.shouldNavigateToChatLogView.toggle()
                            vm.markMessageAsSeen(for: user.uid)
                        }
                    } label: {
                        HStack(spacing: 16) {
                            WebImage(url: URL(string: user.profileImageUrl))
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .cornerRadius(64)
                                .overlay(RoundedRectangle(cornerRadius: 64).stroke(Color.black, lineWidth: 1))
                                .shadow(radius: 5)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.email)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color(.label))
                                
                                // 显示最新聊天时间
                                if let timestamp = user.latestMessageTimestamp {
                                    Text(formatTimestamp(timestamp))
                                        .font(.system(size: 14))
                                        .foregroundColor(Color.gray)
                                } else {
                                    Text("暂无消息")
                                        .font(.system(size: 14))
                                        .foregroundColor(Color.gray)
                                }
                            }
                            Spacer()
                            if user.hasUnseenLatestMessage {
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 12, height: 12)
                            }
                        }
                        .padding()
                        .background(user.isPinned ? Color.gray.opacity(0.2) : Color.clear)
                        .cornerRadius(8)
                    }
                    Divider().padding(.vertical, 8)
                }
                .padding(.horizontal)
            }
        }
    }
    private var newMessageButton: some View {
        Button {
            shouldNavigateToAddFriendView.toggle()
        } label: {
            HStack {
                Spacer()
                Text("Contacts")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
            }
            .foregroundColor(.white)
            .padding(.vertical)
            .background(Color.blue)
            .cornerRadius(32)
            .padding(.horizontal)
            .shadow(radius: 15)
        }
        .fullScreenCover(isPresented: $shouldNavigateToAddFriendView) {
            CreateNewMessageView { user in
                self.chatUser = user
                self.isCurrentUser = false
                self.selectedUser = vm.chatUser
                shouldShowProfileView.toggle()
            }
        }
    }

    func formatTimestamp(_ timestamp: Timestamp) -> String {
        let date = timestamp.dateValue()
        let formatter = DateFormatter()
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            // 如果是今天，显示时间，例如 "14:23"
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            // 如果是昨天，显示 "昨天"
            return "昨天"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            // 如果在本周内，显示星期几
            let weekdaySymbols = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
            let weekday = calendar.component(.weekday, from: date)
            print(weekday)
            if weekday == 1 {
                formatter.dateFormat = "yyyy/MM/dd"
                return formatter.string(from: date)
            } else {
                return weekdaySymbols[(weekday + 5) % 7]
            }// 注意：周日对应索引 0
        } else {
            // 否则，显示日期，例如 "2023/10/07"
            formatter.dateFormat = "yyyy/MM/dd"
            return formatter.string(from: date)
        }
    }
}

#Preview{
    LoginView()
}
