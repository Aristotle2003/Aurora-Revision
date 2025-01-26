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
    @Published var isLoading = true
    
    private var selectedUser: ChatUser
    private var listener: ListenerRegistration?
    
    init(selectedUser: ChatUser) {
        self.selectedUser = selectedUser
        fetchPrompt()
        fetchLatestResponses(for: selectedUser.uid)
        setupCurrentUserHasPostedListener()
    }
    
    deinit {
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
                // 重新获取最新的响应数据
                self.fetchLatestResponses(for: userId)
            } else {
                print("Failed to submit response: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    func fetchLatestResponses(for userId: String) {
        var allResponses: [FriendResponse] = []
        let group = DispatchGroup()
        
        group.enter()
        fetchLatestResponse(for: userId, email: self.selectedUser.email, profileImageUrl: self.selectedUser.profileImageUrl, username: self.selectedUser.username) { response in
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
                          let username = friendData["username"] as? String,
                          let profileImageUrl = friendData["profileImageUrl"] as? String else {
                        continue
                    }
                    
                    group.enter()
                    self.fetchLatestResponse(for: friendId, email: email, profileImageUrl: profileImageUrl, username:username) { response in
                        if let response = response {
                            allResponses.append(response)
                        }
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    self.responses = allResponses.sorted { $0.timestamp > $1.timestamp }
                    self.isLoading = false // 数据加载完成
                }
            }
    }
    
    private func fetchLatestResponse(for uid: String, email: String, profileImageUrl: String, username: String, completion: @escaping (FriendResponse?) -> Void) {
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
                        documentId: doc.documentID,
                        username: username
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
        
        FirebaseManager.shared.firestore.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                print("Failed to fetch current user: \(error.localizedDescription)")
                return
            }
            
            DispatchQueue.main.async {
                if let data = snapshot?.data() {
                    // If `hasPosted` is present, use its value; otherwise, default to false
                    self.currentUserHasPosted = data["hasPosted"] as? Bool ?? false
                } else {
                    // Explicitly set to false if document does not exist or has no data
                    self.currentUserHasPosted = false
                }
            }
        }
        
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
            "likedBy": hasLiked ? FieldValue.arrayRemove([currentUserId]) : FieldValue.arrayUnion([currentUserId]),
            "latestLikeTime": FieldValue.serverTimestamp()
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
    let username: String
}

struct FriendGroupView: View {
    @StateObject var vm: FriendGroupViewModel
    @State private var topCardIndex = 0
    @State private var offset = CGSize.zero
    @State private var rotationDegrees = [Double]()
    let selectedUser: ChatUser
    @AppStorage("SeenDailyAuroraTutorial") private var SeenDailyAuroraTutorial: Bool = false
    @State private var tutorialIndex = 0
    @GestureState private var dragOffset: CGFloat = 0
    @State private var SeenDailyAuroraTutorialTemp = false
    @State private var showReportSheet = false
    
    func generateHapticFeedbackMedium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    init(selectedUser: ChatUser) {
        self.selectedUser = selectedUser
        _vm = StateObject(wrappedValue: FriendGroupViewModel(selectedUser: selectedUser))
        _rotationDegrees = State(initialValue: (0..<20).map { _ in Double.random(in: -15...15) })
    }
    
