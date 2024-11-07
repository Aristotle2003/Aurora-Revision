import SwiftUI
import Firebase
import SDWebImageSwiftUI

class FriendGroupViewModel: ObservableObject {
    @Published var promptText = ""
    @Published var responseText = ""
    @Published var responses = [FriendResponse]()
    @Published var showResponseInput = false
    
    private var selectedUser: ChatUser
        
        init(selectedUser: ChatUser) {
            self.selectedUser = selectedUser
        }
    
    func fetchPrompt() {
        FirebaseManager.shared.firestore.collection("prompts").document("currentPrompt")
            .getDocument { snapshot, error in
                if let data = snapshot?.data(), let prompt = data["text"] as? String {
                    self.promptText = prompt
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
            "timestamp": Timestamp()
        ]
        
        responseRef.setData(data) { error in
            if error == nil {
                self.responseText = ""
                self.showResponseInput = false
                print("Response submitted successfully")
                self.fetchLatestResponses(for: userId) // Refresh responses after submission
            } else {
                print("Failed to submit response: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    func fetchLatestResponses(for userId: String) {
        var allResponses: [FriendResponse] = []
        let group = DispatchGroup()

        // Step 1: Fetch the current user's latest response
        group.enter()
        fetchLatestResponse(for: userId) { latestMessage, timestamp in
            if let latestMessage = latestMessage, let timestamp = timestamp {
                allResponses.append(FriendResponse(
                    uid: userId,
                    email: self.selectedUser.email,
                    profileImageUrl: self.selectedUser.profileImageUrl,
                    latestMessage: latestMessage,
                    timestamp: timestamp
                ))
            }
            group.leave()
        }
        
        // Step 2: Fetch friends' responses
        FirebaseManager.shared.firestore.collection("friends")
            .document(userId)
            .collection("friend_list")
            .getDocuments { friendSnapshot, error in
                if let error = error {
                    print("Failed to fetch friends: \(error.localizedDescription)")
                    return
                }
                
                guard let friendDocs = friendSnapshot?.documents else {
                    print("No friends found.")
                    return
                }
                
                for friendDoc in friendDocs {
                    let friendData = friendDoc.data()
                    guard let friendId = friendData["uid"] as? String,
                          let email = friendData["email"] as? String,
                          let profileImageUrl = friendData["profileImageUrl"] as? String else {
                        print("Friend data missing fields")
                        continue
                    }
                    
                    group.enter()
                    print("Fetching latest response for friend with ID: \(friendId)")
                    self.fetchLatestResponse(for: friendId) { latestMessage, timestamp in
                        if let latestMessage = latestMessage, let timestamp = timestamp {
                            allResponses.append(FriendResponse(
                                uid: friendId,
                                email: email,
                                profileImageUrl: profileImageUrl,
                                latestMessage: latestMessage,
                                timestamp: timestamp
                            ))
                        }
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    self.responses = allResponses.sorted { $0.timestamp > $1.timestamp }
                    print("Fetched responses: \(self.responses)")
                }
            }
    }
    
    private func fetchLatestResponse(for uid: String, completion: @escaping (String?, Date?) -> Void) {
        FirebaseManager.shared.firestore.collection("response_to_prompt")
            .whereField("uid", isEqualTo: uid)
            .order(by: "timestamp", descending: true)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let doc = snapshot?.documents.first {
                    let data = doc.data()
                    let latestMessage = data["text"] as? String ?? ""
                    let timestamp = (data["timestamp"] as? Timestamp)?.dateValue()
                    print("Fetched latest message for UID \(uid): \(latestMessage) at \(timestamp ?? Date())")
                    completion(latestMessage, timestamp)
                } else {
                    print("No response found for UID \(uid) – displaying default message.")
                    completion("No response yet", Date())
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
}

struct FriendGroupView: View {
    @ObservedObject var vm: FriendGroupViewModel
    @Environment(\.presentationMode) var presentationMode
    @State var navigateToMainMessage = false
    let selectedUser: ChatUser
    
    
    init(selectedUser: ChatUser) {
        self.selectedUser = selectedUser
        _vm = ObservedObject(wrappedValue: FriendGroupViewModel(selectedUser: selectedUser))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Prompt display
            Text(vm.promptText)
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.1)))
                .padding(.bottom, 8)
            
            // Reply button and input
            Button("Reply") {
                vm.showResponseInput = true
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if vm.showResponseInput {
                VStack(alignment: .leading) {
                    TextField("Write your response...", text: $vm.responseText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    Button("Submit") {
                        vm.submitResponse(for: selectedUser.uid)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                }
            }
            
            // Scroll view for responses
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(vm.responses) { response in
                        HStack(alignment: .top, spacing: 12) {
                            // Profile image
                            WebImage(url: URL(string: response.profileImageUrl))
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.gray.opacity(0.5), lineWidth: 1))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                // Username and timestamp
                                HStack {
                                    Text(response.email)
                                        .font(.headline)
                                    Spacer()
                                    Text(response.timestamp, style: .time)
                                        .font(.footnote)
                                        .foregroundColor(.gray)
                                }
                                
                                // Message text
                                Text(response.latestMessage)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.top, 2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        Divider()
                            .padding(.vertical, 8)
                    }
                }
            }
        }
        .padding(.horizontal)
        .navigationBarHidden(true) // Hide navigation button
        .gesture(
            DragGesture().onEnded { value in
                if value.translation.width < -100 { // Detect right swipe
                    self.navigateToMainMessage.toggle()
                }
            }
        )
        .navigationDestination(isPresented: $navigateToMainMessage){
                MainMessagesView()
        }
        .onAppear {
            vm.fetchPrompt()
            vm.fetchLatestResponses(for: selectedUser.uid)
        }
    }
}
