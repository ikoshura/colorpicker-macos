//
//  ColorsbookView.swift
//  Colorpicker
//
//  Native counterpart of views/colorsbook.html + js/colorsbook.js:
//  categories on the left, saved colors on the right, add/delete via
//  popups and context menus.
//

import AppKit
import SwiftUI

struct ColorsbookView: View {
    @ObservedObject private var state = AppState.shared

    @State private var selectedCategory: String?
    @State private var showAddCategory = false
    @State private var newCategoryName = ""
    @State private var showAddColor = false
    @State private var newColorHex = ""

    private var currentCategory: AppState.Category? {
        state.categories.first { $0.id == selectedCategory } ?? state.categories.first
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            colorGrid
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 360, minHeight: 285)
        .onAppear {
            if selectedCategory == nil {
                selectedCategory = state.categories.first?.id
            }
        }
    }

    // MARK: - Sidebar (categories)

    /// Native sidebar backed by an `NSSplitViewController`: the divider
    /// always spans the full window height and the column keeps the system
    /// vibrancy / Liquid Glass treatment.
    ///
    /// The `+` button is drawn as an overlay instead of a `safeAreaInset`:
    /// an inset would make the sidebar's material start below the title bar
    /// safe area, cutting the translucency off halfway down the column.
    private var sidebar: some View {
        List(selection: $selectedCategory) {
            ForEach(state.categories) { category in
                categoryRow(category)
                    .tag(category.id)
            }
        }
        .listStyle(.sidebar)
        .contentMargins(.bottom, 34, for: .scrollContent)
        .overlay(alignment: .bottom) {
            VStack(spacing: 0) {
                Divider()
                HStack {
                    Spacer()
                    Button {
                        showAddCategory.toggle()
                        showAddColor = false
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 22, height: 22)
                    }
                    .buttonStyle(.plain)
                    .help("New category")
                    .popover(isPresented: $showAddCategory, arrowEdge: .bottom) {
                        addCategoryForm
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
            }
        }
        .navigationSplitViewColumnWidth(min: 120, ideal: 140, max: 200)
    }

    private func categoryRow(_ category: AppState.Category) -> some View {
        let background = category.colors.first.map { Color(hex: $0) }
            ?? Color(nsColor: .windowBackgroundColor)
        let textColor: Color = ColorTools.isDark(
            ColorTools.rgb(fromHex: category.colors.first ?? "#FFFFFF"))
            ? .white : .black

        return HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(background)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.black.opacity(0.2), lineWidth: 1))
                .frame(width: 14, height: 14)
                .shadow(color: textColor.opacity(0.6), radius: 0.5)

            Text(category.id)
                .font(.system(size: 13))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Delete") { state.deleteCategory(name: category.id) }
        }
    }

    private var addCategoryForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("New category")
                .font(.headline)
            TextField("name", text: $newCategoryName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)
                .onSubmit { commitAddCategory() }
            HStack {
                Spacer()
                Button("Cancel") {
                    newCategoryName = ""
                    showAddCategory = false
                }
                Button("Add") { commitAddCategory() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(12)
    }

    private func commitAddCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            showAddCategory = false
            return
        }
        state.addCategory(name: name)
        selectedCategory = name
        newCategoryName = ""
        showAddCategory = false
    }

    // MARK: - Color grid

    private var colorGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 24), spacing: 6)],
                spacing: 6) {
                ForEach(currentCategory?.colors ?? [], id: \.self) { hex in
                    swatch(hex)
                }
                addButton
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottomTrailing) { addColorPopup }
    }

    private func swatch(_ hex: String) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color(hex: hex))
            .frame(width: 24, height: 24)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Color.black.opacity(0.15), lineWidth: 1))
            .contentShape(Rectangle())
            // Like the original: a click previews the color in the main window.
            .onTapGesture { state.setColor(hex: hex, persist: false) }
            .contextMenu {
                Button("Delete") {
                    if let category = currentCategory {
                        state.deleteColor(category: category.id, hex: hex)
                    }
                }
            }
            .help(hex)
    }

    private var addButton: some View {
        Button {
            showAddColor.toggle()
            showAddCategory = false
        } label: {
            Image(systemName: "plus")
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .help("Add color")
    }

    private var addColorPopup: some View {
        Group {
            if showAddColor {
                HStack(spacing: 4) {
                    TextField("#FFFFFF", text: $newColorHex)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 96)
                        .onSubmit { commitAddColor() }
                    Button("Add") { commitAddColor() }
                }
                .padding(6)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(10)
            }
        }
    }

    private func commitAddColor() {
        let pattern = "^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                  in: newColorHex, range: NSRange(newColorHex.startIndex..., in: newColorHex)),
              let range = Range(match.range(at: 1), in: newColorHex) else {
            return
        }
        if let category = currentCategory {
            state.addColor(category: category.id, hex: "#" + String(newColorHex[range]))
        }
        newColorHex = ""
        showAddColor = false
    }

}
