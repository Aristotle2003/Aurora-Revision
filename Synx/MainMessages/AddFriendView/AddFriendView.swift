//
//  AddFriendView.swift
//  Synx
//
//  Created by Shawn on 11/3/24.
//

import SwiftUI
import SDWebImageSwiftUI
import UIKit
import Contacts
import FirebaseCore

class AddFriendViewModel: ObservableObject {
    @Published var users = [ChatUser]()           // All users who are not friends
    @Published var recommendedUsers = [ChatUser]() // Users recommended based on iPhone contacts
    @Published var randomUsers = [ChatUser]()      // Remaining users
    @Published var searchText = "" {               // Current search query
        didSet {
            filterUsers()
        }
    }
    @Published var currentUser: ChatUser?
    @Published var errorMessage = ""              // Error message
    
    private var allUsers = [ChatUser]()           // Full list of non-friend users before filtering
    
    init() {
        fetchNonFriendUsers()
        fetchCurrentUser()
        processRecommendedUsers()
    }
    
    func fetchNonFriendUsers() {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {
            self.errorMessage = "User not authenticated"
            return
        }
        
        // Fetch all users
        FirebaseManager.shared.firestore.collection("users")
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    self?.errorMessage = "Failed to fetch users: \(error)"
                    return
                }
                
                guard let self = self else { return }
                
                var allUsers = [ChatUser]()
                snapshot?.documents.forEach { document in
                    let user = ChatUser(data: document.data())
                    if user.uid != uid { // Exclude current user
                        allUsers.append(user)
                    }
                }
                
                // Fetch friend list
                FirebaseManager.shared.firestore.collection("friends").document(uid).collection("friend_list")
                    .getDocuments { [weak self] friendSnapshot, error in
                        if let error = error {
                            self?.errorMessage = "Failed to fetch friends: \(error)"
                            return
                        }
                        
                        let friendIDs = friendSnapshot?.documents.map { $0.documentID } ?? []
                        
                        // Exclude friends
                        self?.allUsers = allUsers.filter { !friendIDs.contains($0.uid) }
                        
                        // Process recommended users
                        self?.processRecommendedUsers()
                    }
            }
    }
    
    private func processRecommendedUsers() {
            fetchUserContacts { [weak self] contactNumbers in
                guard let self = self else { return }
                
                // Filter recommended users
                self.recommendedUsers = self.allUsers.filter { user in
                    contactNumbers.contains(user.phoneNumber)
                }
                
                // Filter random users excluding recommended users
                let recommendedUIDs = Set(self.recommendedUsers.map { $0.uid })
                self.randomUsers = self.allUsers.filter { !recommendedUIDs.contains($0.uid) }
                
                // Sort random users alphabetically
                self.randomUsers.sort { $0.username.lowercased() < $1.username.lowercased() }
                
                // Initial filtering for random users
                self.filterUsers()
            }
        }
        
        private func fetchUserContacts(completion: @escaping ([String]) -> Void) {
            let store = CNContactStore()
            store.requestAccess(for: .contacts) { granted, error in
                if granted {
                    let keys = [CNContactPhoneNumbersKey] as [CNKeyDescriptor]
                    let request = CNContactFetchRequest(keysToFetch: keys)
                    var contactNumbers = [String]()
                    
                    do {
                        try store.enumerateContacts(with: request) { contact, _ in
                            contact.phoneNumbers.forEach { number in
                                let phoneNumber = number.value.stringValue
                                contactNumbers.append(phoneNumber.filter("0123456789".contains)) // Clean phone number
                            }
                        }
                        completion(contactNumbers)
                    } catch {
                        completion([])
                    }
                } else {
                    completion([])
                }
            }
        }
    
    
    func filterUsers() {
        DispatchQueue.main.async {
            if self.searchText.isEmpty {
                // When there's no search text, keep Recommended Users as they are
                self.recommendedUsers = self.allUsers.filter { user in
                    self.recommendedUsers.contains(where: { $0.uid == user.uid })
                }
                
                // Exclude recommended users from random users and randomly select 10
                let recommendedUIDs = Set(self.recommendedUsers.map { $0.uid })
                let remainingUsers = self.allUsers.filter { !recommendedUIDs.contains($0.uid) }
                self.randomUsers = Array(remainingUsers.shuffled().prefix(10))
            } else {
                // Flatten into a single filtered list when searching
                let query = self.searchText.lowercased()
                self.randomUsers = self.allUsers.filter { user in
                    user.email.lowercased().contains(query) || user.phoneNumber.contains(query)
                }
                // Keep Recommended Users intact during search
                self.recommendedUsers.removeAll()
            }
        }
    }
    
    func fetchCurrentUser() {
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


}


struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No update needed
    }
}

struct AddFriendView: View {
    @State private var errorMessage = ""
    let didSelectNewUser: (ChatUser) -> ()
    @Environment(\.presentationMode) var presentationMode
    @StateObject var vm = AddFriendViewModel()
    @State private var isSharing = false
    let shareableURL = URL(string: "https://apps.apple.com/us/app/xor/id6621190086")!
    @StateObject private var chatLogViewModel = ChatLogViewModel(chatUser: nil)
    @State private var chatUser: ChatUser? = nil
    @State private var navigateToProfile = false
    @State private var sentRequests: Set<String> = [] // Tracks UIDs of users who have been sent requests

    var body: some View {
        NavigationStack {
            VStack {
                SearchBar(text: $vm.searchText) {
                    vm.filterUsers()
                }
                .padding(.vertical, 8)
                
                Button(action: {
                    isSharing = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Invite Link")
                    }
                    .foregroundColor(.blue)
                }
                .sheet(isPresented: $isSharing) {
                    ShareSheet(activityItems: [shareableURL])
                }
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Recommended Users Section
                        if !vm.recommendedUsers.isEmpty {
                            Section(header: Text("Recommended Users").font(.headline)) {
                                ForEach(vm.recommendedUsers) { user in
                                    userRow(for: user)
                                }
                            }
                        }
                        
                        // Random People Section
                        if !vm.randomUsers.isEmpty {
                            Section(header: Text("Random People").font(.headline)) {
                                ForEach(vm.randomUsers) { user in
                                    userRow(for: user)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Friend")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToProfile) {
                if let chatUser = self.chatUser, let currentUser = vm.currentUser {
                    ProfileView(
                        chatUser: chatUser,
                        currentUser: currentUser,
                        isCurrentUser: false,
                        chatLogViewModel: chatLogViewModel
                    )
                } else {
                    Text("Loading Profile...") // Fallback if navigation occurs prematurely
                }
            }
        }
    }
    
    @ViewBuilder
    private func userRow(for user: ChatUser) -> some View {
        HStack {
            // User Profile Photo - Navigate to ProfileView when clicked
            Button(action: {
                self.chatUser = user
                navigateToProfile = true
            }) {
                WebImage(url: URL(string: user.profileImageUrl))
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            }
            
            // User Name
            VStack(alignment: .leading) {
                Text(user.username)
                    .font(.headline)
            }
            Spacer()
            
            // Add Friend Button
            Button(action: {
                sendFriendRequest(for: user)
            }) {
                Text(sentRequests.contains(user.uid) ? "Request Sent" : "+ Add")
                    .font(.system(size: 14))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(sentRequests.contains(user.uid) ? Color.gray.opacity(0.2) : Color.blue)
                    .foregroundColor(sentRequests.contains(user.uid) ? .gray : .white)
                    .cornerRadius(8)
            }
            .disabled(sentRequests.contains(user.uid)) // Disable button if request is sent
        }
        .padding(.vertical, 8)
        .background(Divider(), alignment: .bottom)
    }
    
    private func sendFriendRequest(for user: ChatUser) {
        guard let currentUser = vm.currentUser else {
            self.errorMessage = "Failed to fetch current user data."
            return
        }

        let friendRequestData: [String: Any] = [
            "fromUid": currentUser.uid,
            "fromEmail": currentUser.email,
            "profileImageUrl": currentUser.profileImageUrl,
            "username": currentUser.username,
            "status": "pending",
            "timestamp": Timestamp()
        ]
        
        FirebaseManager.shared.firestore
            .collection("friend_request")
            .document(user.uid)
            .collection("request_list")
            .document()
            .setData(friendRequestData) { error in
                if let error = error {
                    self.errorMessage = "Failed to send friend request: \(error)"
                    print("Failed to send friend request:", error)
                    return
                }
                
                DispatchQueue.main.async {
                    // Mark the request as sent
                    self.sentRequests.insert(user.uid)
                }
                
                print("Friend request sent successfully!")
            }
    }
}
