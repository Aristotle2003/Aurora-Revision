//import SwiftUI
//import Firebase
//import SDWebImageSwiftUI
//import FirebaseAuth
//
//class FriendGroupScratchViewModel: ObservableObject {
//    @Published var promptText = ""
//    @Published var responseText = ""
//    @Published var responses = [FriendResponse]()
//    @Published var showResponseInput = false
//    @Published var currentUserHasPosted = true  // 新增属性
//    
//    private var selectedUser: ChatUser
//    
//    init(selectedUser: ChatUser) {
//        self.selectedUser = selectedUser
//        fetchCurrentUserHasPostedStatus()
//        fetchPrompt()
//        fetchLatestResponses(for: selectedUser.uid)
//    }
//    
//    func fetchPrompt() {
//        FirebaseManager.shared.firestore.collection("prompts").document("currentPrompt")
//            .getDocument { snapshot, error in
//                if let data = snapshot?.data(), let prompt = data["text"] as? String {
//                    DispatchQueue.main.async {
//                        self.promptText = prompt
//                    }
//                    print("Fetched prompt: \(prompt)")
//                } else {
//                    print("Failed to fetch prompt: \(error?.localizedDescription ?? "Unknown error")")
//                }
//            }
//    }
//    
//    func submitResponse(for userId: String) {
//        let responseRef = FirebaseManager.shared.firestore.collection("response_to_prompt").document()
//        let data: [String: Any] = [
//            "uid": userId,
//            "text": responseText,
//            "timestamp": Timestamp(),
//            "likes": 0,
//            "likedBy": []
//        ]
//        
//        responseRef.setData(data) { error in
//            if error == nil {
//                DispatchQueue.main.async {
//                    self.responseText = ""
//                    self.showResponseInput = false
//                    self.currentUserHasPosted = true
//                }
//                print("Response submitted successfully")
//                self.updateHasPostedStatus(for: userId)  // 更新 hasPosted 状态
//                self.fetchLatestResponses(for: userId)  // Refresh responses after submission
//            } else {
//                print("Failed to submit response: \(error?.localizedDescription ?? "Unknown error")")
//            }
//        }
//    }
//    
//    func fetchLatestResponses(for userId: String) {
//        var allResponses: [FriendResponse] = []
//        let group = DispatchGroup()
//        
//        // 获取当前用户的响应
//        group.enter()
//        fetchLatestResponse(for: userId, email: self.selectedUser.email, profileImageUrl: self.selectedUser.profileImageUrl) { response in
//            if let response = response {
//                allResponses.append(response)
//            }
//            group.leave()
//        }
//        
//        // 获取好友的响应
//        FirebaseManager.shared.firestore.collection("friends")
//            .document(userId)
//            .collection("friend_list")
//            .getDocuments { friendSnapshot, error in
//                if let error = error {
//                    print("获取好友列表失败：\(error.localizedDescription)")
//                    return
//                }
//                
//                guard let friendDocs = friendSnapshot?.documents else {
//                    print("没有找到好友。")
//                    return
//                }
//                
//                for friendDoc in friendDocs {
//                    let friendData = friendDoc.data()
//                    guard let friendId = friendData["uid"] as? String,
//                          let email = friendData["email"] as? String,
//                          let profileImageUrl = friendData["profileImageUrl"] as? String else {
//                        continue
//                    }
//                    
//                    group.enter()
//                    self.fetchLatestResponse(for: friendId, email: email, profileImageUrl: profileImageUrl) { response in
//                        if let response = response {
//                            allResponses.append(response)
//                        }
//                        group.leave()
//                    }
//                }
//                
//                group.notify(queue: .main) {
//                    self.responses = allResponses.sorted { $0.timestamp > $1.timestamp }
//                }
//            }
//    }
//    
//    private func fetchLatestResponse(for uid: String, email: String, profileImageUrl: String, completion: @escaping (FriendResponse?) -> Void) {
//        FirebaseManager.shared.firestore.collection("response_to_prompt")
//            .whereField("uid", isEqualTo: uid)
//            .order(by: "timestamp", descending: true)
//            .limit(to: 1)
//            .getDocuments { snapshot, error in
//                if let doc = snapshot?.documents.first {
//                    let data = doc.data()
//                    let latestMessage = data["text"] as? String ?? ""
//                    let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() ?? Date()
//                    let likes = data["likes"] as? Int ?? 0
//                    let likedBy = data["likedBy"] as? [String] ?? []
//                    let currentUserId = FirebaseManager.shared.auth.currentUser?.uid ?? ""
//                    let likedByCurrentUser = likedBy.contains(currentUserId)
//                    let response = FriendResponse(
//                        uid: uid,
//                        email: email,
//                        profileImageUrl: profileImageUrl,
//                        latestMessage: latestMessage,
//                        timestamp: timestamp,
//                        likes: likes,
//                        likedByCurrentUser: likedByCurrentUser,
//                        documentId: doc.documentID
//                    )
//                    DispatchQueue.main.async {
//                        completion(response)
//                    }
//                } else {
//                    print("未找到 UID \(uid) 的响应")
//                    DispatchQueue.main.async {
//                        completion(nil)
//                    }
//                }
//            }
//    }
//    
//    func fetchCurrentUserHasPostedStatus() {
//        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
//        
//        FirebaseManager.shared.firestore.collection("users").document(uid).getDocument { snapshot, error in
//            if let error = error {
//                print("Failed to fetch current user: \(error.localizedDescription)")
//                return
//            }
//            
//            DispatchQueue.main.async {
//                if let data = snapshot?.data() {
//                    // If `hasPosted` is present, use its value; otherwise, default to false
//                    self.currentUserHasPosted = data["hasPosted"] as? Bool ?? false
//                } else {
//                    // Explicitly set to false if document does not exist or has no data
//                    self.currentUserHasPosted = false
//                }
//            }
//        }
//    }
//
//    func updateHasPostedStatus(for userId: String) {
//        FirebaseManager.shared.firestore.collection("users").document(userId).updateData([
//            "hasPosted": true
//        ]) { error in
//            if let error = error {
//                print("Failed to update hasPosted status: \(error.localizedDescription)")
//                return
//            }
//            print("User's hasPosted status updated successfully.")
//            
//            self.fetchCurrentUserHasPostedStatus()
//        }
//    }
//    
//    // 点赞或取消点赞
//    func toggleLike(for response: FriendResponse) {
//        guard let currentUserId = FirebaseManager.shared.auth.currentUser?.uid else {return}
//        
//        let responseRef = FirebaseManager.shared.firestore
//            .collection("response_to_prompt")
//            .document(response.documentId)
//        
//        let hasLiked = response.likedByCurrentUser
//        
//        responseRef.updateData([
//            "likes": hasLiked ? FieldValue.increment(Int64(-1)) : FieldValue.increment(Int64(1)),
//            "likedBy": hasLiked ? FieldValue.arrayRemove([currentUserId]) : FieldValue.arrayUnion([currentUserId])
//        ]) { error in
//            if let error = error {
//                print("更新点赞状态失败：\(error.localizedDescription)")
//                return
//            }
//            DispatchQueue.main.async {
//                if let index = self.responses.firstIndex(where: { $0.id == response.id }) {
//                    self.responses[index].likedByCurrentUser.toggle()
//                    self.responses[index].likes += hasLiked ? -1 : 1
//                }
//            }
//        }
//    }
//}
//
//
//struct FriendScratcgGroupView: View {
//    @ObservedObject var vm: FriendGroupScratchViewModel
//    @Environment(\.presentationMode) var presentationMode
//    @State var navigateToMainMessage = false
//    @State private var topCardIndex = 0
//    @State private var offset = CGSize.zero
//    @State private var isSwiping = false
//    let selectedUser: ChatUser
//    
//    init(selectedUser: ChatUser) {
//        self.selectedUser = selectedUser
//        _vm = ObservedObject(wrappedValue: FriendGroupScratchViewModel(selectedUser: selectedUser))
//    }
//    
//    var body: some View {
//        VStack(alignment: .leading, spacing: 16) {
//            // Prompt display
//            Text(vm.promptText)
//                .font(.headline)
//                .padding()
//                .frame(maxWidth: .infinity, alignment: .leading)
//                .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
//                .padding(.bottom, 8)
//            
//            // Reply button and input
//            Button("Reply") {
//                vm.showResponseInput = true
//            }
//            .frame(maxWidth: .infinity, alignment: .leading)
//            
//            if vm.showResponseInput {
//                VStack(alignment: .leading) {
//                    TextField("Write your response...", text: $vm.responseText)
//                        .textFieldStyle(RoundedBorderTextFieldStyle())
//                        .padding(.horizontal)
//                    Button("Submit") {
//                        vm.submitResponse(for: selectedUser.uid)
//                    }
//                    .frame(maxWidth: .infinity, alignment: .leading)
//                    .padding(.top, 4)
//                }
//            }
//            
//            // Scroll view for responses
//            ScrollView {
//                ZStack {
//                    if vm.currentUserHasPosted {
//                        // 在 ForEach 循环中，修改显示每个响应的视图
//                        ForEach(vm.responses) { response in
//                            HStack(alignment: .top, spacing: 12) {
//                                // 头像
//                                WebImage(url: URL(string: response.profileImageUrl))
//                                    .resizable()
//                                    .scaledToFill()
//                                    .frame(width: 40, height: 40)
//                                    .clipShape(Circle())
//                                    .overlay(Circle().stroke(Color.gray.opacity(0.5), lineWidth: 1))
//                                
//                                VStack(alignment: .leading, spacing: 4) {
//                                    // 用户名和时间戳
//                                    HStack {
//                                        Text(response.email)
//                                            .font(.headline)
//                                        Spacer()
//                                        Text(response.timestamp, style: .time)
//                                            .font(.footnote)
//                                            .foregroundColor(.gray)
//                                    }
//                                    
//                                    // 消息文本
//                                    Text(response.latestMessage)
//                                        .font(.body)
//                                        .foregroundColor(.primary)
//                                        .fixedSize(horizontal: false, vertical: true)
//                                        .padding(.top, 2)
//                                    
//                                    // 点赞按钮和数量
//                                    HStack {
//                                        Button(action: {
//                                            vm.toggleLike(for: response)
//                                        }) {
//                                            Image(systemName: response.likedByCurrentUser ? "heart.fill" : "heart")
//                                                .foregroundColor(response.likedByCurrentUser ? .red : .gray)
//                                        }
//                                        Text("\(response.likes)")
//                                            .font(.subheadline)
//                                    }
//                                }
//                            }
//                            Divider()
//                                .padding(.vertical, 8)
//                        }
//                    } else {
//                        // 用户未发布，显示锁定视图
//                        VStack {
//                            Spacer() // 在顶部添加 Spacer，增加空白空间，使得居中
//                            Image(systemName: "lock.fill")
//                                .resizable()
//                                .scaledToFit()
//                                .frame(width: 100, height: 100)
//                                .foregroundColor(.gray)
//                            
//                            Text("发布一条动态以解锁好友圈")
//                                .font(.headline)
//                                .padding()
//                            
//                            Button(action: {
//                                vm.showResponseInput = true
//                            }) {
//                                Text("立即发布")
//                                    .foregroundColor(.white)
//                                    .padding()
//                                    .background(Color.blue)
//                                    .cornerRadius(8)
//                            }
//                            Spacer() // 在底部添加 Spacer，增加空白空间，使得居中
//                        }
//                        .frame(maxWidth: .infinity, maxHeight: .infinity) // 让整个 VStack 充满可用的空间
//                    }
//                }
//            }
//        }
//        .padding(.horizontal)
//        .navigationBarHidden(true) // Hide navigation button
//        .gesture(
//            DragGesture().onEnded { value in
//                if value.translation.width < -100 { // Detect right swipe
//                    self.navigateToMainMessage.toggle()
//                }
//            }
//        )
////        .navigationDestination(isPresented: $navigateToMainMessage){
////            MainMessagesView()
////        }
//    }
//}
