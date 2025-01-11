//
//  PrivacyPolicyView.swift
//  Aurora
//
//  Created by Shawn on 1/11/25.
//

import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // MARK: - BACKGROUND GRADIENT
                LinearGradient(
                    gradient: Gradient(colors: [Color.purple, Color.blue]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // MARK: - HEADER
                        VStack(spacing: 4) {
                            Text("Privacy Policy")
                                .font(.system(size: 28, weight: .bold, design: .serif))
                                .foregroundColor(.white)
                            
                            Text("Last Modified: 12/13/2024")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding(.top, 16)
                        
                        // MARK: - INTRODUCTION
                        FancyPrivacySectionView(
                            iconName: "lock.shield.fill",
                            sectionTitle: "Introduction",
                            content: """
Welcome to Aurora’s *fancified* Privacy Policy. We aim to clearly explain how we handle, protect, and utilize your personal data. By continuing to use Aurora, you acknowledge and accept these practices, empowering you with significant control over your own information.
"""
                        )
                        
                        // MARK: - CONTROL OVER YOUR INFORMATION
                        FancyPrivacySectionView(
                            iconName: "person.crop.circle.badge.checkmark",
                            sectionTitle: "Control Over Your Information",
                            content: """
**Access & Edits**  
Visit your in-app profile settings anytime to review or modify your account details.

**Deletion**  
Feel free to remove your account when you wish. Just follow the instructions under “Account Deletion” in our settings.

**Visibility**  
Our robust privacy controls let you decide who can view your content and personal details.

**Communication & Permissions**  
Manage contact options, block unwanted interactions, set device-level permissions, and unsubscribe from marketing messages whenever you like.

**Advertising Preferences**  
Tailor the ads you see through easy-to-use in-app settings.
"""
                        )
                        
                        // MARK: - INFORMATION WE COLLECT
                        FancyPrivacySectionView(
                            iconName: "tray.full.fill",
                            sectionTitle: "Information We Collect",
                            content: """
1. **User-Provisioned Data**  
   Name, email, phone number, profile details, media uploads, and any direct communications with our support. Payment info is stored when you engage with paid features.

2. **Usage-Generated Data**  
   We track usage stats, device attributes, and rely on technologies like cookies to enhance your Aurora experience.

3. **Third-Party Sources**  
   On occasion, we may receive info from partner platforms, advertisers, or other Aurora users—especially if it involves potential violations or relevant updates.
"""
                        )
                        
                        // MARK: - HOW YOUR INFO IS USED
                        FancyPrivacySectionView(
                            iconName: "gearshape.2.fill",
                            sectionTitle: "How Your Info Is Used",
                            content: """
- **Core Services**: We rely on your data to keep Aurora functional, secure, and user-friendly.
- **Personalization**: We refine your feed, suggestions, and interactions based on your content interests.
- **Service Enhancement**: We analyze trends, fix bugs, and test features, prioritizing rigorous security safeguards.
- **Communications**: Depending on your preferences, we may send essential service updates, promotional materials, or security alerts.

**We May Share With**  
- Other users, as your privacy settings allow  
- Vetted third-party providers assisting Aurora’s operations  
- Official authorities, if legally required  
- Potential successors in case of a merger or acquisition  

**We Don’t Share**  
- Private messages without consent  
- Sensitive personal data to advertisers  
- Any confidential details with unauthorized parties
"""
                        )
                        
                        // MARK: - DATA RETENTION POLICY
                        FancyPrivacySectionView(
                            iconName: "externaldrive.fill.badge.person.crop",
                            sectionTitle: "Data Retention Policy",
                            content: """
1. **User-Managed Content**  
   You control how long your posts or other data stay visible on Aurora. Deletion typically removes content from active servers within 24 hours. Optional auto-deletion timers are available.

2. **System Essentials**  
   Basic credentials and security logs may be retained as needed to safeguard Aurora’s stability and integrity.

3. **Legal Compliance**  
   We may store specific info for a limited time to fulfill legal, regulatory, or dispute-resolution obligations.

4. **Account Deletion**  
   Once requested, we aim to fully remove personal data within 15 days. Residual traces may persist in encrypted backups, but we follow rigorous processes to ensure thorough compliance with deletion requests.
"""
                        )
                        
                        // MARK: - POLICY UPDATES
                        FancyPrivacySectionView(
                            iconName: "arrow.triangle.2.circlepath.circle.fill",
                            sectionTitle: "Policy Updates",
                            content: """
**Major Changes**  
- Prominent in-app notices  
- Direct emails to registered users  
- Visual alerts on key Aurora pages

**Minor Revisions**  
- Updated “Last Modified” date in this document  
- Notices posted on relevant app sections or website banners  

We encourage periodic reviews of this Policy to stay informed about how we continue to protect and manage your data. Where possible, we provide early notice of big changes, letting you evaluate and adapt accordingly.
"""
                        )
                        
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .navigationBarTitle("Privacy Policy", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - FancyPrivacySectionView
/// Reusable stylized card for displaying sections of the Privacy Policy
struct FancyPrivacySectionView: View {
    let iconName: String
    let sectionTitle: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section Header
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.accentColor)
                Text(sectionTitle)
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundColor(.primary)
            }
            
            Divider()
                .background(Color.accentColor.opacity(0.7))
            
            // Section Content
            Text(content)
                .font(.system(size: 15))
                .foregroundColor(.primary)
                .lineSpacing(5)
        }
        .padding(16)
        .background(Color.white.opacity(0.9))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 4)
    }
}
