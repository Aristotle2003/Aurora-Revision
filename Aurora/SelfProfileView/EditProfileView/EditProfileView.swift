import SwiftUI
import Firebase

class ProfileViewModel: ObservableObject {
    @Published var age: String = ""
    @Published var gender: String = ""
    @Published var email: String = ""
    @Published var bio: String = ""
    @Published var location: String = "Select Location"
    @Published var username: String = ""
    @Published var birthdate: Date = Date()
    @Published var pronouns: String = ""
    @Published var name: String = ""
    
    private let currentUser: ChatUser
    
    init(currentUser: ChatUser) {
        self.currentUser = currentUser
        loadCurrentInfo()
    }
    
    func loadCurrentInfo() {
        FirebaseManager.shared.firestore
            .collection("basic_information")
            .document(currentUser.uid)
            .collection("information")
            .document("profile")
            .getDocument { snapshot, error in
                if let data = snapshot?.data() {
                    self.age = data["age"] as? String ?? ""
                    self.gender = data["gender"] as? String ?? ""
                    self.email = data["email"] as? String ?? ""
                    self.bio = data["bio"] as? String ?? ""
                    self.location = data["location"] as? String ?? ""
                    self.username = data["username"] as? String ?? ""
                    self.pronouns = data["pronouns"] as? String ?? ""
                    self.name = data["name"] as? String ?? ""
                    if let birthdateString = data["birthdate"] as? String,
                       let birthdate = ISO8601DateFormatter().date(from: birthdateString) {
                        self.birthdate = birthdate
                    } else {
                        self.birthdate = Date()
                    }
                } else if let error = error {
                    print("Error loading current information: \(error)")
                }
            }
    }
    
    func saveProfileInfo() {
        let profileData: [String: Any] = [
            "age": age,
            "gender": gender,
            "email": email,
            "bio": bio,
            "location": location,
            "username": username,
            "birthdate": birthdate,
            "pronouns": pronouns,
            "name": name
        ]
        
        FirebaseManager.shared.firestore
            .collection("basic_information")
            .document(currentUser.uid)
            .collection("information")
            .document("profile")
            .setData(profileData) { error in
                if let error = error {
                    print("Failed to save profile information: \(error)")
                } else {
                    print("Profile information saved successfully!")
                }
            }
        updateUsername()//Please skip update if the username doesn't change
    }
    
    private func updateUsername() {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        
        let updatedData: [String: Any] = ["username": username]
        
        saveUsernameToCentralDb(uid: uid, data: updatedData)
    }
    
    private func saveUsernameToCentralDb(uid: String, data: [String: Any]) {
        let userRef = FirebaseManager.shared.firestore.collection("users").document(uid)
        userRef.updateData(data) { error in
            if let error = error {
                print("Failed to update profile: \(error)")
                return
            }
            print("Profile updated successfully")
            self.saveUsernameToFriends(uid: uid, data: data)
        }
    }

    private func saveUsernameToFriends(uid: String, data: [String: Any]) {
        let friendsRef = FirebaseManager.shared.firestore.collection("friends").document(uid).collection("friend_list")
        friendsRef.getDocuments { snapshot, error in
            if let error = error {
                print("Failed to fetch friends: \(error)")
                return
            }
            guard let documents = snapshot?.documents else { return }
            for document in documents {
                let friendId = document.documentID
                let friendRef = FirebaseManager.shared.firestore.collection("friends").document(friendId).collection("friend_list").document(uid)
                friendRef.updateData(data) { error in
                    if let error = error {
                        print("Failed to update friend profile: \(error)")
                    } else {
                        print("Friend profile updated successfully")
                    }
                }
            }
        }
    }
}

struct EditProfileView: View {
    @StateObject private var profileVM: ProfileViewModel
    @Environment(\.dismiss) var dismiss
    @ObservedObject var chatLogViewModel: ChatLogViewModel
    