    var safeAreaTopInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?
            .safeAreaInsets.top ?? 0
    }
    
    var body: some View {
        if SeenDailyAuroraTutorial{
            NavigationStack{
                ZStack {
                    // Background Color
                    Color(red: 0.976, green: 0.980, blue: 1.0)
                        .ignoresSafeArea()
                    if vm.isLoading {
                        // 显示加载指示器
                        ProgressView()
                            .scaleEffect(2.0) // 将加载指示器放大到原来的2倍
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            ZStack {
                                Image("liuhaier")
                                    .resizable()
                                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * 0.07 + safeAreaTopInset)
                                    .aspectRatio(nil, contentMode: .fill)
                                    .ignoresSafeArea()
                                
                                HStack {
                                    Spacer()
                                    Image("auroratext")
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: UIScreen.main.bounds.width * 0.1832,
                                               height: UIScreen.main.bounds.height * 0.0198)
                                    Spacer()
                                }
                            }
                            .frame(maxHeight: UIScreen.main.bounds.height * 0.07)
                            
                            HStack{
                                Text("Today's Prompt")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color(.gray))
                                    .padding(.leading, 16)
                                Spacer()
                            }
                            
                            // Add padding to match design
                            
                            // Rounded rectangle containing the prompt text
                            ZStack(alignment: .topLeading) {
                                // Dynamic RoundedRectangle wrapping the content
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(Color(red: 0.898, green: 0.910, blue: 0.996)) // Color equivalent to #E5E8FE
                                
                                HStack(spacing: 20) {
                                    // VStack for Date and Prompt
                                    VStack(alignment: .leading, spacing: 10) {
                                        // Date Text
                                        Text(Date(), style: .date)
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                            .padding(.top, 20) // Pinned 20 from the top
                                            .padding(.leading, 20) // Pinned 20 from the left
                                        
                                        // Prompt Text
                                        Text(vm.promptText)
                                            .font(.headline)
                                            .foregroundColor(.gray)
                                            .fixedSize(horizontal: false, vertical: true) // Allows wrapping
                                            .padding(.bottom, 20) // Padding to the bottom of the rectangle
                                            .padding(.trailing, 20) // Ensure alignment
                                            .padding(.leading, 20) // Align with date
                                    }
                                    .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .leading) // Take up 3/4 of the rectangle
                                    
                                    // Write Daily Aurora Button
                                    Button(action: {
                                        vm.showResponseInput = true
                                        generateHapticFeedbackMedium()
                                    }) {
                                        Image("writedailyaurorabutton") // Icon for the reply button
                                            .resizable()
                                            .frame(width: 24, height: 24) // Icon size
                                    }
                                    .padding()
                                    .padding(.trailing, 10)
                                }
                            }
                            .padding([.leading, .trailing], 20) // Padding for the rectangle
                            .fixedSize(horizontal: false, vertical: true) // Ensure ZStack tightly wraps its content
                            .frame(maxWidth: .infinity, alignment: .top) // Pin the ZStack to the top
                            
                            HStack{
                                Text("Responses by Friends")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Color(.gray))
                                    .padding(.leading, 16)
                                Spacer()
                            }
                            
                            ZStack {
                                if vm.currentUserHasPosted {
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
                                }
                                
                                
                                
                                
                                if !vm.currentUserHasPosted {
                                    ZStack {
                                        Image("blurredbackgroundfordailyaurora") // Icon for the reply button
                                            .resizable()// Icon size
                                            .scaledToFit()
                                            .scaleEffect(1.3)
                                        VStack {
                                            Spacer()
                                            
                                            Image("lockimage")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 250, height: 130)
                                            
                                            Button(action: {
                                                vm.showResponseInput = true
                                                generateHapticFeedbackMedium()
                                            }) {
                                                Image("writeyourownresponsebutton")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .frame(width: 180, height: 100)
                                            }
                                            
                                            Spacer()
                                        }
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .opacity(0.8)
                                        .zIndex(100)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: 450)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .navigationBarHidden(true)
                        .fullScreenCover(isPresented: $vm.showResponseInput) {
                            FullScreenResponseInputView(vm: vm, selectedUser: selectedUser)
                        }
                    }
                }
            }
        }
        else{
            ZStack {
                Color(red: 0.976, green: 0.980, blue: 1.0)
                    .ignoresSafeArea()
                
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        ForEach(0..<4) { index in
                            ZStack {
                                Image("dailyauroratutorialp\(index + 1)")
                                    .resizable()
                                    .scaledToFill()
                                    .edgesIgnoringSafeArea(.all)
                                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                                    .clipped()
                                
                                if index == 3 {
                                    VStack {
                                        Spacer()
                                        Button(action: {
                                            withAnimation(.easeInOut) {
                                                SeenDailyAuroraTutorial = true
                                            }
                                            generateHapticFeedbackMedium()
                                        }) {
                                            Image("dailyauroratutoriallastbutton")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: UIScreen.main.bounds.width * 0.8)
                                        }
                                        .padding(.bottom, 100)
                                    }
                                }
                            }
                            .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
                        }
                    }
                    .frame(width: UIScreen.main.bounds.width * 4, height: UIScreen.main.bounds.height)
                    .offset(x: -CGFloat(tutorialIndex) * UIScreen.main.bounds.width + dragOffset)
                    .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.5), value: dragOffset)
                    .gesture(
                        DragGesture()
                            .updating($dragOffset) { value, state, _ in
                                state = value.translation.width
                            }
                            .onEnded { value in
                                let threshold = UIScreen.main.bounds.width * 0.25
                                var newIndex = tutorialIndex
                                
                                if value.predictedEndTranslation.width < -threshold && tutorialIndex < 3 {
                                    newIndex += 1
                                } else if value.predictedEndTranslation.width > threshold && tutorialIndex > 0 {
                                    newIndex -= 1
                                }
                                
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    tutorialIndex = newIndex
                                }
                            }
                    )
                }
                .ignoresSafeArea()
            }
        }
    }
    
    func getCardColor(index: Int) -> Color {
        let colors = [Color.mint, Color.cyan, Color.pink]
        return colors[index % colors.count]
    }
    
    func calculateHeight(for text: String) -> CGFloat {
        let textWidth = UIScreen.main.bounds.width - 80 // Account for 20 padding on each side
        let font = UIFont.preferredFont(forTextStyle: .headline)
        let size = CGSize(width: textWidth, height: .greatestFiniteMagnitude)
        let boundingBox = text.boundingRect(with: size, options: .usesLineFragmentOrigin, attributes: [.font: font], context: nil)
        
        return boundingBox.height + 80 // Add 80 for date, spacing, and padding
    }
}

