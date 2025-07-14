//
//  AppleSignInView.swift
//  Pulto
//
//  Enhanced Apple Sign In with user management and persistence
//

import SwiftUI
import AuthenticationServices
import CryptoKit

// MARK: - User Model
struct AppUser: Codable, Identifiable {
    let id: String  // Apple User ID
    var name: String
    var email: String
    var firstName: String
    var lastName: String
    var signInDate: Date
    var lastActiveDate: Date
    var preferences: UserPreferences
    
    init(appleIDCredential: ASAuthorizationAppleIDCredential) {
        self.id = appleIDCredential.user
        self.firstName = appleIDCredential.fullName?.givenName ?? ""
        self.lastName = appleIDCredential.fullName?.familyName ?? ""
        self.name = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        self.email = appleIDCredential.email ?? ""
        self.signInDate = Date()
        self.lastActiveDate = Date()
        self.preferences = UserPreferences()
    }
    
    var displayName: String {
        if !name.isEmpty {
            return name
        } else if !email.isEmpty {
            return email.components(separatedBy: "@").first ?? "User"
        } else {
            return "User"
        }
    }
}

struct UserPreferences: Codable {
    var enableNotifications: Bool = true
    var autoSaveWorkspaces: Bool = true
    var defaultWorkspaceCategory: String = "Custom"
    var preferredExportFormat: String = "Jupyter"
    var theme: String = "System"
}

// MARK: - Authentication Manager
class AuthenticationManager: NSObject, ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published var currentUser: AppUser?
    @Published var isSignedIn: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private let keychain = KeychainService()
    private let userDefaultsKey = "CurrentAppUser"
    
    override init() {
        super.init()
        checkExistingAuthentication()
    }
    
    func signInWithApple() {
        isLoading = true
        errorMessage = nil
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        // Generate nonce for security
        let nonce = randomNonceString()
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    func signOut() {
        currentUser = nil
        isSignedIn = false
        
        // Clear stored user data
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        keychain.deleteUserCredentials()
        
        print("✅ Successfully signed out")
    }
    
    private func checkExistingAuthentication() {
        // Check if user data exists in UserDefaults
        if let userData = UserDefaults.standard.data(forKey: userDefaultsKey),
           let user = try? JSONDecoder().decode(AppUser.self, from: userData) {
            
            // Verify the user still has valid Apple ID credentials
            let provider = ASAuthorizationAppleIDProvider()
            provider.getCredentialState(forUserID: user.id) { [weak self] credentialState, error in
                DispatchQueue.main.async {
                    switch credentialState {
                    case .authorized:
                        self?.currentUser = user
                        self?.isSignedIn = true
                        self?.updateLastActiveDate()
                        print("✅ User is still authorized")
                    case .revoked, .notFound:
                        self?.signOut()
                        print("⚠️ User authorization revoked or not found")
                    case .transferred:
                        self?.signOut()
                        print("⚠️ User authorization transferred")
                    @unknown default:
                        self?.signOut()
                        print("⚠️ Unknown authorization state")
                    }
                }
            }
        }
    }
    
    private func saveUser(_ user: AppUser) {
        currentUser = user
        isSignedIn = true
        
        // Save to UserDefaults
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: userDefaultsKey)
        }
        
        // Save credentials to Keychain
        keychain.saveUserCredentials(userID: user.id, email: user.email)
        
        print("✅ User saved successfully")
    }
    
    private func updateLastActiveDate() {
        guard var user = currentUser else { return }
        user.lastActiveDate = Date()
        saveUser(user)
    }
    
    // MARK: - Security Helpers
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: Array<Character> =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            return String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

// MARK: - ASAuthorizationControllerDelegate
extension AuthenticationManager: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        DispatchQueue.main.async {
            self.isLoading = false
            
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let user = AppUser(appleIDCredential: appleIDCredential)
                self.saveUser(user)
                