    init(currentUser: ChatUser, chatLogViewModel: ChatLogViewModel) {
        _profileVM = StateObject(wrappedValue: ProfileViewModel(currentUser: currentUser))
        self.chatLogViewModel = chatLogViewModel
    }
    
    var body: some View {
        NavigationView {
            ZStack{
                Color(red: 0.976, green: 0.980, blue: 1.0)
                    .ignoresSafeArea()
                VStack {
                    // Custom Navigation Header
                    HStack {
                        Button(action: {
                            dismiss() // Dismiss the view when back button is pressed
                        }) {
                            Image("chatlogviewbackbutton") // Replace with your back button image
                                .resizable()
                                .frame(width: 24, height: 24) // Customize this color
                        }
                        Spacer()
                        Text("Edit Profile")
                            .font(.system(size: 20, weight: .bold)) // Customize font style
                            .foregroundColor(Color(red: 125/255, green: 133/255, blue: 191/255)) // Customize text color
                        Spacer()
                        Image("spacerformainmessageviewtopleft") // Replace with your back button image
                            .resizable()
                            .frame(width: 24, height: 24) // To balance the back button
                    }
                    .padding()
                    .background(Color(red: 229/255, green: 232/255, blue: 254/255))
                    
                    Form {
                        Section(header: Text("")) {
                            
                            NavigationLink(destination: UsernameInputView(title: "Username", value: $profileVM.username)) {
                                HStack {
                                    Text("Username")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                                    Spacer()
                                    Text(profileVM.username.isEmpty ? "Enter Username" : profileVM.username)
                                        .foregroundColor(.gray)
                                }
                                .frame(height: 54)
                            }
                            
                            NavigationLink(destination: NameInputView(title: "Your name", value: $profileVM.name)) {
                                HStack {
                                    Text("Name")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                                    Spacer()
                                    Text(profileVM.name.isEmpty ? "Enter name" : profileVM.name)
                                        .foregroundColor(.gray)
                                }
                                .frame(height: 54)
                                
                            }
                            
                            NavigationLink(destination: GenderInputView(title: "Gender", value: $profileVM.gender)) {
                                HStack {
                                    Text("Gender")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                                    Spacer()
                                    Text(profileVM.gender.isEmpty ? "Enter Gender" : profileVM.gender)
                                        .foregroundColor(.gray)
                                }
                                .frame(height: 54)
                            }
                            
                            NavigationLink(destination: AgeInputView(title: "Age", value: $profileVM.age)) {
                                HStack {
                                    Text("Age")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                                    Spacer()
                                    Text(profileVM.age.isEmpty ? "Enter Age" : profileVM.age)
                                        .foregroundColor(.gray)
                                }
                                .frame(height: 54)
                            }

                            NavigationLink(destination: PronounsInputView(title: "Pronouns", value: $profileVM.pronouns)) {
                                HStack {
                                    Text("Pronouns")
                                        .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                                        .font(.system(size: 14, weight: .bold))
                                    Spacer()
                                    Text(profileVM.pronouns.isEmpty ? "Enter pronouns" : profileVM.pronouns)
                                        .foregroundColor(.gray)
                                }
                                .frame(height: 54)
                            }
                            
                            NavigationLink(destination: LocationInputView(title: "Location", value: $profileVM.location)) {
                                HStack {
                                    Text("Location")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))

                                    Spacer()
                                    Text(profileVM.location.isEmpty ? "Select Location" : profileVM.location)
                                        .foregroundColor(.gray)
                                }
                                .frame(height: 54)
                            }
                            
                            NavigationLink(destination: BioInputView(title: "Bio", value: $profileVM.bio)) {
                                HStack {
                                    Text("Bio")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                                    Spacer()
                                    Text(profileVM.bio.isEmpty ? "Enter Bio" : profileVM.bio)
                                        .foregroundColor(.gray)
                                }
                                .frame(height: 54)
                            }
                            
                    
                            /*NavigationLink(destination: BirthdatePickerView(selectedDate: $profileVM.birthdate)) {
                                HStack {
                                    Text("Birthdate")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                                    Spacer()
                                    Text("\(profileVM.birthdate.formatted(.dateTime.year().month().day()))")
                                        .foregroundColor(.gray)
                                }
                                .frame(height: 64)
                            }*/
                        }
                        
                        
                        Button(action: {
                            profileVM.saveProfileInfo()
                            dismiss()
                        }) {
                            Image("savebuttoneditprofileview")
                                .scaledToFit()
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(Color(red: 0.976, green: 0.980, blue: 1.0))
                    .cornerRadius(32)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

struct NameInputView: View {
    let title: String
    @Binding var value: String      // The binding coming from the parent
    @Environment(\.dismiss) var dismiss
    
    // 1) Create a local state property
    @State private var tempValue: String
    
    func generateHapticFeedbackMedium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func generateHapticFeedbackHeavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }
    
    init(title: String, value: Binding<String>) {
        self.title = title
        self._value = value
        // Initialize the local copy with the current parent value
        _tempValue = State(initialValue: value.wrappedValue)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.976, green: 0.980, blue: 1.0)
                    .ignoresSafeArea()
                VStack {
                    
                    // Custom Navigation Header
                    HStack {
                        Button(action: {
                            // 2) If the user taps Back, just dismiss without saving changes
                            dismiss()
                            generateHapticFeedbackMedium()
                        }) {
                            Image("chatlogviewbackbutton")
                                .resizable()
                                .frame(width: 24, height: 24)
                        }
                        Spacer()
                        Text("Name")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(red: 125/255, green: 133/255, blue: 191/255))
                        Spacer()
                        Image("spacerformainmessageviewtopleft")
                            .resizable()
                            .frame(width: 24, height: 24)
                    }
                    .padding()
                    .background(Color(red: 229/255, green: 232/255, blue: 254/255))
                    
                    Spacer().frame(height: 28)
                    
                    // 3) Bind the TextField to tempValue instead of the direct binding
                    HStack {
                        TextField("Enter \(title)", text: $tempValue)
                            .padding()
                            .background(Color.white)
                            .foregroundColor(Color(red: 125/255, green: 125/255, blue: 125/255))
                            .cornerRadius(24)
                            .padding(.horizontal)
                        
                        if !tempValue.isEmpty {
                            Button(action: {
                                tempValue = "" // Clear the textfield
                                generateHapticFeedbackMedium()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 16)
                            }
                        }
                    }
                    
                    HStack {
                        Text("Consider filling in some 'real' name so your friends know who you are!")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                            .padding(.horizontal)
                            .padding(.top, 12)
                        Spacer().frame(width: 40)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 4) On tapping Done, copy local tempValue back into the original Binding, then dismiss
                    Button(action: {
                        value = tempValue   // This actually saves the change to the parent's binding
                        dismiss()
                        generateHapticFeedbackMedium()
                    }) {
                        Image("donebutton")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .scaledToFit()
                            .padding()
                    }
                    
                    Spacer()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}


// MARK: - Detail Input View
struct UsernameInputView: View {
    let title: String
    @Binding var value: String
    @Environment(\.dismiss) var dismiss
    
    // Local copy of the binding text
    @State private var tempValue: String
    
    func generateHapticFeedbackMedium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func generateHapticFeedbackHeavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }
    
    // We need a custom initializer so we can initialize `tempValue` with the parent's value
    init(title: String, value: Binding<String>) {
        self.title = title
        self._value = value
        self._tempValue = State(initialValue: value.wrappedValue)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.976, green: 0.980, blue: 1.0)
                    .ignoresSafeArea()
                
                VStack {
                    // Custom Navigation Header
                    HStack {
                        // Back Button -> Discard changes and dismiss
                        Button(action: {
                            generateHapticFeedbackMedium()
                            dismiss()
                        }) {
                            Image("chatlogviewbackbutton") // Replace with your back button image
                                .resizable()
                                .frame(width: 24, height: 24)
                        }
                        Spacer()
                        
                        Text("Username")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(red: 125/255, green: 133/255, blue: 191/255))
                        
                        Spacer()
                        
                        // Spacer image for symmetrical layout
                        Image("spacerformainmessageviewtopleft")
                            .resizable()
                            .frame(width: 24, height: 24)
                    }
                    .padding()
                    .background(Color(red: 229/255, green: 232/255, blue: 254/255))
                    
                    Spacer().frame(height: 28)
                    
                    // TextField bound to the local state `tempValue`
                    HStack {
                        TextField("Enter \(title)", text: $tempValue)
                            .padding()
                            .background(Color.white)
                            .foregroundColor(Color(red: 125/255, green: 125/255, blue: 125/255))
                            .cornerRadius(24)
                            .padding(.horizontal)
                        
                        if !tempValue.isEmpty {
                            Button(action: {
                                tempValue = "" // Clear the textfield
                                generateHapticFeedbackMedium()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 16)
                            }
                        }
                    }
                    
                    HStack {
                        Text("This is not a unique identifier of you! So think of Aurora's username as your 'internet name'. We uniquely identify our users by their email or phone.")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                            .padding(.horizontal)
                            .padding(.top, 12)
                        
                        Spacer().frame(width: 40)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Done button -> commit changes back to parent, then dismiss
                    Button(action: {
                        value = tempValue   // write the local changes back to the binding
                        dismiss()
                        generateHapticFeedbackMedium()
                    }) {
                        Image("donebutton")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .scaledToFit()
                            .padding()
                    }
                    
                    Spacer()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}


// MARK: - Detail Input View
struct AgeInputView: View {
    let title: String
    @Binding var value: String
    @Environment(\.dismiss) var dismiss
    
    // Local copy of the binding text
    @State private var tempValue: String
    
    func generateHapticFeedbackMedium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func generateHapticFeedbackHeavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }
    
    // Custom initializer to initialize `tempValue`
    init(title: String, value: Binding<String>) {
        self.title = title
        self._value = value
        self._tempValue = State(initialValue: value.wrappedValue)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.976, green: 0.980, blue: 1.0)
                    .ignoresSafeArea()
                
                VStack {
                    // Custom Navigation Header
                    HStack {
                        // Back button -> discard changes
                        Button(action: {
                            generateHapticFeedbackMedium()
                            dismiss()
                        }) {
                            Image("chatlogviewbackbutton") // Replace with your back button image
                                .resizable()
                                .frame(width: 24, height: 24)
                        }
                        Spacer()
                        
                        Text("Age")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(red: 125/255, green: 133/255, blue: 191/255))
                        
                        Spacer()
                        
                        Image("spacerformainmessageviewtopleft") // Symmetry
                            .resizable()
                            .frame(width: 24, height: 24)
                    }
                    .padding()
                    .background(Color(red: 229/255, green: 232/255, blue: 254/255))
                    
                    Spacer().frame(height: 28)
                    
                    // TextField using our local state `tempValue`
                    HStack {
                        TextField("Enter \(title)", text: $tempValue)
                            .padding()
                            .background(Color.white)
                            .foregroundColor(Color(red: 125/255, green: 125/255, blue: 125/255))
                            .cornerRadius(24)
                            .padding(.horizontal)
                        
                        if !tempValue.isEmpty {
                            Button(action: {
                                tempValue = "" // Clear the textfield
                                generateHapticFeedbackMedium()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 16)
                            }
                        }
                    }
                    
                    HStack {
                        Text("How old are you?")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                            .padding(.horizontal)
                            .padding(.top, 12)
                        
                        Spacer().frame(width: 40)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Done button -> commit local changes back to parent, then dismiss
                    Button(action: {
                        value = tempValue  // Save changes to parent
                        dismiss()
                        generateHapticFeedbackMedium()
                    }) {
                        Image("donebutton")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .scaledToFit()
                            .padding()
                    }
                    
                    Spacer()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}


// MARK: - Detail Input View
struct GenderInputView: View {
    let title: String
    @Binding var value: String      // Parent binding
    @Environment(\.dismiss) var dismiss
    
    // Local states
    @State private var localSelectedGender: String = ""
    @State private var localIsCustom: Bool = false
    @State private var localCustomValue: String = ""
    
    func generateHapticFeedbackMedium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func generateHapticFeedbackHeavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }
    
    init(title: String, value: Binding<String>) {
        self.title = title
        self._value = value
        
        // Initialize local states based on the parent's current value
        if value.wrappedValue == "Male" || value.wrappedValue == "Female" {
            // Parent's value is a known gender
            _localSelectedGender = State(initialValue: value.wrappedValue)
            _localIsCustom       = State(initialValue: false)
            _localCustomValue    = State(initialValue: "")
        } else {
            // Parent's value is something else (custom)
            _localSelectedGender = State(initialValue: "")
            _localIsCustom       = State(initialValue: true)
            _localCustomValue    = State(initialValue: value.wrappedValue)
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.976, green: 0.980, blue: 1.0)
                    .ignoresSafeArea()
                
                VStack {
                    // Custom Navigation Header
                    HStack {
                        // Back button -> discard changes
                        Button(action: {
                            dismiss()
                            generateHapticFeedbackMedium()
                        }) {
                            Image("chatlogviewbackbutton")
                                .resizable()
                                .frame(width: 24, height: 24)
                        }
                        Spacer()
                        
                        Text("Gender")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(red: 125/255, green: 133/255, blue: 191/255))
                        
                        Spacer()
                        
                        Image("spacerformainmessageviewtopleft")
                            .resizable()
                            .frame(width: 24, height: 24)
                    }
                    .padding()
                    .background(Color(red: 229/255, green: 232/255, blue: 254/255))
                    
                    Spacer().frame(height: 28)
                    
                    // Gender Selection Options
                    VStack(alignment: .leading, spacing: 20) {
                        GenderOptionButton(
                            title: "Female",
                            selectedGender: $localSelectedGender,
                            isCustom: $localIsCustom,
                            localCustomValue: $localCustomValue
                        )
                        
                        GenderOptionButton(
                            title: "Male",
                            selectedGender: $localSelectedGender,
                            isCustom: $localIsCustom,
                            localCustomValue: $localCustomValue
                        )
                        
                        // "Custom" option
                        Button(action: {
                            localIsCustom = true
                            localSelectedGender = ""
                            localCustomValue = ""  // Clear any previous custom text
                            generateHapticFeedbackMedium()
                        }) {
                            HStack {
                                ZStack {
                                    Circle()
                                        .strokeBorder(
                                            localSelectedGender.isEmpty && localIsCustom
                                            ? Color(red: 125/255, green: 133/255, blue: 191/255)
                                            : Color.gray,
                                            lineWidth: 2
                                        )
                                        .frame(width: 24, height: 24)
                                    
                                    if localSelectedGender.isEmpty && localIsCustom {
                                        Circle()
                                            .fill(Color(red: 125/255, green: 133/255, blue: 191/255))
                                            .frame(width: 12, height: 12)
                                    }
                                }
                                
                                Text("Custom")
                                    .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                                    .font(.system(size: 16))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    
                    // If "Custom" is selected, show a text field
                    if localIsCustom {
                        HStack {
                            TextField("Enter Custom Gender", text: $localCustomValue)
                                .padding()
                                .background(Color.white)
                                .foregroundColor(Color(red: 125/255, green: 125/255, blue: 125/255))
                                .cornerRadius(24)
                                .padding(.horizontal)
                            
                            if !localCustomValue.isEmpty {
                                Button(action: {
                                    localCustomValue = ""
                                    generateHapticFeedbackMedium()
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                        .padding(.trailing, 16)
                                }
                            }
                        }
                    }
                    
                    Spacer().frame(height: 16)
                    
                    // Done button -> commit changes back to parent's `value`
                    Button(action: {
                        if localIsCustom {
                            value = localCustomValue
                        } else {
                            value = localSelectedGender
                        }
                        dismiss()
                        generateHapticFeedbackMedium()
                    }) {
                        Image("donebutton")
                            .scaledToFit()
                            .padding()
                    }
                    
                    Spacer()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Custom Button for Gender Selection
struct GenderOptionButton: View {
    let title: String
    
    @Binding var selectedGender: String
    @Binding var isCustom: Bool
    @Binding var localCustomValue: String  // helps in clearing custom data if needed
    
    func generateHapticFeedbackMedium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func generateHapticFeedbackHeavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }
    
    var body: some View {
        Button(action: {
            selectedGender = title
            isCustom = false
            localCustomValue = ""  // clear out any custom text
            generateHapticFeedbackMedium()
        }) {
            HStack {
                ZStack {
                    Circle()
                        .strokeBorder(
                            selectedGender == title && !isCustom
                            ? Color(red: 125/255, green: 133/255, blue: 191/255)
                            : Color.gray,
                            lineWidth: 2
                        )
                        .frame(width: 24, height: 24)
                    
                    if selectedGender == title && !isCustom {
                        Circle()
                            .fill(Color(red: 125/255, green: 133/255, blue: 191/255))
                            .frame(width: 12, height: 12)
                    }
                }
                
                Text(title)
                    .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                    .font(.system(size: 16))
            }
        }
    }
}


// MARK: - Detail Input View
struct PronounsInputView: View {
    let title: String
    @Binding var value: String
    @Environment(\.dismiss) var dismiss
    
    // Local state to hold the text while editing
    @State private var tempValue: String
    
    func generateHapticFeedbackMedium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func generateHapticFeedbackHeavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }
    
    init(title: String, value: Binding<String>) {
        self.title = title
        self._value = value
        // Initialize the local copy from the parent binding
        _tempValue = State(initialValue: value.wrappedValue)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.976, green: 0.980, blue: 1.0)
                    .ignoresSafeArea()
                
                VStack {
                    // Custom Navigation Header
                    HStack {
                        // Back button -> discard changes
                        Button(action: {
                            dismiss()
                            generateHapticFeedbackMedium()
                        }) {
                            Image("chatlogviewbackbutton") // Replace with your back button image
                                .resizable()
                                .frame(width: 24, height: 24)
                        }
                        Spacer()
                        
                        Text("Pronouns")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(red: 125/255, green: 133/255, blue: 191/255))
                        
                        Spacer()
                        
                        Image("spacerformainmessageviewtopleft") // Balance the layout
                            .resizable()
                            .frame(width: 24, height: 24)
                    }
                    .padding()
                    .background(Color(red: 229/255, green: 232/255, blue: 254/255))
                    
                    Spacer().frame(height: 28)
                    
                    // TextField uses the local state `tempValue`
                    HStack {
                        TextField("Enter \(title)", text: $tempValue)
                            .padding()
                            .background(Color.white)
                            .foregroundColor(Color(red: 125/255, green: 125/255, blue: 125/255))
                            .cornerRadius(24)
                            .padding(.horizontal)
                        
                        if !tempValue.isEmpty {
                            Button(action: {
                                tempValue = "" // Clear the textfield
                                generateHapticFeedbackMedium()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 16)
                            }
                        }
                    }
                    
                    HStack {
                        Text("Enter your pronouns.")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                            .padding(.horizontal)
                            .padding(.top, 12)
                        Spacer().frame(width: 40)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Done button -> save tempValue to parent's binding, then dismiss
                    Button(action: {
                        value = tempValue
                        dismiss()
                        generateHapticFeedbackMedium()
                    }) {
                        Image("donebutton")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .scaledToFit()
                            .padding()
                    }
                    
                    Spacer()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - Detail Input View
struct BioInputView: View {
    let title: String
    @Binding var value: String
    @Environment(\.dismiss) var dismiss
    
    // Local copy of the bio text
    @State private var tempValue: String
    
    func generateHapticFeedbackMedium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func generateHapticFeedbackHeavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }
    
    init(title: String, value: Binding<String>) {
        self.title = title
        self._value = value
        // Initialize local state from parent
        _tempValue = State(initialValue: value.wrappedValue)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.976, green: 0.980, blue: 1.0)
                    .ignoresSafeArea()
                
                VStack {
                    // Custom Navigation Header
                    HStack {
                        // Back button -> discard changes
                        Button(action: {
                            dismiss()
                            generateHapticFeedbackMedium()
                        }) {
                            Image("chatlogviewbackbutton")
                                .resizable()
                                .frame(width: 24, height: 24)
                        }
                        Spacer()
                        
                        Text("Bio")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(red: 125/255, green: 133/255, blue: 191/255))
                        
                        Spacer()
                        
                        Image("spacerformainmessageviewtopleft")
                            .resizable()
                            .frame(width: 24, height: 24)
                    }
                    .padding()
                    .background(Color(red: 229/255, green: 232/255, blue: 254/255))
                    
                    Spacer().frame(height: 28)
                    
                    // Multiline Text Editor (bound to local state)
                    ZStack(alignment: .bottomTrailing) {
                        TextEditor(text: $tempValue)
                            .padding()
                            .foregroundColor(Color(red: 125/255, green: 125/255, blue: 125/255))
                            .background(Color.white)
                            .cornerRadius(20)
                            .frame(height: 150)
                            .onChange(of: tempValue) { newValue in
                                // Limit to 100 characters
                                if newValue.count > 100 {
                                    tempValue = String(newValue.prefix(100))
                                }
                            }
                        
                        Text("\(tempValue.count)/100")
                            .foregroundColor(.gray)
                            .font(.system(size: 12))
                            .padding(.trailing, 16)
                            .padding(.bottom, 8)
                    }
                    .padding(.horizontal)
                    
                    Text("Tell us what's special about you!")
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Done (Save) Button -> write tempValue to parent, then dismiss
                    Button(action: {
                        value = tempValue
                        dismiss()
                        generateHapticFeedbackMedium()
                    }) {
                        Image("donebutton")
                            .resizable()
                            .scaledToFit()
                            .padding()
                    }
                    
                    Spacer()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}



// MARK: - Detail Input View
struct LocationInputView: View {
    let title: String
    @Binding var value: String
    @Environment(\.dismiss) var dismiss
    
    // Local copy of the location text
    @State private var tempValue: String
    
    func generateHapticFeedbackMedium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func generateHapticFeedbackHeavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }
    
    init(title: String, value: Binding<String>) {
        self.title = title
        self._value = value
        // Initialize local state from the parent's binding
        _tempValue = State(initialValue: value.wrappedValue)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.976, green: 0.980, blue: 1.0)
                    .ignoresSafeArea()
                
                VStack {
                    // Custom Navigation Header
                    HStack {
                        // Back button -> discard changes
                        Button(action: {
                            dismiss()
                            generateHapticFeedbackMedium()
                        }) {
                            Image("chatlogviewbackbutton")
                                .resizable()
                                .frame(width: 24, height: 24)
                        }
                        Spacer()
                        
                        Text("Location")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(red: 125/255, green: 133/255, blue: 191/255))
                        
                        Spacer()
                        
                        Image("spacerformainmessageviewtopleft")
                            .resizable()
                            .frame(width: 24, height: 24)
                    }
                    .padding()
                    .background(Color(red: 229/255, green: 232/255, blue: 254/255))
                    
                    Spacer().frame(height: 28)
                    
                    // TextField for local state
                    HStack {
                        TextField("Enter \(title)", text: $tempValue)
                            .padding()
                            .background(Color.white)
                            .foregroundColor(Color(red: 125/255, green: 125/255, blue: 125/255))
                            .cornerRadius(24)
                            .padding(.horizontal)
                        
                        if !tempValue.isEmpty {
                            Button(action: {
                                tempValue = "" // Clear the textfield
                                generateHapticFeedbackMedium()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 16)
                            }
                        }
                    }
                    
                    HStack {
                        Text("Enter your location.")
                            .font(.system(size: 12))
                            .foregroundColor(Color(red: 86/255, green: 86/255, blue: 86/255))
                            .padding(.horizontal)
                            .padding(.top, 12)
                        Spacer().frame(width: 40)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Done button -> save changes to parent's binding, then dismiss
                    Button(action: {
                        value = tempValue
                        dismiss()
                        generateHapticFeedbackMedium()
                    }) {
                        Image("donebutton")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .scaledToFit()
                            .padding()
                    }
                    
                    Spacer()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}


// MARK: - Birthdate Picker View
struct BirthdatePickerView: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            DatePicker("Select Birthdate", selection: $selectedDate, displayedComponents: [.date])
                .datePickerStyle(WheelDatePickerStyle())
                .labelsHidden()
                .padding()
            
            Button("OK") {
                dismiss()
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
        .navigationTitle("Birthdate")
    }
}



import SwiftUI
import MapKit

struct LocationPickerView: View {
    @Binding var selectedLocation: String
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194), // Default to San Francisco
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var cityName: String = "Loading..."
    @Environment(\.dismiss) var dismiss
    @State private var lastCenter: CLLocationCoordinate2D? = nil

    var body: some View {
        VStack(spacing: 20) {
            // Map with interaction
            Map(coordinateRegion: $region, interactionModes: .all)
                .frame(height: 300)
                .cornerRadius(10)
                .overlay(
                    // Pin at the center
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundColor(.red)
                        .offset(y: -10)
                )
                .onAppear {
                    // Fetch city name for the initial region
                    fetchCityName(from: region.center)
                }

            // Trigger geocoding manually with a button
            Button("Update City Name") {
                fetchCityName(from: region.center)
            }
            .padding()
            .background(Color.green)
            .foregroundColor(.white)
            .cornerRadius(10)

            // Display the fetched city name
            VStack(alignment: .leading, spacing: 10) {
                Text("City Name:")
                    .font(.headline)
                Text(cityName)
                    .foregroundColor(.gray)
                    .padding()
                    .background(Color(UIColor.systemGroupedBackground))
                    .cornerRadius(10)
            }
            
            // Buttons for saving location
            HStack(spacing: 20) {
                Button("Select Location") {
                    // Combine city name and coordinates to set the selected location
                    selectedLocation = "\(cityName)"
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)

                Button("Cancel") {
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding()
        .navigationTitle("Pick Location")
    }
    
    // Function to fetch the city name using Nominatim API
    private func fetchCityName(from coordinate: CLLocationCoordinate2D) {
        guard !coordinatesAreEqual(coordinate, lastCenter) else { return } // Avoid redundant calls
        lastCenter = coordinate
        
        let url = URL(string: "https://nominatim.openstreetmap.org/reverse?lat=\(coordinate.latitude)&lon=\(coordinate.longitude)&format=json&addressdetails=1")!
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("Failed to fetch city name: \(error)")
                return
            }
            guard let data = data else { return }
            
            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let address = jsonResponse["address"] as? [String: Any],
                   let city = address["city"] as? String {
                    DispatchQueue.main.async {
                        self.cityName = city
                    }
                } else {
                    DispatchQueue.main.async {
                        self.cityName = "Unknown Location"
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.cityName = "Error fetching city"
                }
            }
        }.resume()
    }
    
    // Helper function to compare two coordinates
    private func coordinatesAreEqual(_ lhs: CLLocationCoordinate2D, _ rhs: CLLocationCoordinate2D?) -> Bool {
        guard let rhs = rhs else { return false }
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