struct Comment: Identifiable {
    let id = UUID()
    let uid: String
    let userName: String
    let profileImageUrl: String
    let content: String
    let timestamp: Date // 添加时间戳字段
}


struct ResponseCard: View {
    var response: FriendResponse
    var cardColor: Color
    var likeAction: () -> Void
    
    @State private var isFlipped = false
    @State private var showReportSheet = false
    @State private var reportContent = ""
    @State private var comments: [Comment] = []
    @State private var newCommentText = "" // 新增用于输入评论的文本状态
    @FocusState private var isFocused: Bool
    @State private var isShowingCommentSheet = false
    
    var body: some View {
        ZStack {
            if isFlipped {
                // 卡片背面（显示评论）
                cardBackView
            } else {
                // 卡片正面（显示帖子内容）
                cardFrontView
            }
        }
        .onTapGesture {
            // 点击时翻面
            if !isFlipped {
                // 在翻到背面时拉取评论
                fetchComments()
            }
            withAnimation {
                isFlipped.toggle()
            }
        }
        .frame(width: UIScreen.main.bounds.width * 0.692111,
               height: UIScreen.main.bounds.height * 0.42253)
        .aspectRatio(contentMode: .fit)
        .sheet(isPresented: $showReportSheet) {
            VStack(spacing: 20) {
                Text("Report this response").font(.headline)
                
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
    }
    
    // 卡片正面视图
    private var cardFrontView: some View {
        ZStack {
            cardBackground
            
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let topPadding: CGFloat = 35
                let sidePadding: CGFloat = 20
                let bottomPadding: CGFloat = 20
                let buttonWidth: CGFloat = 24
                let profileSize: CGFloat = 45.0
                let textWidth: CGFloat = 100
                let likeButtonSize: CGFloat = 32.0
                
                let textColor: Color = {
                    if cardColor == .mint {
                        return Color(red: 0.357, green: 0.635, blue: 0.451)
                    } else if cardColor == .cyan {
                        return Color(red: 0.388, green: 0.655, blue: 0.835)
                    } else {
                        return Color(red: 0.49, green: 0.52, blue: 0.75)
                    }
                }()
                
                // 报告按钮
                Group {
                    if cardColor == .mint {
                        Image("reportbuttongreencard")
                            .resizable()
                            .scaledToFit()
                            .frame(width: buttonWidth, height: buttonWidth)
                            .position(x: w - sidePadding - 10, y: topPadding)
                            .onTapGesture {
                                showReportSheet = true
                            }
                    } else if cardColor == .cyan {
                        Image("reportbuttonbluecard")
                            .resizable()
                            .scaledToFit()
                            .frame(width: buttonWidth, height: buttonWidth)
                            .position(x: w - sidePadding - 10, y: topPadding)
                            .onTapGesture {
                                showReportSheet = true
                            }
                    } else if cardColor == .pink {
                        Image("reportbuttonpurplecard")
                            .resizable()
                            .scaledToFit()
                            .frame(width: buttonWidth, height: buttonWidth)
                            .position(x: w - sidePadding - 10, y: topPadding)
                            .onTapGesture {
                                showReportSheet = true
                            }
                    }
                }
                
                // 帖子文本
                Text(response.latestMessage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(textColor)
                    .frame(width: w * 0.7)
                    .multilineTextAlignment(.center)
                    .position(x: w / 2, y: h / 2)
                
                // 头像
                WebImage(url: URL(string: response.profileImageUrl))
                    .resizable()
                    .scaledToFill()
                    .frame(width: profileSize, height: profileSize)
                    .clipShape(Circle())
                    .position(x: sidePadding + profileSize / 2,
                              y: h - bottomPadding - profileSize / 2)
                
                // 用户名和时间
                let textLeftOffset: CGFloat = sidePadding + profileSize + 10
                Group {
                    Text(response.username)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(textColor)
                        .frame(width: textWidth, alignment: .leading)
                        .position(x: textLeftOffset + textWidth / 2,
                                  y: h - bottomPadding - profileSize / 2 - 8)
                    
                    Text(response.timestamp, style: .time)
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                        .frame(width: textWidth, alignment: .leading)
                        .position(x: textLeftOffset + textWidth / 2,
                                  y: h - bottomPadding - profileSize / 2 + 8)
                }
                
                // 点赞按钮和点赞数
                let likeSectionX = w - sidePadding - likeButtonSize / 2
                let likeSectionY = h - bottomPadding - profileSize / 2
                Button(action: {
                    likeAction()
                }) {
                    if cardColor == .mint {
                        Image(response.likedByCurrentUser ? "likegivengreen" : "likenotgivengreen")
                            .resizable()
                            .scaledToFit()
                            .frame(width: likeButtonSize, height: likeButtonSize)
                    } else if cardColor == .cyan {
                        Image(response.likedByCurrentUser ? "likegivenblue" : "likenotgivenblue")
                            .resizable()
                            .scaledToFit()
                            .frame(width: likeButtonSize, height: likeButtonSize)
                    } else if cardColor == .pink {
                        Image(response.likedByCurrentUser ? "likegivenpurple" : "likenotgivenpurple")
                            .resizable()
                            .scaledToFit()
                            .frame(width: likeButtonSize, height: likeButtonSize)
                    }
                }
                .position(x: likeSectionX, y: likeSectionY)
                
                Text("\(response.likes)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(textColor)
                    .position(x: likeSectionX - 30, y: likeSectionY)
            }
        }
    }
    
    // 卡片背面视图（评论）
    private var cardBackView: some View {
        
        ZStack {
            cardBackground
            
            VStack {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(comments) { comment in
                            HStack(alignment: .top, spacing: 10) {
                                if comment.uid != getCurrentUser().uid {
                                    NavigationLink(destination: ProfileView(
                                        chatUser: ChatUser(data: [
                                            "uid": comment.uid, // 插个眼
                                            "userName": comment.userName,
                                            "profileImageUrl": comment.profileImageUrl
                                        ]),
                                        currentUser: getCurrentUser(),
                                        isCurrentUser: false)) {
                                            WebImage(url: URL(string: comment.profileImageUrl))
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 32, height: 32)
                                                .clipShape(Circle())
                                        }
                                }
                                else{
                                    WebImage(url: URL(string: comment.profileImageUrl))
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 32, height: 32)
                                        .clipShape(Circle())
                                }
                                if cardColor == .mint{
                                    VStack(alignment: .leading) {
                                        Text(comment.userName)
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(Color(red: 0.357, green: 0.635, blue: 0.451))
                                        Text(comment.content)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.gray)
                                    }
                                } else if cardColor == .cyan{
                                    VStack(alignment: .leading) {
                                        Text(comment.userName)
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(Color(red: 0.388, green: 0.655, blue: 0.835))
                                        Text(comment.content)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.gray)
                                    }
                                }else{
                                    VStack(alignment: .leading) {
                                        Text(comment.userName)
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(Color(red: 0.49, green: 0.52, blue: 0.75))
                                        Text(comment.content)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.gray)
                                    }
                                }
                                Spacer()
                                Text(comment.timestamp, style: .time)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.top, 2.5)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.top, 70)
                HStack {
                    Button(action: {
                        isShowingCommentSheet = true
                    }) {
                        HStack {
                            Image(systemName: "bubble.left")
                            Text("Add a comment...")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(25)
                    }
                }
                .padding()
                .sheet(isPresented: $isShowingCommentSheet) {
                    NavigationView {
                        VStack {
                            TextField("Add a comment...", text: $newCommentText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding()
                            
                            Spacer()
                        }
                        .navigationTitle("Add Comment")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") {
                                    isShowingCommentSheet = false
                                }
                            }
                            
                            ToolbarItem(placement: .confirmationAction) {
                                Button(action: {
                                    submitNewComment()
                                    isShowingCommentSheet = false
                                }) {
                                    Image(systemName: "paperplane.fill")
                                        .foregroundColor(getButtonColor())
                                }
                            }
                        }
                    }
                }
                
