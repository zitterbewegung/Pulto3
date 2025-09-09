//
//  NotebookWindowView.swift
//  Pulto3
//
//  Created by Joshua Herman on 9/8/25.
//  Copyright © 2025 Apple. All rights reserved.
//


import SwiftUI

struct NotebookWindowView: View {
    let windowId: Int
    @ObservedObject var notebookManager: NotebookManager
    let generateNotebookJSON: () -> String
    @State private var bootstrapped = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Notebook").font(.title2).bold()
                Spacer()
                if let path = notebookManager.path(windowId: windowId) {
                    Text(path).font(.caption).foregroundStyle(.secondary)
                }
                Button {
                    Task { await notebookManager.runAll(windowId: windowId) }
                } label: {
                    Label("Run All", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.bottom, 6)

            Divider()

            List {
                let cells = notebookManager.cells(windowId: windowId)
                ForEach(Array(cells.enumerated()), id: \.element.id) { (idx, cell) in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("In [\(cell.execution_count ?? 0)]:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                Task { await notebookManager.runCell(windowId: windowId, index: idx) }
                            } label: { Image(systemName: "play.circle") }
                            .buttonStyle(.bordered)
                        }

                        ScrollView(.horizontal, showsIndicators: true) {
                            Text(cell.source.joined())
                                .monospaced()
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if !cell.outputs.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(cell.outputs) { out in
                                    switch out {
                                    case .stream(let t):            Text(t).monospaced()
                                    case .executeResult(let t):     Text(t).monospaced().fontWeight(.semibold)
                                    case .displayData(let t):       Text(t)
                                    case .error(let en, let ev):    Text("\(en): \(ev)").foregroundStyle(.red)
                                    }
                                }
                            }
                            .padding(8)
                            .background(Color.gray.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding()
        .task {
            guard !bootstrapped else { return }
            bootstrapped = true
            await notebookManager.bootstrap(
                windowId: windowId,
                notebookJSON: generateNotebookJSON(),
                suggestedPath: "Pulto/\(windowId).ipynb"
            )
        }
    }
}
