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
        updateUsername()
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
            Form {
                Section(header: Text("Basic Information")) {
                    
                    NavigationLink(destination: DetailInputView(title: "Your name", value: $profileVM.name)) {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(profileVM.name.isEmpty ? "Enter name" : profileVM.name)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    NavigationLink(destination: DetailInputView(title: "Username", value: $profileVM.username)) {
                        HStack {
                            Text("Username")
                            Spacer()
                            Text(profileVM.username.isEmpty ? "Enter Username" : profileVM.username)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    NavigationLink(destination: DetailInputView(title: "Age", value: $profileVM.age)) {
                        HStack {
                            Text("Age")
                            Spacer()
                            Text(profileVM.age.isEmpty ? "Enter Age" : profileVM.age)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    NavigationLink(destination: DetailInputView(title: "Gender", value: $profileVM.gender)) {
                        HStack {
                            Text("Gender")
                            Spacer()
                            Text(profileVM.gender.isEmpty ? "Enter Gender" : profileVM.gender)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    NavigationLink(destination: DetailInputView(title: "Email", value: $profileVM.email)) {
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(profileVM.email.isEmpty ? "Enter Email" : profileVM.email)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    NavigationLink(destination: DetailInputView(title: "Bio", value: $profileVM.bio)) {
                        HStack {
                            Text("Bio")
                            Spacer()
                            Text(profileVM.bio.isEmpty ? "Enter Bio" : profileVM.bio)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    NavigationLink(destination: LocationPickerView(selectedLocation: $profileVM.location)) {
                        HStack {
                            Text("Location")
                            Spacer()
                            Text(profileVM.location.isEmpty ? "Select Location" : profileVM.location)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    NavigationLink(destination: BirthdatePickerView(selectedDate: $profileVM.birthdate)) {
                        HStack {
                            Text("Birthdate")
                            Spacer()
                            Text("\(profileVM.birthdate.formatted(.dateTime.year().month().day()))")
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Button("Save") {
                    profileVM.saveProfileInfo()
                    dismiss()
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .navigationTitle("Edit Profile")
        }
    }
}

// MARK: - Detail Input View
struct DetailInputView: View {
    let title: String
    @Binding var value: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            TextField("Enter \(title)", text: $value)
                .textFieldStyle(RoundedBorderTextFieldStyle())
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
        .navigationTitle(title)
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
