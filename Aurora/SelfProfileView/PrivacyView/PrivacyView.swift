//
//  PrivacyView.swift
//  Synx
//
//  Created by Shawn on 12/4/24.
//

import SwiftUI

struct PrivacyView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    // Header Section
                    VStack(alignment: .center, spacing: 10) {
                        Text("Privacy Policy")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        
                        Text("Your Privacy, Our Priority")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Divider()
                            .background(Color.blue)
                    }
                    .padding(.top, 20)
                    
                    // Section: Introduction
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Introduction")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        
                        Text("""
                        Welcome to **Your Social App**! At our core, we are committed to protecting your personal information and your right to privacy. This Privacy Policy explains how we collect, use, and protect your data when you use our app.
                        
                        Whether you're here to connect, share, or simply explore, your privacy matters to us.
                        """)
                    }
                    
                    // Section: Account Privacy
                    VStack(alignment: .leading, spacing: 10) {
                        Text("1. Account Privacy")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        
                        Text("""
                        Your Social App provides two privacy settings for accounts:
                        
                        - **Public Accounts**: Anyone can follow you and view your profile, posts, and activity.
                        - **Private Accounts**: Only approved followers can access your content. This gives you control over who can see your personal updates.
                        
                        You can switch between these settings anytime in your profile settings.
                        """)
                        .foregroundColor(.gray)
                    }
                    
                    // Section: Data Security
                    VStack(alignment: .leading, spacing: 10) {
                        Text("2. Data Security")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        
                        Text("""
                        We prioritize the security of your data by:
                        
                        - Using **end-to-end encryption** for all your private messages.
                        - Storing your data securely with advanced encryption techniques.
                        - Conducting regular security audits to safeguard our systems against breaches.
                        
                        **Rest assured**, your data is never sold to third parties or used without your consent.
                        """)
                        .foregroundColor(.gray)
                    }
                    
                    // Section: Your Control
                    VStack(alignment: .leading, spacing: 10) {
                        Text("3. Your Control")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        
                        Text("""
                        Our app empowers you with full control over your interactions:
                        
                        - **Tagging and Mentions**: Control who can tag or mention you in posts.
                        - **Blocking**: Block specific users from interacting with you.
                        - **Story Visibility**: Hide your stories from select users.
                        
                        Take charge of your online presence with easy-to-use privacy controls.
                        """)
                        .foregroundColor(.gray)
                    }
                    
                    // Section: Cookies and Tracking
                    VStack(alignment: .leading, spacing: 10) {
                        Text("4. Cookies and Tracking")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        
                        Text("""
                        We use cookies to:
                        
                        - Enhance your experience by personalizing content.
                        - Analyze app usage to improve performance.
                        
                        You can manage or disable cookies anytime in your settings. Note that disabling cookies may affect certain functionalities.
                        """)
                        .foregroundColor(.gray)
                    }
                    
                    // Section: Contact Us
                    VStack(alignment: .leading, spacing: 10) {
                        Text("5. Contact Us")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        
                        Text("""
                        Questions or concerns about our Privacy Policy? Reach out to us at:
                        
                        **Email**: support@yourapp.com
                        **Phone**: +1-234-567-890
                        
                        We’re here to ensure your experience with our app is safe and enjoyable.
                        """)
                        .foregroundColor(.gray)
                    }
                    
                    // Footer Section
                    VStack(alignment: .center, spacing: 10) {
                        Divider()
                            .background(Color.blue)
                        
                        Text("Thank you for trusting Your Social App!")
                            .font(.headline)
                            .foregroundColor(.blue)
                        
                        Text("Updated on: December 5, 2024")
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 20)
            }
            .background(LinearGradient(gradient: Gradient(colors: [.white, .blue.opacity(0.1)]), startPoint: .top, endPoint: .bottom))
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(leading: Button("back") {
                dismiss()
            })
        }
    }
}