                print("✅ Successfully signed in with Apple ID")
                print("   User ID: \(user.id)")
                print("   Name: \(user.displayName)")
                print("   Email: \(user.email)")
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        DispatchQueue.main.async {
            self.isLoading = false
            
            if let authError = error as? ASAuthorizationError {
                switch authError.code {
                case .canceled:
                    self.errorMessage = "Sign in was canceled"
                case .failed:
                    self.errorMessage = "Sign in failed. Please try again."
                case .invalidResponse:
                    self.errorMessage = "Invalid response from Apple"
                case .notHandled:
                    self.errorMessage = "Sign in could not be handled"
                case .unknown:
                    self.errorMessage = "An unknown error occurred"
                @unknown default:
                    self.errorMessage = "An unexpected error occurred"
                }
            } else {
                self.errorMessage = error.localizedDescription
            }
            
            print("❌ Apple Sign In failed: \(self.errorMessage ?? "Unknown error")")
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding
extension AuthenticationManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // For visionOS, we need to return the current window
        #if os(visionOS)
        return ASPresentationAnchor()
        #else
        return UIApplication.shared.windows.first { $0.isKeyWindow } ?? UIWindow()
        #endif
    }
}

// MARK: - Keychain Service
class KeychainService {
    private let service = "com.pulto.app"
    
