//
//  WorkspaceDialog.swift
//  Pulto
//
//  Workspace creation dialog
//

import SwiftUI

struct WorkspaceDialog: View {
    @Binding var isPresented: Bool
    @State private var workspaceName = ""
    @State private var workspaceDescription = ""
    @State private var selectedCategory: WorkspaceCategory = .custom
    @State private var isTemplate = false
    @State private var workspaceTags: [String] = []
    @State private var newTag = ""
    
    let onSave: (String, String, WorkspaceCategory, Bool, [String]) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section("Workspace Details") {
                    TextField("Name", text: $workspaceName)
                    TextField("Description", text: $workspaceDescription, axis: .vertical)
                        .lineLimit(3...6)
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(WorkspaceCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.iconName)
                                Text(category.displayName)
                            }
                            .tag(category)
                        }
                    }
                    
                    Toggle("Save as Template", isOn: $isTemplate)
                }
                
                Section("Tags") {
                    HStack {
                        TextField("Add tag", text: $newTag)
                            .onSubmit {
                                addTag()
                            }
                        
                        Button("Add") {
                            addTag()
                        }
                        .disabled(newTag.isEmpty)
                    }
                    
                    if !workspaceTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(workspaceTags, id: \.self) { tag in
                                    HStack {
                                        Text(tag)
                                        Button(action: {
                                            removeTag(tag)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(15)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Workspace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(workspaceName, workspaceDescription, selectedCategory, isTemplate, workspaceTags)
                        isPresented = false
                    }
                    .disabled(workspaceName.isEmpty)
                }
            }
        }
    }
    
    private func addTag() {
        guard !newTag.isEmpty else { return }
        if !workspaceTags.contains(newTag) {
            workspaceTags.append(newTag)
        }
        newTag = ""
    }
    
    private func removeTag(_ tag: String) {
        workspaceTags.removeAll { $0 == tag }
    }
}

#Preview {
    WorkspaceDialog(isPresented: .constant(true), onSave: { _, _, _, _, _ in })
}