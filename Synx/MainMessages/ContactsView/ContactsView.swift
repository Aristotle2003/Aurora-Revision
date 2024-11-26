import SwiftUI
import FirebaseCore
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
                self.users.sort { $0.username.lowercased() < $1.username.lowercased() }
                
                // Initialize filtered users with all users
                self.filterUsers()
            }
    }
    
    func filterUsers() {
        if searchText.isEmpty {
            filteredUsers = users // Show all friends if search text is empty
        } else {
            filteredUsers = users.filter { user in
                let username = user.username.lowercased()
                let searchQuery = searchText.lowercased()
                return username.contains(searchQuery)
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
            let firstLetter = String(user.username.prefix(1)).uppercased()
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
            ZStack{
                Color(red: 0.976, green: 0.980, blue: 1.0)
                    .ignoresSafeArea()
                VStack{
                    ZStack{
                        Image("liuhaier")
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .ignoresSafeArea()
                        HStack {
                            Image("spacerformainmessageviewtopleft")
                                .resizable()
                                .frame(width: 36, height: 36)
                                .padding(.leading, 28)
                            Spacer()
                            Image("auroratext")
                                .resizable()
                                .scaledToFill()
                                .frame(width: UIScreen.main.bounds.width * 0.1832,
                                       height: UIScreen.main.bounds.height * 0.0198)
                            Spacer()
                            
                            Button(action: {
                                isShowingAddFriendView = true
                            }) {
                                Image("addfriendbutton")
                                    .resizable()
                                    .frame(width: 24, height: 24)
                                    .padding(.trailing, 28)
                            }
                        }
                    }
                    .frame(height: UIScreen.main.bounds.height * 0.07)
                    
                    SearchBar(text: $vm.searchText) {
                        vm.filterUsers()
                    }
                    .padding(.vertical, 4)
                    
                    ScrollView {
                        if !vm.errorMessage.isEmpty {
                            Text(vm.errorMessage)
                                .foregroundColor(.red)
                                .padding()
                        }
                        
                        LazyVStack(spacing: 8) {
                            ForEach(vm.groupedUsers().keys.sorted(), id: \.self) { key in
                                Section(header:
                                            HStack {
                                    Text(key)
                                        .font(.headline.bold()) // Bold font
                                        .foregroundColor(Color.gray) // Grey color
                                        .padding(.leading, 20) // Align to the left with padding
                                    Spacer()
                                }
                                    .padding(.vertical, 4) // Vertical padding for spacing
                                    .background(Color(.clear))
                                ){
                                    ForEach(vm.groupedUsers()[key]!) { user in
                                        Button {
                                            presentationMode.wrappedValue.dismiss()
                                            didSelectNewUser(user)  // Direct selection from CreateNewMessageView
                                        } label: {
                                            ZStack {
                                                // Background bubble image
                                                Image("contactsbubble")
                                                    .resizable()
                                                    .scaledToFit()
                                                    .cornerRadius(16)
                                                
                                                // User content
                                                HStack(spacing: 16) {
                                                    WebImage(url: URL(string: user.profileImageUrl))
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 45, height: 45)
                                                        .clipShape(Circle())
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        
                                                        Text(user.username)
                                                            .font(.system(size: 16, weight: .bold))
                                                            .foregroundColor(Color(red: 0.49, green: 0.52, blue: 0.75))
                                                        
                                                        if let timestamp = user.latestMessageTimestamp {
                                                            Text(formatTimestamp(timestamp))
                                                                .font(.system(size: 14))
                                                                .foregroundColor(Color.gray)
                                                        } else {
                                                            Text("")
                                                                .font(.system(size: 14))
                                                                .foregroundColor(Color.gray)
                                                        }
                                                    }
                                                    
                                                    Spacer()
                                                }
                                                .padding(.leading, 16)
                                            }
                                            .padding(.horizontal, 20)
                                            .padding(.bottom, 0)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                    // Dismiss button at the bottom
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Dismiss")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, maxHeight: 44)
                            .background(Color.blue)
                            .cornerRadius(10)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
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
    
    func formatTimestamp(_ timestamp: Timestamp) -> String {
        let date = timestamp.dateValue()
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            // 如果是今天，显示时间，例如 "14:23"
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            // 如果是昨天，显示 "昨天"
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            // 如果在本周内，显示星期几
            let weekdaySymbols = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
            let weekday = calendar.component(.weekday, from: date)
            print(weekday)
            if weekday == 1 {
                formatter.dateFormat = "yyyy/MM/dd"
                return formatter.string(from: date)
            } else {
                return weekdaySymbols[(weekday + 5) % 7]
            }// 注意：周日对应索引 0
        } else {
            // 否则，显示日期，例如 "2023/10/07"
            formatter.dateFormat = "yyyy/MM/dd"
            return formatter.string(from: date)
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    var onSearch: () -> Void  // Callback for the search action
    
    var body: some View {
        HStack {
            Spacer()
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            // Search input field
            TextField("Search friends", text: $text)
                .font(.system(size: 14)) // Set font size
                .foregroundColor(.gray)
                .submitLabel(.search) // Enable "Search" key on keyboard
                .onSubmit {
                    onSearch()  // Trigger search when "Search" key is pressed
                }
            
            
            // Clear button (conditionally shown)
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
        .padding(10) // Add padding inside the search bar
        .background(
            RoundedRectangle(cornerRadius: 20) // Round corners
                .fill(Color.white) // White background
            
        )
        .frame(maxWidth: .infinity) // Centralized horizontally
        .padding(.horizontal, 20) // Add spacing from edges
    }
}

#Preview {
    MainMessagesView()
}
