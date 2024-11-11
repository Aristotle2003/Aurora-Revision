import SwiftUI
import SDWebImageSwiftUI

class CreateNewMessageViewModel: ObservableObject {
    
    @Published var users = [ChatUser]()          // Stores all fetched friends
    @Published var filteredUsers = [ChatUser]()  // Stores search results
    @Published var errorMessage = ""             // Stores error messages
    @Published var searchText = "" {             // Stores current search query
        didSet {
            filterUsers()
        }
    }
    
    init() {
        fetchAllFriends()
    }
    
    private func fetchAllFriends() {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else {
            self.errorMessage = "Could not find firebase uid"
            return
        }
        
        FirebaseManager.shared.firestore.collection("friends").document(uid).collection("friend_list")
            .getDocuments { documentsSnapshot, error in
                if let error = error {
                    self.errorMessage = "Failed to fetch friends: \(error)"
                    return
                }
                
                self.users.removeAll()
                
                documentsSnapshot?.documents.forEach({ snapshot in
                    let data = snapshot.data()
                    let user = ChatUser(data: data)
                    self.users.append(user)
                })
                
                // Sort users by the first letter of their email
                self.users.sort { $0.email.lowercased() < $1.email.lowercased() }
                
                // Initialize filtered users with all users
                self.filterUsers()
            }
    }
    
    func filterUsers() {
        if searchText.isEmpty {
            filteredUsers = users // Show all friends if search text is empty
        } else {
            filteredUsers = users.filter { user in
                let email = user.email.lowercased()
                let searchQuery = searchText.lowercased()
                return email.contains(searchQuery)
            }
        }
    }
    
    // Function to refresh users after adding a new friend
    func refreshUsers() {
        fetchAllFriends()
    }
    
//     // Group users by the first letter of their email
//     func groupedUsers() -> [String: [ChatUser]] {
//         Dictionary(grouping: filteredUsers) { user in
//             String(user.email.prefix(1)).uppercased()
//         }
//     }
// }

    // Group users by the first letter of their email
    func groupedUsers() -> [String: [ChatUser]] {
        Dictionary(grouping: filteredUsers) { user in
            let firstLetter = String(user.email.prefix(1)).uppercased()
            let regex = try! NSRegularExpression(pattern: "^[A-Z]$")
            let range = NSRange(location: 0, length: firstLetter.utf16.count)
            if regex.firstMatch(in: firstLetter, options: [], range: range) != nil {
                return firstLetter
            } else {
                return "#"
            }
        }
    }
}

// MARK: - CreateNewMessageView (Main Contacts View)
struct CreateNewMessageView: View {
    
    let didSelectNewUser: (ChatUser) -> ()  // Closure that will handle the selected user
    
    @Environment(\.presentationMode) var presentationMode
    @StateObject var vm = CreateNewMessageViewModel()
    @State private var isShowingAddFriendView = false  // State for navigating to AddFriendView
    @State private var selectedUserFromAddFriendView: ChatUser? = nil  // Track user passed from AddFriendView
    @State private var hasSelectedUserFromAddFriendView = false  // A flag to track if a user has been selected
    
    var body: some View {
        NavigationView {
            VStack {
                // Search Bar
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
                        ForEach(vm.groupedUsers().keys.sorted(), id: \.self) { key in
                            Section(header: Text(key)
                                        .font(.headline)
                                        .padding(.leading, 16)
                                        .padding(.vertical, 4)
                                        .background(Color(.systemGray6))) {
                                ForEach(vm.groupedUsers()[key]!) { user in
                                    Button {
                                        presentationMode.wrappedValue.dismiss()
                                        didSelectNewUser(user)  // Direct selection from CreateNewMessageView
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
                }
            }
            .onChange(of: hasSelectedUserFromAddFriendView) { oldValue, newValue in
                if newValue, let user = selectedUserFromAddFriendView {
                    didSelectNewUser(user)  // Handle the user passed from AddFriendView
                    selectedUserFromAddFriendView = nil  // Reset after handling
                    hasSelectedUserFromAddFriendView = false  // Reset the flag
                }
            }
            .navigationTitle("Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                // "+" Button for adding new friends
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isShowingAddFriendView = true  // Navigate to AddFriendView
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingAddFriendView) {
                // When AddFriendView selects a user, pass it to CreateNewMessageView
                AddFriendView { newFriend in
                    presentationMode.wrappedValue.dismiss()
                    selectedUserFromAddFriendView = newFriend
                    hasSelectedUserFromAddFriendView = true  // Trigger the change flag
                    isShowingAddFriendView = false  // Dismiss AddFriendView
                }
            }
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    var onSearch: () -> Void  // Add callback for search action
    
    // Add focus state
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack {
            // Search icon and button
            Button(action: {
                onSearch()  // Trigger search
                // Dismiss keyboard when search button is tapped
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                             to: nil, from: nil, for: nil)
            }) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .frame(width: 20, height: 20)
            }
            
            // Search input field
            TextField("Search by email or phone", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isFocused)
                .submitLabel(.search)  // Shows search button on keyboard
                .onSubmit {
                    onSearch()  // Trigger search when return key is pressed
                }
            
            // Clear button
            if !text.isEmpty {
                Button(action: {
                    text = ""  // Clear search text
                    onSearch()  // Trigger search after clearing
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal)
    }
}

#Preview {
    MainMessagesView()
}
