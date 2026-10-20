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

    @State private var selectedCategory = ""
    @State private var showAddCategory = false
    @State private var newCategoryName = ""
    @State private var showAddColor = false
    @State private var newColorHex = ""

    private var currentCategory: AppState.Category? {
        state.categories.first { $0.id == selectedCategory } ?? state.categories.first
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            colorGrid
        }
        .frame(minWidth: 360, minHeight: 285)
        .onAppear {
            if selectedCategory.isEmpty {
                selectedCategory = state.categories.first?.id ?? ""
            }
        }
    }

    // MARK: - Sidebar (categories)

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(state.categories) { category in
                        categoryRow(category)
                    }
                }
                .padding(6)
            }
            Divider()
            Button {
                showAddCategory.toggle()
                showAddColor = false
            } label: {
                Image(systemName: "plus")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .help("New category")
        }
        .frame(width: 130)
        .background(Color(nsColor: .underPageBackgroundColor))
        .overlay(alignment: .bottomLeading) { addCategoryPopup }
    }

    private func categoryRow(_ category: AppState.Category) -> some View {
        let isActive = category.id == (currentCategory?.id ?? "")
        let background = category.colors.first.map { Color(hex: $0) }
            ?? Color(nsColor: .windowBackgroundColor)
        let textColor: Color = ColorTools.isDark(
            ColorTools.rgb(fromHex: category.colors.first ?? "#FFFFFF"))
            ? .white : .black

        return Button {
            selectedCategory = category.id
        } label: {
            Text(category.id)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(textColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(background)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(
                                    isActive ? Color.primary : .clear, lineWidth: 2)))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Delete") { state.deleteCategory(name: category.id) }
        }
    }

    private var addCategoryPopup: some View {
        Group {
            if showAddCategory {
                HStack(spacing: 4) {
                    TextField("name", text: $newCategoryName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 96)
                        .onSubmit {
                            state.addCategory(name: newCategoryName)
                            selectedCategory = newCategoryName
                            newCategoryName = ""
                            showAddCategory = false
                        }
                    Button("Add") {
                        state.addCategory(name: newCategoryName)
                        selectedCategory = newCategoryName
                        newCategoryName = ""
                        showAddCategory = false
                    }
                }
                .padding(6)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(6)
            }
        }
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
