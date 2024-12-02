//
//  Tutorial.swift
//  Synx
//
//  Created by YiYang Peng on 11/23/24.
//
import SwiftUI
import SDWebImageSwiftUI
import Firebase

class TutorialManager: ObservableObject {
    @Published var showTutorial: Bool = !UserDefaults.standard.bool(forKey: "HasSeenTutorial")
    @Published var messages: [String] = []
    
    private var tutorialScript: [String] = [
        "I’m LumiBot; your guide to exploring Aurora!",
        "I am going to teach you how Aurora works by pretending to be your friend. Let’s start with sending a real-time message to me. Type anything in your chat box.",
        "On Aurora, your friends will get a 'typing' notification whenever you type. So they get to see what you’re typing in real-time and respond in real-time.",
        "If you ever want to save a message, like a funny quote from a friend or something important you typed, hit the save button, and it’ll be stored in your chat history for easy access later.",
        "Heads up, though—your friend will get notified when you save their message. It’s like saying, 'This was too good not to keep!'",
        "Need a fresh start? Tap the clear button to wipe your chatbox clean. Warning: If the message isn’t saved, it’s gone forever. Poof.",
        "And that’s the basics! Grab some friends and enjoy Aurora together!"
    ]
}

struct TutorialView: View {
    @AppStorage("SeenTutorial") private var SeenTutorial: Bool = false
    @State private var navigateToMainMessageView = false
    @State private var tutorialtext = ""
    @State private var bottext = ""
    @FocusState private var isInputFocused: Bool
    @State private var activeTimers: [Timer] = []
    