                // 评论输入框和发送按钮固定在底部
//                HStack {
//                    TextField("Add a comment...", text: $newCommentText)
//                        .focused($isFocused)
//                        .textFieldStyle(RoundedBorderTextFieldStyle())
//                        .padding(.leading, 8)
//                        .cornerRadius(25)
//                        .keyboardAdaptive()
//                    
//                    Button(action: {
//                        submitNewComment()
//                        isFocused = false
//                    }) {
//                        if cardColor == .mint {
//                            Image(systemName: "paperplane.fill")
//                                .foregroundColor(Color(red: 0.357, green: 0.635, blue: 0.451))
//                        } else if cardColor == .cyan {
//                            Image(systemName: "paperplane.fill")
//                                .foregroundColor(Color(red: 0.388, green: 0.655, blue: 0.835))
//                        } else if cardColor == .pink {
//                            Image(systemName: "paperplane.fill")
//                                .foregroundColor(Color(red: 0.49, green: 0.52, blue: 0.75))
//                        }
//                    }
//                    .padding(.trailing, 8)
//                }
//                .padding()
            }
        }
    }
    
    private func getButtonColor() -> Color {
            switch cardColor {
            case .mint:
                return Color(red: 0.357, green: 0.635, blue: 0.451)
            case .cyan:
                return Color(red: 0.388, green: 0.655, blue: 0.835)
            case .pink:
                return Color(red: 0.49, green: 0.52, blue: 0.75)
            default:
                return .blue
            }
        }

        // 为正反面提供相同的卡片背景
    private var cardBackground: some View {
        ZStack {
            if cardColor == .mint {
                Image("greencard")
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(25)
            } else if cardColor == .cyan {
                Image("bluecard")
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(25)
            } else if cardColor == .pink {
                Image("purplecard")
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(25)
            } else {
                RoundedRectangle(cornerRadius: 25)
                    .fill(Color.white)
            }
        }
    }
    
    private func submitNewComment() {
        guard let currentUser = FirebaseManager.shared.auth.currentUser else { return }
        guard !newCommentText.isEmpty else { return }
        let commentRef = FirebaseManager.shared.firestore
            .collection("response_to_prompt")
            .document(response.documentId)
            .collection("comments")
            .document()

        let userId = currentUser.uid
        FirebaseManager.shared.firestore.collection("users").document(userId).getDocument { snapshot, error in
            guard let data = snapshot?.data(), error == nil else {
                print("Failed to fetch user data: \(error?.localizedDescription ?? "Unknown error")")
                return
            }

            let userName = data["username"] as? String ?? "Unknown"
            let profileImageUrl = data["profileImageUrl"] as? String ?? ""
            
            let commentData: [String: Any] = [
                "uid": userId,
                "userName": userName,
                "profileImageUrl": profileImageUrl,
                "content": newCommentText,
                "timestamp": FieldValue.serverTimestamp() // 添加时间戳字段
            ]
        
            commentRef.setData(commentData) { error in
                if let error = error {
                    print("Failed to submit comment:", error.localizedDescription)
                    return
                }
                DispatchQueue.main.async {
                    self.newCommentText = ""
                    self.fetchComments()
                }
            }
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

    // 拉取评论方法
    private func fetchComments() {
        FirebaseManager.shared.firestore
            .collection("response_to_prompt")
            .document(response.documentId)
            .collection("comments")
            .order(by: "timestamp", descending: true) // 根据时间戳排序
            .getDocuments { snapshot, error in
                guard let docs = snapshot?.documents, error == nil else { return }
                DispatchQueue.main.async {
                    self.comments = docs.map { doc in
                        let data = doc.data()
                        return Comment(
                            uid: data["uid"] as? String ?? "Unknown",
                            userName: data["userName"] as? String ?? "Unknown",
                            profileImageUrl: data["profileImageUrl"] as? String ?? "",
                            content: data["content"] as? String ?? "",
                            timestamp: (data["timestamp"] as? Timestamp)?.dateValue() ?? Date() // 获取时间戳
                        )
                    }
                }
            }
    }
    
    private func reportFriend() {
        let reportData: [String: Any] = [
            "uid": response.uid,
            "timestamp": FieldValue.serverTimestamp(),
            "content": response.latestMessage,
            "why": reportContent
        ]
        
        FirebaseManager.shared.firestore
            .collection("reports_for_friends_in_dailyaurora")
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


struct FullScreenResponseInputView: View {
    @StateObject var vm: FriendGroupViewModel
    let selectedUser: ChatUser
    
    @State private var keyboardHeight: CGFloat = 0 // Track keyboard height
    @FocusState private var isResponseTextFocused: Bool // For focusing the TextEditor
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    Color(red: 0.976, green: 0.980, blue: 1.0)
                        .ignoresSafeArea()
                    
                    VStack {
                        let topbarheight = UIScreen.main.bounds.height * 0.055
                        HStack {
                            Button(action: {
                                vm.showResponseInput = false
                            }) {
                                Image("chatlogviewbackbutton")
                                    .resizable()
                                    .frame(width: 24, height: 24)
                                    .padding(.leading, 20)
                            }
                            
                            Spacer()
                            
                            Image("auroratext")
                                .resizable()
                                .scaledToFill()
                                .frame(width: UIScreen.main.bounds.width * 0.1832, height: UIScreen.main.bounds.height * 0.0198)
                            
                            Spacer()
                            
                            Button(action: {
                                vm.submitResponse(for: selectedUser.uid)
                            }) {
                                Image("postbutton")
                                    .resizable()
                                    .frame(width: 24, height: 24)
                                    .padding(.trailing, 20)
                            }
                        }
                        .frame(height: topbarheight)
                        
                        HStack {
                            Text("Today's Prompt:")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Color(red: 85/255, green: 85/255, blue: 85/255))
                                .padding(.leading, 25)
                                .padding(.top, 20)
                            Spacer()
                        }
                        
                        HStack {
                            Text(vm.promptText)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(Color(red: 85/255, green: 85/255, blue: 85/255))
                                .padding(.leading, 25)
                                .padding(.trailing, 25)
                                .padding(.top, 10)
                                .fixedSize(horizontal: false, vertical: true) // Allow multiline
                            Spacer()
                        }
                        
                        // Multiline TextEditor for response input
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $vm.responseText)
                                .foregroundColor(Color(red: 85/255, green: 85/255, blue: 85/255)) // Color #555555
                                .font(.system(size: 14))
                                .padding(.horizontal, 25)
                                .scrollContentBackground(.hidden)// Clear background
                                .frame(height: UIScreen.main.bounds.height * 0.3) // 30% of the screen height
                                .focused($isResponseTextFocused) // Manage focus state
                                .tint(Color.gray)
                                .onAppear {
                                    // Automatically focus when view appears
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        self.isResponseTextFocused = true
                                    }
                                }
                                .onChange(of: vm.responseText) { newValue in
                                    if newValue.count > 300 {
                                        vm.responseText = String(newValue.prefix(300)) // Limit to 300 characters
                                    }
                                }
                            if vm.responseText.isEmpty {
                                Text("  Type your answer here...")
                                    .foregroundColor(Color.gray.opacity(0.7)) // Placeholder text color
                                    .font(.system(size: 14))
                                    .padding(.horizontal, 25)
                                    .padding(.vertical, 8)
                            }
                        }
                        
                        // HStack for character count and date
                        HStack {
                            // Character Count at Bottom-Left
                            Text("\(vm.responseText.count)/300")
                                .foregroundColor(Color.gray)
                                .font(.system(size: 12))
                                .padding(.leading, 25)
                            
                            Spacer()
                            
                            // Today's Date at Bottom-Right
                            Text(Date(), style: .date)
                                .foregroundColor(Color.gray)
                                .font(.system(size: 12))
                                .padding(.trailing, 25)
                        }
                        .padding(.bottom, 16)
                        Spacer()
                    }
                    .animation(.easeOut(duration: 0.25), value: keyboardHeight)
                }
                .onAppear {
                    // Observe keyboard events
                    NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                        if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                            self.keyboardHeight = keyboardFrame.height
                        }
                    }
                    NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                        self.keyboardHeight = 0
                    }
                }
                .onDisappear {
                    NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
                    NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
                }
                .ignoresSafeArea(.keyboard)
            }
        }
    }
}

extension View {
    func keyboardAdaptive() -> some View {
        self.modifier(KeyboardAdaptive())
    }
}

struct KeyboardAdaptive: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight)
            .onAppear {
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { notification in
                    if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                        keyboardHeight = keyboardFrame.height
                    }
                }
                
                NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { _ in
                    keyboardHeight = 0
                }
            }
    }
}
