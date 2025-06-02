//
//  AppleSignInView.swift
//  Pulto
//
//  Created by Joshua Herman on 5/27/25.
//  Copyright © 2025 Apple. All rights reserved.
//



import SwiftUI
import AuthenticationServices

struct AppleSignInView: View {
    @State private var isSignedIn = false
    @State private var userID = ""
    @State private var userName = ""
    @State private var userEmail = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "applelogo")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue.gradient)
                    
                    Text("Sign In")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                
                if !isSignedIn {
                    // Built-in Sign in with Apple Button
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handleSignInResult(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(width: 280, height: 50)
                    .cornerRadius(8)
                } else {
                    // User signed in successfully
                    VStack(spacing: 20) {
                        Text("Welcome!")
                            .font(.title)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            if !userName.isEmpty {
                                Text("Name: \(userName)")
                            }
                            if !userEmail.isEmpty {
                                Text("Email: \(userEmail)")
                            }
                            Text("User ID: \(String(userID.prefix(20)))...")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        
                        Button("Sign Out") {
                            signOut()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(40)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.regularMaterial)
        }
    }
    
    private func handleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                userID = appleIDCredential.user
                
                if let fullName = appleIDCredential.fullName {
                    let firstName = fullName.givenName ?? ""
                    let lastName = fullName.familyName ?? ""
                    userName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
                }
                
                if let email = appleIDCredential.email {
                    userEmail = email
                }
                
                isSignedIn = true
                
                print("Successfully signed in with Apple ID")
                print("User ID: \(userID)")
                print("Name: \(userName)")
                print("Email: \(userEmail)")
            }
            
        case .failure(let error):
            print("Sign in with Apple failed: \(error.localizedDescription)")
        }
    }
    
    private func signOut() {
        userID = ""
        userName = ""
        userEmail = ""
        isSignedIn = false
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        AppleSignInView()
    }
}
