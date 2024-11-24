import Foundation
import FirebaseFirestore

struct ChatUser: Identifiable {
    
    var id: String { uid }
    let uid: String
    let email: String
    let username: String
    var profileImageUrl: String
    let fcmToken: String
    var hasPosted: Bool
    var isPinned: Bool
    var hasUnseenLatestMessage: Bool
    var latestMessageTimestamp: Timestamp?  // 新增属性
    
    
    init(data: [String: Any]) {
        self.uid = data["uid"] as? String ?? ""
        self.email = data["email"] as? String ?? ""
        self.username = data["username"] as? String ?? ""
        self.profileImageUrl = data["profileImageUrl"] as? String ?? ""
        self.fcmToken = data["fcmToken"] as? String ?? ""
        self.hasPosted = data["hasPosted"] as? Bool ?? false
        self.isPinned = data["isPinned"] as? Bool ?? false
        self.hasUnseenLatestMessage = data["hasUnseenLatestMessage"] as? Bool ?? false
        self.latestMessageTimestamp = data["latestMessageTimestamp"] as? Timestamp  // 初始化
        
    }
}


