import SwiftUI
import Firebase

class CustomTabNavigationViewModel: ObservableObject{
    @Published var errorMessage = ""
    @Published var currentUser: ChatUser?
    var friendGroupListener: ListenerRegistration?
    @AppStorage("lastCheckedTimestamp") var lastCheckedTimestamp: Double = 0
    @AppStorage("lastLikesCount") var lastLikesCount: Int = 0
    @Published var hasNewFriendGroup = false // 用于跟踪是否有新的朋友圈消息
    
    init(){
        fetchCurrentUser()
        setupFriendGroupListener() // 合并朋友圈和点赞监听器
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
            
            DispatchQueue.main.async {
                self.currentUser = ChatUser(data: data)
            }
        }
    }
    
    func setupFriendGroupListener() {
        guard let currentUserUid = FirebaseManager.shared.auth.currentUser?.uid else {
            self.errorMessage = "Could not find firebase uid"
            return
        }

        // 如果已有监听器，先移除
        friendGroupListener?.remove()
        friendGroupListener = nil

        // double to int64
        let lastCheckedTimestampInt64 = Int64(lastCheckedTimestamp)

        friendGroupListener = FirebaseManager.shared.firestore
            .collection("response_to_prompt")
            .whereField("timestamp", isGreaterThan: Timestamp(seconds: lastCheckedTimestampInt64, nanoseconds: 0))
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("Failed to listen for friend group messages and likes: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                var hasNewLikes = false
                var hasNewFriendGroupUpdates = false

                // Fetch friend list
                self?.fetchFriendList { friendUIDs in
                    for document in documents {
                        let data = document.data()
                        let authorUid = data["uid"] as? String ?? ""
                        let documentId = document.documentID
                        let likes = data["likes"] as? Int ?? 0

                        // 检查朋友圈更新
                        if friendUIDs.contains(authorUid) && authorUid != currentUserUid {
                            hasNewFriendGroupUpdates = true
                        }

                        // 检查点赞更新
                        if authorUid == currentUserUid {
                            if likes > self?.lastLikesCount ?? 0 {
                                hasNewLikes = true
                                self?.lastLikesCount = likes
                            }
                            self?.lastLikesCount = likes
                        }
                    }

                    DispatchQueue.main.async {
                        self?.hasNewFriendGroup = (hasNewFriendGroupUpdates || hasNewLikes)
                    }
                }
            }
    }
    func fetchFriendList(completion: @escaping ([String]) -> Void) {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {
            self.errorMessage = "Could not find firebase uid"
            return
        }

        FirebaseManager.shared.firestore
            .collection("friends")
            .document(uid)
            .collection("friend_list")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Failed to fetch friend list: \(error)")
                    return
                }

                guard let documents = snapshot?.documents else {
                    print("No friend list documents found")
                    return
                }

                let friendUIDs = documents.map { $0.documentID }
                completion(friendUIDs)
            }
    }
}


struct CustomTabNavigationView: View {
    @State private var currentView: String = "Home" 
    
    @ObservedObject private var vm = CustomTabNavigationViewModel()
    @StateObject private var chatLogViewModel = ChatLogViewModel(chatUser: nil)
    @State private var currentUser: ChatUser? = nil

    var body: some View {
        ZStack{
            VStack {
                switch currentView {
                case "MainMessages":
                    MainMessagesView()
                case "Profile":
                    if let user = vm.currentUser{
                        SelfProfileView(
                            chatUser: user,
                            currentUser: user,
                            isCurrentUser: true,
                            chatLogViewModel: chatLogViewModel
                        )
                    }
                case "Contacts":
                    CreateNewMessageView()
                case "DailyAurora":
                    if let user = vm.currentUser{
                        FriendGroupView(selectedUser: user)
                    }
                default:
                    MainMessagesView()
                }
            }
            VStack{
                Spacer()
                CustomNavBar(currentView: $currentView)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
    
    
}

struct CustomNavBar: View {
    @Binding var currentView: String
    @ObservedObject private var vm = CustomTabNavigationViewModel()
    

    var body: some View {
        ZStack{
            Image("navigationbar")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .ignoresSafeArea(edges: .bottom)
            
            HStack(spacing: 60){
                Button(action: {
                    currentView = "DailyAurora"
                    vm.hasNewFriendGroup = false
                    let currentDate = Date()
                    vm.lastCheckedTimestamp = currentDate.timeIntervalSince1970
                }) {
                    VStack {
                        Image("dailyaurorabutton")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                        if vm.hasNewFriendGroup {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 12, height: 12)
                                .offset(x: 30, y: -10)
                        }
                    }
                }
                
                Button(action: {
                    currentView = "MainMessages"
                }) {
                    VStack {
                        Image("messagesbutton")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                    }
                }
                
                Button(action: {
                    currentView = "Contacts"
                }) {
                    VStack {
                        Image("contactsbutton")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                    }
                }
                
                Button(action: {
                    currentView = "Profile"
                }) {
                    VStack {
                        Image("profilebutton")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                    }
                }
                .foregroundColor(currentView == "Settings" ? .blue : .gray)
            }
            .padding(.bottom, 20)
        }
    }
}

// 示例视图
struct ViewOne: View {
    var body: some View {
        VStack {
            Text("Home View")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.green.opacity(0.2))
        }
    }
}

struct ViewTwo: View {
    var body: some View {
        VStack {
            Text("Profile View")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.blue.opacity(0.2))
        }
    }
}

struct ViewThree: View {
    var body: some View {
        VStack {
            Text("Messages View")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.yellow.opacity(0.2))
        }
    }
}

struct ViewFour: View {
    var body: some View {
        VStack {
            Text("Settings View")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.2))
        }
    }
}

#Preview{
    CustomTabNavigationView()
}
