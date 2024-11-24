import SwiftUI
import Firebase
import FirebaseAuth

struct SetUsernameView: View {
    @Binding var haveUserName: Bool
    @State private var username: String = ""
    @State private var errorMessage: String = ""
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(spacing: 20) {
            Text("设置用户名")
                .font(.largeTitle)
                .bold()

            TextField("请输入用户名", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            Button(action: {
                saveUsername()
            }) {
                Text("确认")
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(8)
                    .padding(.horizontal)
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
        }
        .padding()
    }

    func saveUsername() {
        guard !username.isEmpty else {
            errorMessage = "用户名不能为空"
            return
        }
        // 将用户名保存到 Firebase
        if let uid = FirebaseManager.shared.auth.currentUser?.uid {
            let userRef = FirebaseManager.shared.firestore.collection("users").document(uid)
            userRef.updateData(["username": username]) { error in
                if let error = error {
                    errorMessage = "保存用户名失败: \(error.localizedDescription)"
                } else {
                    haveUserName = true
                }
            }
            saveUsernameToBasicInfo()
        }
    }
    func saveUsernameToBasicInfo(){
        // 将用户名保存到 Firebase
        if let uid = FirebaseManager.shared.auth.currentUser?.uid {
            let userRef = FirebaseManager.shared.firestore.collection("basic_information").document(uid).collection("information").document("profile")
            userRef.updateData(["username": username]) { error in
                if let error = error {
                    errorMessage = "保存用户名失败: \(error.localizedDescription)"
                } else {
                    print("Saving username correctly")
                }
            }
        }
    }
}
