//
//  AddFriendView.swift
//  Synx
//
//  Created by Shawn on 11/3/24.
//

import SwiftUI
import SDWebImageSwiftUI

// MARK: - AddFriendViewModel (Add Friends View Model)
class AddFriendViewModel: ObservableObject {
    
    @Published var users = [ChatUser]()          // Stores all users who are not friends
    @Published var filteredUsers = [ChatUser]()  // Stores search results
    @Published var errorMessage = ""             // Stores error messages
    @Published var searchText = "" {             // Stores current search query
        didSet {
            filterUsers()
        }
    }
    
    init() {
        fetchNonFriendUsers()
    }
    
    func fetchNonFriendUsers() {
            guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {
                self.errorMessage = "User not authenticated"
                return
            }
            
            // Step 1: Fetch all users excluding the current user
            FirebaseManager.shared.firestore.collection("users")
                .getDocuments { documentsSnapshot, error in
                    if let error = error {
                        self.errorMessage = "Failed to fetch users: \(error)"
                        return
                    }
                    
                    var allUsers = [ChatUser]()
                    
                    documentsSnapshot?.documents.forEach { snapshot in
                        let data = snapshot.data()
                        let user = ChatUser(data: data)
                        if user.uid != uid {  // Exclude the current user
                            allUsers.append(user)
                        }
                    }
                    
                    // Step 2: Fetch friend list of the current user
                    FirebaseManager.shared.firestore.collection("friends").document(uid).collection("friend_list")
                        .getDocuments { friendSnapshot, error in
                            if let error = error {
                                self.errorMessage = "Failed to fetch friends: \(error)"
                                return
                            }
                            
                            // Extract friend IDs
                            let friendIDs = friendSnapshot?.documents.map { $0.documentID } ?? []
                            
                            // Filter out friends from allUsers
                            self.users = allUsers.filter { !friendIDs.contains($0.uid) }
                            
                            // Sort users alphabetically
                            self.users.sort { $0.email.lowercased() < $1.email.lowercased() }
                            
                            // Update filtered users based on search text
                            self.filterUsers()
                        }
                }
    }

    
    func filterUsers() {
        if searchText.isEmpty {
            let maxUsers = min(users.count, 10)
            filteredUsers = Array(users[0..<maxUsers])
        } else {
            filteredUsers = users.filter { user in
                let email = user.email.lowercased()
                let searchQuery = searchText.lowercased()
                return email.contains(searchQuery)
            }
        }
    }
}

struct AddFriendView: View {
    
    let didSelectNewUser: (ChatUser) -> ()
    @Environment(\.presentationMode) var presentationMode
    
    @StateObject var vm = AddFriendViewModel()
    
    var body: some View {
        NavigationView {
            VStack {

                SearchBar(text: $vm.searchText) {
                    vm.filterUsers()
                }
                .padding(.vertical, 8)
                
                ScrollView {
                    if !vm.errorMessage.isEmpty {
                        Text(vm.errorMessage)
                            .foregroundColor(.red)
                            .padding()
                    }
                    
                    LazyVStack(spacing: 0) {
                        ForEach(vm.filteredUsers) { user in
                            Button {
                                presentationMode.wrappedValue.dismiss()  // Dismiss AddFriendView
                                didSelectNewUser(user)
                            } label: {
                                HStack(spacing: 16) {
                                    WebImage(url: URL(string: user.profileImageUrl))
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 50, height: 50)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color(.systemGray4), lineWidth: 1)
                                        )
                                    
                                    Text(user.email)
                                        .foregroundColor(.primary)
                                        .font(.system(size: 16))
                                    
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 12)
                            }
                            
                            Divider()
                                .padding(.leading, 76)
                        }
                    }
                }
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        // Dismiss the Add Friend View
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
