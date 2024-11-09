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
    
    init() {
        /*if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            print("AppDelegate accessed successfully.")
            appDelegate.fetchAndStoreFCMToken()
        } else {
            print("Failed to access AppDelegate.")
        }

        print("been here")*/
        DispatchQueue.main.async{
            self.isUserCurrentlyLoggedOut =
            FirebaseManager.shared.auth.currentUser?.uid == nil
        }
        fetchCurrentUser()
        fetchAllFriends()
    }
    
    @Published var recentMessages = [RecentMessage]()
    
    private func fetchAllFriends() {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {
            self.errorMessage = "Could not find firebase uid"
            return
        }
        FirebaseManager.shared.firestore.collection("friends").document(uid).collection("friend_list")
            .getDocuments { documentsSnapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to fetch users: \(error)"
                    print("Failed to fetch users: \(error)")
                    return
                }
                
                documentsSnapshot?.documents.forEach({ snapshot in
                    let data = snapshot.data()
                    let user = ChatUser(data: data)
                    if user.uid != FirebaseManager.shared.auth.currentUser?.uid {
                        self.users.append(.init(data: data))
                    }
                })
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
            
            
            self.chatUser = ChatUser(data: data)
            
//            self.errorMessage = chatUser.profileImageUrl
            
        }
    }
    
    
    
    func handleSignOut(){
        isUserCurrentlyLoggedOut.toggle()
        try? FirebaseManager.shared.auth.signOut()
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
                        if let chatUser = vm.chatUser{
                            self.selectedUser = chatUser
                            self.chatUser = user
                            self.shouldNavigateToChatLogView.toggle()
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
                            VStack(alignment: .leading, spacing: 8) {
                                Text(user.email)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color(.label))
                            }
                            Spacer()
                        }
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
}

#Preview{
    LoginView()
}