    var body: some View {
        NavigationStack {
            ZStack{
                Image("chatlogviewbackground")
                    .resizable()
                    .ignoresSafeArea(.all, edges: .all)
                VStack{
                    let topbarheight = UIScreen.main.bounds.height * 0.07
                    HStack{
                        Button(action: {
                            saveTutorialSeenStatus()
                            SeenTutorial = true
                            navigateToMainMessageView = true
                        }) {
                            Image("chatlogviewbackbutton")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .padding(.leading, 20)
                            //.padding(8)
                        }
                        
                        Spacer()
                        Image("auroratext")
                            .resizable()
                            .scaledToFill()
                            .frame(width: UIScreen.main.bounds.width * 0.1832, height: UIScreen.main.bounds.height * 0.0198)
                        //.padding(12)
                        
                        Spacer()
                        
                        Button(action: {
                            print("Three dots button tapped")
                        }) {
                            Image("chatlogviewthreedotsbutton")
                                .resizable()
                                .frame(width: 24, height: 24)
                                .padding(.trailing, 20)
                            //.padding(8)
                        }
                    }
                    //.background(Color.white)
                    .frame(height: topbarheight)
                    
                    let geoheight = UIScreen.main.bounds.height - topbarheight - UIScreen.main.bounds.height * 0.455 //不许动
                    GeometryReader { geometry in
                        let width = geometry.size.width * 0.895 // 90% of screen width
                        let height = width * 0.549
                        VStack(spacing: 16){
                            ZStack {
                                // Background Image
                                Image("chatlogviewwhitebox")
                                    .resizable()
                                    .frame(width: width, height: height)
                                
                                // Content
                                VStack(spacing: 12) { // 12 points of spacing between sections
                                    // HStack for Profile Photo
                                    HStack {
                                        Image("lumibotpfp")
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 42, height: 42)
                                            .clipShape(Circle())
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Lumi Bot")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(Color(red: 0.49, green: 0.52, blue: 0.75))
                                            Text("Active Now")
                                                .font(.system(size: 12))
                                                .foregroundColor(Color.gray)
                                        }
                                        .padding(.leading, 7)
                                        Spacer()
                                    }
                                    .padding(.leading, 20)
                                    .padding(.top, 20)
                                    
                                    // Scrollable Text Section
                                    GeometryReader { geometry in
                                        VStack {
                                            Spacer(minLength: 0)
                                            ScrollView {
                                                VStack {
                                                    Spacer(minLength: calculateDynamicSpacing(geometry: geometry, botText: bottext))
                                                    
                                                    Text(bottext)
                                                        .font(Font.system(size: 18))
                                                        .multilineTextAlignment(.center)
                                                        .foregroundColor(Color(red: 0.553, green: 0.525, blue: 0.525))
                                                        .frame(maxWidth: geometry.size.width - 40)
                                                        .padding(.horizontal, 20)
                                                }
                                            }
                                            
                                            Spacer(minLength: 0) // Bottom Spacer
                                        }
                                    }
                                    
                                    // HStack for Save Button
                                    HStack {
                                        Spacer()
                                        if #available(iOS 18.0, *) {
                                            // iOS 18.0 or newer: Only show the first frame of the Lottie file
                                            LottieAnimationViewContainer(filename: "Save Button", isInteractive: false)
                                                .frame(width: 24, height: 24)
                                                .padding(.trailing, 20)
                                                .padding(.bottom, 24)
                                        } else {
                                            // iOS versions below 18.0: Use full Lottie animation with interactivity
                                            LottieAnimationViewContainer(filename: "Save Button", isInteractive: true)
                                                .frame(width: 24, height: 24)
                                                .padding(.trailing, 20)
                                                .padding(.bottom, 24)
                                        }
                                    }
                                }
                            }
                            //.background(Color.blue) // ZStack background color
                            .frame(width: width, height: height)
                            
                            
                            ZStack {
                                // Background Image
                                Image("chatlogviewpurplebox")
                                    .resizable()
                                    .frame(width: width, height: height)
                                
                                // Top-left Seen/Unseen Button
                                VStack {
                                    HStack {
                                        Image("Seen")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 52, height: 19)
                                        Spacer()
                                    }
                                    .padding(.leading, 20)
                                    .padding(.top, 20)
                                    
                                    Spacer()
                                }
                                
                                // Centered Text Input
                                VStack {
                                    Spacer() // Push TextEditor down
                                    
                                    ScrollView {
                                        TextEditor(text: $tutorialtext)
                                            .font(Font.system(size: 18))
                                            .foregroundColor(Color(red: 0.553, green: 0.525, blue: 0.525))
                                            .focused($isInputFocused)
                                            .multilineTextAlignment(.center) // Center-align text inside TextEditor
                                            .background(Color.clear) // Transparent background
                                            .scrollContentBackground(.hidden) // Ensures scrollable area is transparent
                                            .frame(maxWidth: .infinity, minHeight: 50) // Flexible width and minimum height
                                            .padding(.horizontal, 20) // Add spacing from sides
                                    }
                                    .frame(height: 60) // Set the height of the ScrollView
                                    .padding(.top, 5)
                                    .padding(.horizontal, 20)
                                    
                                    Spacer() // Push TextEditor
                                }
                                .onAppear {
                                    isInputFocused = true // Auto-focus the TextEditor
                                }
                                
                                // Bottom Save and Clear Buttons
                                VStack {
                                    Spacer() // Push buttons to the bottom
                                    HStack(spacing: 16) { // 20-point spacing between buttons
                                        Spacer()
                                        
                                        if #available(iOS 18.0, *) {
                                            // iOS 18.0 or newer: Only show the first frame of the Lottie file
                                            LottieAnimationViewContainer(filename: "Save Button", isInteractive: false)
                                                .frame(width: 24, height: 24)
                                        } else {
                                            // iOS versions below 18.0: Use full Lottie animation with interactivity
                                            LottieAnimationViewContainer(filename: "Save Button", isInteractive: true)
                                                .frame(width: 24, height: 24)
                                            
                                        }
                                        
                                        
                                        Button(action: {
                                            tutorialtext = ""
                                        }) {
                                            if #available(iOS 18.0, *) {
                                                // iOS 18.0 or newer: Only show the first frame of the Lottie file
                                                LottieAnimationViewContainer(filename: "Clear Button", isInteractive: false)
                                                    .frame(width: 24, height: 24)
                                            } else {
                                                // iOS versions below 18.0: Use full Lottie animation with interactivity
                                                LottieAnimationViewContainer(filename: "Clear Button", isInteractive: true)
                                                    .frame(width: 24, height: 24)
                                            }
                                        }
                                    }
                                    .padding(.trailing, 20) // Align to the right
                                    .padding(.bottom, 24)  // Spacing from bottom edge
                                }
                            }
                            //.background(Color.blue)
                            .frame(width: width, height: height)
                            
                            
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    //.background(Color.blue)
                    .frame(height: geoheight)
                    
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            }
            .navigationBarBackButtonHidden(true) // Hide the default back button
            .fullScreenCover(isPresented: $navigateToMainMessageView) {
                CustomTabNavigationView()
            }
            .onAppear {
                animateText()
            }
            .onDisappear {
                invalidateTimers() // Invalidate timers when the view disappears
            }
            
        }
        
        
    }
    func calculateDynamicSpacing(geometry: GeometryProxy, botText: String) -> CGFloat {
        let maxWidth = geometry.size.width - 40
        let fontHeight = UIFont.systemFont(ofSize: 18).lineHeight
        let lineCount = botText.boundingRect(
            with: CGSize(width: maxWidth, height: .infinity),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: UIFont.systemFont(ofSize: 18)],
            context: nil
        ).height / fontHeight
        
        if lineCount <= 1 {
            return max((geometry.size.height - 20) / 2, 0)
        } else if lineCount == 2 {
            return max((geometry.size.height - 45) / 1.7, 0)
        } else {
            return 0 // For 3+ lines, no additional spacer
        }
    }
    
    private func saveTutorialSeenStatus() {
        guard let uid = FirebaseManager.shared.auth.currentUser?.uid else { return }
        
        // Save "seen_tutorial" to Firestore
        FirebaseManager.shared.firestore
            .collection("users")
            .document(uid)
            .setData(["seen_tutorial": true], merge: true) { error in
                if let error = error {
                    print("Failed to save tutorial seen status: \(error)")
                } else {
                    print("Tutorial seen status saved successfully.")
                }
            }
    }
    
    private func invalidateTimers() {
        for timer in activeTimers {
            timer.invalidate()
        }
        activeTimers.removeAll()
    }
    
    
    private func animateText() {
        let sentences = [
            "I’m LumiBot; your guide to exploring Aurora!",
            "I am going to teach you how Aurora works by pretending to be your friend.",
            "Let’s start with sending a real time message to me. Type anything in your chat box.",
            "On Aurora, your friends will get a “typing” notification whenever you type.",
            "If you ever want to save a message, hit the save button. You can access it later in chat histories.",
            "Heads up, your friend will get notified when you save their message.",
            "Need a fresh start? Tap the clear button to wipe your chatbox clean.",
            "Warning: If the message isn’t saved, it’s gone forever. Poof.",
            "And that’s that basics! Grab some friends and enjoy Aurora together!"
        ]
        var currentSentenceIndex = 0
        
        func typeSentence(_ sentence: String, completion: @escaping () -> Void) {
            var currentIndex = 0
            bottext = "" // Clear the text for the new sentence
            
            let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                if currentIndex < sentence.count {
                    let index = sentence.index(sentence.startIndex, offsetBy: currentIndex)
                    bottext.append(sentence[index])
                    currentIndex += 1
                } else {
                    timer.invalidate()
                    completion()
                }
            }
            activeTimers.append(timer) // Keep track of active timers
        }
        
        func showNextSentence() {
            if currentSentenceIndex < sentences.count {
                let currentSentence = sentences[currentSentenceIndex]
                typeSentence(currentSentence) {
                    // Delay 2 seconds before showing the next sentence
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        currentSentenceIndex += 1
                        showNextSentence()
                    }
                }
            }
        }
        
        showNextSentence()
    }
    
}

struct SlideInModifier: ViewModifier {
    var edge: Edge
    @State private var offsetValue: CGFloat = UIScreen.main.bounds.width

    func body(content: Content) -> some View {
        content
            .offset(x: edge == .leading ? -offsetValue : offsetValue)
            .onAppear {
                withAnimation(.easeInOut) {
                    offsetValue = 0
                }
            }
            .onDisappear {
                withAnimation(.easeInOut) {
                    offsetValue = edge == .leading ? -UIScreen.main.bounds.width : UIScreen.main.bounds.width
                }
            }
    }
}

struct SlideInFromLeftModifier: ViewModifier {
    @State private var offsetValue: CGFloat = -UIScreen.main.bounds.width // Start off-screen (left)

    func body(content: Content) -> some View {
        content
            .offset(x: offsetValue) // Apply initial offset
            .onAppear {
                withAnimation(.easeInOut) {
                    offsetValue = 0 // Animate to the center of the screen
                }
            }
            .onDisappear {
                withAnimation(.easeInOut) {
                    offsetValue = UIScreen.main.bounds.width // Slide out to the right
                }
            }
    }
}

#Preview{
    TutorialView()
}