    func saveUserCredentials(userID: String, email: String) {
        let credentials = [
            "userID": userID,
            "email": email
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: credentials) {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: "user_credentials",
                kSecValueData as String: data
            ]
            
            // Delete existing item
            SecItemDelete(query as CFDictionary)
            
            // Add new item
            SecItemAdd(query as CFDictionary, nil)
        }
    }
    
    func deleteUserCredentials() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "user_credentials"
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Enhanced Apple Sign In View
struct AppleSignInView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var showingUserProfile = false
    @State private var showingErrorAlert = false
    @State private var animateWelcome = false
    @State private var animateFeatures = false
    @Environment(\.dismiss) private var dismiss
    
    let isPresented: Binding<Bool>?
    
    init() {
        self.isPresented = nil
    }
    
    init(isPresented: Binding<Bool>) {
        self.isPresented = isPresented
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if authManager.isSignedIn, let user = authManager.currentUser {
                    authenticatedView(user: user)
                } else {
                    signInView
                }
            }
            .background(.regularMaterial)
            .navigationTitle("Apple Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        if let isPresented = isPresented {
                            isPresented.wrappedValue = false
                        } else {
                            dismiss()
                        }
                    }
                }
            }
            .alert("Sign In Error", isPresented: $showingErrorAlert) {
                Button("OK") {
                    authManager.errorMessage = nil
                }
            } message: {
                Text(authManager.errorMessage ?? "Unknown error occurred")
            }
            .onChange(of: authManager.errorMessage) { _, errorMessage in
                showingErrorAlert = errorMessage != nil
            }
            .onChange(of: authManager.isSignedIn) { _, isSignedIn in
                if isSignedIn {
                    // Auto-dismiss after a short delay to show success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        if let isPresented = isPresented {
                            isPresented.wrappedValue = false
                        } else {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Sign In View
    private var signInView: some View {
        VStack(spacing: 30) {
            // Header Section
            VStack(spacing: 20) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue.gradient)
                    .scaleEffect(animateWelcome ? 1.0 : 0.8)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateWelcome)
                
                VStack(spacing: 8) {
                    Text("Welcome to Pulto")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Sign in to sync your workspaces and access advanced features")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .opacity(animateWelcome ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.8).delay(0.2), value: animateWelcome)
            }
            
            // Features Section
            VStack(spacing: 12) {
                FeatureRow(icon: "icloud.fill", title: "Cloud Sync", description: "Sync workspaces across devices")
                FeatureRow(icon: "shield.fill", title: "Secure Storage", description: "Your data is encrypted and private")
                FeatureRow(icon: "person.2.fill", title: "Collaboration", description: "Share workspaces with team members")
            }
            .padding(.horizontal)
            .opacity(animateFeatures ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.8).delay(0.4), value: animateFeatures)
            
            // Sign In Button
            VStack(spacing: 16) {
                if authManager.isLoading {
                    HStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Signing in...")
                            .font(.headline)
                    }
                    .frame(width: 250, height: 44)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { _ in
                        // Handled by AuthenticationManager
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(width: 250, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onTapGesture {
                        authManager.signInWithApple()
                    }
                }
                
                Text("Secure sign in with your Apple ID")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .opacity(animateFeatures ? 1.0 : 0.0)
            .animation(.easeInOut(duration: 0.8).delay(0.6), value: animateFeatures)
            
            Spacer()
        }
        .padding(30)
        .onAppear {
            animateWelcome = true
            animateFeatures = true
        }
    }
    
    // MARK: - Authenticated View
    private func authenticatedView(user: AppUser) -> some View {
        VStack(spacing: 20) {
            // Success Header
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.green.gradient)
                
                VStack(spacing: 4) {
                    Text("Welcome back!")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(user.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text("Successfully signed in")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            // User Stats
            VStack(spacing: 12) {
                HStack(spacing: 15) {
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                        
                        Text("Active")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text("Account")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                    
                    VStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.title3)
                            .foregroundStyle(.blue)
                        
                        Text(formatDate(user.signInDate))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text("Member Since")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                }

                if !user.email.isEmpty {
                    UserInfoCard(title: "Email", value: user.email, icon: "envelope.fill")
                }
            }
            
            // Action Buttons
            VStack(spacing: 10) {
                Button("View Profile") {
                    showingUserProfile = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                
                Button("Sign Out") {
                    authManager.signOut()
                }
                .buttonStyle(.bordered)
                .foregroundStyle(.red)
                .controlSize(.regular)
            }
            
            Spacer()
        }
        .padding(30)
        .sheet(isPresented: $showingUserProfile) {
            UserProfileView(user: user)
                .frame(width: 600, height: 700)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    init(icon: String, title: String, description: String) {
        self.icon = icon
        self.title = title
        self.description = description
    }
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

extension FeatureRow {
    init(icon: String, title: String, value: String) {
        self.icon = icon
        self.title = title
        self.description = value
    }
}

struct UserInfoCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(value)
                    .font(.body)
                    .fontWeight(.medium)
            }
            
            Spacer()
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - User Profile View
struct UserProfileView: View {
    let user: AppUser
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthenticationManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile Header
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.blue.gradient)
                        
                        VStack(spacing: 4) {
                            Text(user.displayName)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            if !user.email.isEmpty {
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    // User Details
                    VStack(spacing: 12) {
                        ProfileDetailRow(title: "User ID", value: user.id)
                        ProfileDetailRow(title: "First Name", value: user.firstName.isEmpty ? "Not provided" : user.firstName)
                        ProfileDetailRow(title: "Last Name", value: user.lastName.isEmpty ? "Not provided" : user.lastName)
                        ProfileDetailRow(title: "Sign In Date", value: formatFullDate(user.signInDate))
                        ProfileDetailRow(title: "Last Active", value: formatFullDate(user.lastActiveDate))
                    }
                    
                    // Preferences Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Preferences")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 8) {
                            PreferenceRow(isEnabled: user.preferences.enableNotifications, value: nil, label: "Notifications", icon: "bell.fill")
                            PreferenceRow(isEnabled: user.preferences.autoSaveWorkspaces, value: nil, label: "Auto-save Workspaces", icon: "square.and.arrow.down")
                            PreferenceRow(isEnabled: nil, value: user.preferences.defaultWorkspaceCategory, label: "Default Category", icon: "folder")
                            PreferenceRow(isEnabled: nil, value: user.preferences.preferredExportFormat, label: "Export Format", icon: "square.and.arrow.up")
                            PreferenceRow(isEnabled: nil, value: user.preferences.theme, label: "Theme", icon: "paintbrush")
                        }
                    }
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        Button("Sign Out") {
                            authManager.signOut()
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .foregroundStyle(.white)
                        .background(.red)
                    }
                    .padding(.top)
                }
                .padding()
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func formatFullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ProfileDetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct PreferenceRow: View {
    var isEnabled: Bool?
    var value: String?
    let label: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.blue)
                .frame(width: 20)
            
            Text(label)
                .font(.subheadline)
            
            Spacer()
            
            if let isEnabled = isEnabled {
                Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(isEnabled ? .green : .red)
            } else if let value = value {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

// 
//  AppleSignInView.swift
//  Pulto
//
//  Created by Joshua Herman on 5/28/23.
//  Copyright (c) 2023 Apple. All rights reserved.

// Preview
struct AppleSignInView_Previews: PreviewProvider {
    static var previews: some View {
        AppleSignInView()
    }
}
