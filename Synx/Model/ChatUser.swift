//
//  ChatUser.swift
//  Synx
//
//  Created by Shawn on 10/17/24.
//

import Foundation

struct ChatUser : Identifiable{
    
    var id: String{uid}
    let uid, email, profileImageUrl: String
    let fcmToken: String
    var hasPosted: Bool  // 新增属性
    
    init(data:[String: Any]){
        self.uid = data["uid"] as? String ?? ""
        self.email = data["email"] as? String ?? ""
        self.profileImageUrl = data["profileImageUrl"] as? String ?? ""
        self.fcmToken = data["fcmToken"] as? String ?? ""
        self.hasPosted = data["hasPosted"] as? Bool ?? false  // 初始化属性
    }
}
