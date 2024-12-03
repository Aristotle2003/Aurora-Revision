import SwiftUI
import Firebase
import SDWebImageSwiftUI
import FirebaseAuth

class FriendGroupViewModel: ObservableObject {
    @Published var promptText = ""
    @Published var responseText = ""
    @Published var responses = [FriendResponse]()
    @Published var showResponseInput = false
    @Published var currentUserHasPosted = true
    
    private var selectedUser: ChatUser
    private var listener: ListenerRegistration?
    
    init(selectedUser: ChatUser) {
        self.selectedUser = selectedUser
        fetchPrompt()
        fetchLatestResponses(for: selectedUser.uid)
        setupCurrentUserHasPostedListener()
    }
    
    deinit {
        // 移除监听器以防止内存泄漏
        listener?.remove()
    }
    
    func fetchPrompt() {
        FirebaseManager.shared.firestore.collection("prompts").document("currentPrompt")
            .getDocument { snapshot, error in
                if let data = snapshot?.data(), let prompt = data["text"] as? String {
                    DispatchQueue.main.async {
                        self.promptText = prompt
                    }
                    print("Fetched prompt: \(prompt)")
                } else {
                    print("Failed to fetch prompt: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
    }
    
    func submitResponse(for userId: String) {
        let responseRef = FirebaseManager.shared.firestore.collection("response_to_prompt").document()
        let data: [String: Any] = [
            "uid": userId,
            "text": responseText,
            "timestamp": Timestamp(),
            "likes": 0,
            "likedBy": []
        ]
        
        responseRef.setData(data) { error in
            if error == nil {
                DispatchQueue.main.async {
                    self.responseText = ""
                    self.showResponseInput = false
                }
                print("Response submitted successfully")
                // 更新 hasPosted 状态
                self.updateHasPostedStatus(for: userId)
            } else {
                print("Failed to submit response: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    func fetchLatestResponses(for userId: String) {
        var allResponses: [FriendResponse] = []
        let group = DispatchGroup()
        
        group.enter()
        fetchLatestResponse(for: userId, email: self.selectedUser.email, profileImageUrl: self.selectedUser.profileImageUrl) { response in
            if let response = response {
                allResponses.append(response)
            }
            group.leave()
        }
        
        FirebaseManager.shared.firestore.collection("friends")
            .document(userId)
            .collection("friend_list")
            .getDocuments { friendSnapshot, error in
                if let error = error {
                    print("获取好友列表失败：\(error.localizedDescription)")
                    return
                }
                
                guard let friendDocs = friendSnapshot?.documents else {
                    print("没有找到好友。")
                    return
                }
                
                for friendDoc in friendDocs {
                    let friendData = friendDoc.data()
                    guard let friendId = friendData["uid"] as? String,
                          let email = friendData["email"] as? String,
                          let profileImageUrl = friendData["profileImageUrl"] as? String else {
                        continue
                    }
                    
                    group.enter()
                    self.fetchLatestResponse(for: friendId, email: email, profileImageUrl: profileImageUrl) { response in
                        if let response = response {
                            allResponses.append(response)
                        }
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    self.responses = allResponses.sorted { $0.timestamp > $1.timestamp }
                }
            }
    }
    
    private func fetchLatestResponse(for uid: String, email: String, profileImageUrl: String, completion: @escaping (FriendResponse?) -> Void) {
        FirebaseManager.shared.firestore.collection("response_to_prompt")
            .whereField("uid", isEqualTo: uid)
            .order(by: "timestamp", descending: true)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let doc = snapshot?.documents.first {
                    let data = doc.data()
                    let latestMessage = data["text"] as? String ?? ""
                    let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
                    let likes = data["likes"] as? Int ?? 0
                    let likedBy = data["likedBy"] as? [String] ?? []
                    let currentUserId = FirebaseManager.shared.auth.currentUser?.uid ?? ""
                    let likedByCurrentUser = likedBy.contains(currentUserId)
                    let response = FriendResponse(
                        uid: uid,
                        email: email,
                        profileImageUrl: profileImageUrl,
                        latestMessage: latestMessage,
                        timestamp: timestamp,
                        likes: likes,
                        likedByCurrentUser: likedByCurrentUser,
                        documentId: doc.documentID
                    )
                    DispatchQueue.main.async {
                        completion(response)
                    }
                } else {
                    print("未找到 UID \(uid) 的响应")
                    DispatchQueue.main.async {
                        completion(nil)
                    }
                }
            }
    }
    
    func setupCurrentUserHasPostedListener() {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        
        listener = FirebaseManager.shared.firestore.collection("users").document(uid)
            .addSnapshotListener { snapshot, error in
                if let error = error {
                    print("Failed to listen to current user's post status: \(error.localizedDescription)")
                    return
                }
                
                DispatchQueue.main.async {
                    if let data = snapshot?.data() {
                        self.currentUserHasPosted = data["hasPosted"] as? Bool ?? false
                    } else {
                        self.currentUserHasPosted = false
                    }
                }
            }
    }

    func updateHasPostedStatus(for userId: String) {
        FirebaseManager.shared.firestore.collection("users").document(userId).updateData([
            "hasPosted": true
        ]) { error in
            if let error = error {
                print("Failed to update hasPosted status: \(error.localizedDescription)")
                return
            }
            print("User's hasPosted status updated successfully.")
        }
    }
    
    func toggleLike(for response: FriendResponse) {
        guard let currentUserId = FirebaseManager.shared.auth.currentUser?.uid else { return }
        
        let responseRef = FirebaseManager.shared.firestore
            .collection("response_to_prompt")
            .document(response.documentId)
        
        let hasLiked = response.likedByCurrentUser
        
        responseRef.updateData([
            "likes": hasLiked ? FieldValue.increment(Int64(-1)) : FieldValue.increment(Int64(1)),
            "likedBy": hasLiked ? FieldValue.arrayRemove([currentUserId]) : FieldValue.arrayUnion([currentUserId])
        ]) { error in
            if let error = error {
                print("更新点赞状态失败：\(error.localizedDescription)")
                return
            }
            DispatchQueue.main.async {
                if let index = self.responses.firstIndex(where: { $0.id == response.id }) {
                    self.responses[index].likedByCurrentUser.toggle()
                    self.responses[index].likes += hasLiked ? -1 : 1
                }
            }
        }
    }
}

struct FriendResponse: Identifiable {
    let id = UUID()
    let uid: String
    let email: String
    let profileImageUrl: String
    let latestMessage: String
    let timestamp: Date
    var likes: Int
    var likedByCurrentUser: Bool
    let documentId: String
}

struct FriendGroupView: View {
    @ObservedObject var vm: FriendGroupViewModel
    @State private var topCardIndex = 0
    @State private var offset = CGSize.zero
    @State private var rotationDegrees = [Double]()
    let selectedUser: ChatUser

    init(selectedUser: ChatUser) {
        self.selectedUser = selectedUser
        _vm = ObservedObject(wrappedValue: FriendGroupViewModel(selectedUser: selectedUser))
        _rotationDegrees = State(initialValue: (0..<20).map { _ in Double.random(in: -15...15) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(vm.promptText)
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
                .padding(.bottom, 8)
            
            Button("Reply") {
                vm.showResponseInput = true
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                ForEach(vm.responses.indices, id: \.self) { index in
                    if index >= topCardIndex {
                        ResponseCard(response: vm.responses[index], cardColor: getCardColor(index: index), likeAction: {
                            vm.toggleLike(for: vm.responses[index])
                        })
                        .offset(x: index == topCardIndex ? offset.width : 0, y: CGFloat(index - topCardIndex) * 10)
                        .rotationEffect(.degrees(index == topCardIndex ? Double(offset.width / 20) : rotationDegrees[index]), anchor: .center)
                        .scaleEffect(index == topCardIndex ? 1.0 : 0.95)
                        .animation(.spring(), value: offset)
                        .zIndex(Double(vm.responses.count - index))
                        .gesture(
                            DragGesture()
                                .onChanged { gesture in
                                    if index == topCardIndex {
                                        offset = gesture.translation
                                    }
                                }
                                .onEnded { _ in
                                    if abs(offset.width) > 150 {
                                        withAnimation {
                                            offset = CGSize(width: offset.width > 0 ? 500 : -500, height: 0)
                                            topCardIndex += 1
                                            if topCardIndex >= vm.responses.count {
                                                topCardIndex = 0
                                            }
                                            offset = .zero
                                        }
                                    } else {
                                        withAnimation {
                                            offset = .zero
                                        }
                                    }
                                }
                        )
                        .padding(8)
                    }
                }

                if !vm.currentUserHasPosted {
                    Color.white.opacity(0.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(false)
                    
                    VStack {
                        Spacer()
                        Image(systemName: "lock.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.gray)
                        
                        Text("发布一条动态以解锁好友圈")
                            .font(.headline)
                            .padding()
                        
                        Button(action: {
                            vm.showResponseInput = true
                        }) {
                            Text("立即发布")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(0.8)
                    .zIndex(100)
                    .background(Color.white.opacity(0.8))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 450)
        }
        .padding(.horizontal)
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $vm.showResponseInput) {
            FullScreenResponseInputView(vm: vm, selectedUser: selectedUser)
        }
    }
    
    func getCardColor(index: Int) -> Color {
        let colors = [Color.mint, Color.cyan, Color.pink]
        return colors[index % colors.count]
    }
}

struct ResponseCard: View {
    var response: FriendResponse
    var cardColor: Color
    var likeAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(response.latestMessage)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)

            Spacer()

            HStack(alignment: .center) {
                WebImage(url: URL(string: response.profileImageUrl))
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray.opacity(0.5), lineWidth: 1))
                
                VStack(alignment: .leading) {
                    Text(response.email)
                        .font(.headline)
                    Text(response.timestamp, style: .time)
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                Spacer()
                
                HStack {
                    Button(action: {
                        likeAction()
                    }) {
                        Image(systemName: response.likedByCurrentUser ? "heart.fill" : "heart")
                            .foregroundColor(response.likedByCurrentUser ? .red : .gray)
                            .scaleEffect(response.likedByCurrentUser ? 1.2 : 1.0)
                            .animation(.easeIn, value: response.likedByCurrentUser)
                    }
                    Text("\(response.likes)")
                        .font(.subheadline)
                }
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 200)
        .background(cardColor)
        .cornerRadius(25)
        .shadow(color: .gray.opacity(0.4), radius: 10, x: 0, y: 5)
    }
}

struct FullScreenResponseInputView: View {
    @ObservedObject var vm: FriendGroupViewModel
    let selectedUser: ChatUser

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                Text("Today's prompt:")
                    .font(.headline)
                    .padding(.bottom, 4)
                Text(vm.promptText)
                    .font(.body)
                    .padding(.bottom, 20)
                
                TextField("Write your response...", text: $vm.responseText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)

                Button("Submit") {
                    vm.submitResponse(for: selectedUser.uid)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
                .padding(.horizontal)

                Spacer()
            }
            .padding()
            .navigationTitle("Reply to Prompt")
            .navigationBarItems(leading: Button("Cancel") {
                vm.showResponseInput = false
            })
        }
    }
}
