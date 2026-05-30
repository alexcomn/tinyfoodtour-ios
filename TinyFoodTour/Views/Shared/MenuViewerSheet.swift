import SwiftUI

// MARK: - Data types (mirrors MenuViewer.tsx)
struct MenuItemData: Codable {
    let name: String
    let price: String?
    let description: String?
}

struct MenuSection: Codable {
    let title: String
    let items: [MenuItemData]
}

struct MenuData: Codable {
    let sections: [MenuSection]
    let note: String?
    let error: String?
}

// MARK: - View model
@MainActor
final class MenuViewModel: ObservableObject {
    @Published var menuData: MenuData?
    @Published var isLoading = false
    @Published var error: String?
    @Published var collapsedSections: Set<Int> = []

    func load(url: String, restaurantName: String) async {
        isLoading = true
        error = nil
        menuData = nil
        collapsedSections = []
        do {
            let data: MenuData = try await SupabaseService.shared.invokeFunction(
                name: "fetch-menu",
                body: ["url": url, "restaurant_name": restaurantName]
            )
            if let err = data.error {
                error = err
            } else if data.sections.isEmpty {
                error = data.note ?? "No menu items found on this website."
            } else {
                menuData = data
            }
        } catch {
            self.error = "Couldn't load the menu. Try viewing the website directly."
        }
        isLoading = false
    }

    func toggleSection(_ index: Int) {
        if collapsedSections.contains(index) {
            collapsedSections.remove(index)
        } else {
            collapsedSections.insert(index)
        }
    }

    func collapseAll(count: Int) { collapsedSections = Set(0..<count) }
    func expandAll() { collapsedSections = [] }
    var allCollapsed: Bool { menuData.map { collapsedSections.count == $0.sections.count } ?? false }
}

// MARK: - Sheet view (mirrors MenuViewer.tsx)
struct MenuViewerSheet: View {
    let url: String
    let restaurantName: String

    @StateObject private var vm = MenuViewModel()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    loadingView
                } else if let err = vm.error {
                    errorView(err)
                } else if let data = vm.menuData {
                    menuContent(data)
                }
            }
            .navigationTitle(restaurantName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if let url = URL(string: url) {
                        Link(destination: url) {
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(Color("SlateMid"))
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color("SlateMid"))
                    }
                }
                // Collapse/expand all when multiple sections
                if let data = vm.menuData, data.sections.count > 1 {
                    ToolbarItem(placement: .bottomBar) {
                        Button(vm.allCollapsed ? "Expand all" : "Collapse all") {
                            if vm.allCollapsed { vm.expandAll() }
                            else { vm.collapseAll(count: data.sections.count) }
                        }
                        .font(.system(size: 13))
                        .foregroundColor(Color("SlateMid"))
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task { await vm.load(url: url, restaurantName: restaurantName) }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().tint(Color("Radish"))
            Text("Standby, we're loading a peek at the menu for you.")
                .font(.system(size: 14))
                .foregroundColor(Color("SlateMid"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(Color("SlateMid"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            if let url = URL(string: url) {
                Link(destination: url) {
                    Label("Open website", systemImage: "arrow.up.right.square")
                        .font(.system(size: 14))
                        .foregroundColor(Color("Primary"))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func menuContent(_ data: MenuData) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if let note = data.note {
                    Text(note)
                        .font(.system(size: 11))
                        .italic()
                        .foregroundColor(Color("SlateMid"))
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                ForEach(Array(data.sections.enumerated()), id: \.offset) { idx, section in
                    SectionBlock(
                        section: section,
                        index: idx,
                        isCollapsed: vm.collapsedSections.contains(idx),
                        hasMultiple: data.sections.count > 1,
                        onToggle: { vm.toggleSection(idx) }
                    )
                }

                // Footer link
                if let url = URL(string: url) {
                    Divider()
                    Link(destination: url) {
                        Label("View full website", systemImage: "arrow.up.right.square")
                            .font(.system(size: 11))
                            .foregroundColor(Color("SlateMid"))
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 16)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
    }
}

// MARK: - Section block
private struct SectionBlock: View {
    let section: MenuSection
    let index: Int
    let isCollapsed: Bool
    let hasMultiple: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header
            Button(action: hasMultiple ? onToggle : {}) {
                HStack {
                    Text(section.title.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.5)
                        .foregroundColor(Color("Primary"))

                    Spacer()

                    if hasMultiple {
                        HStack(spacing: 4) {
                            Text("\(section.items.count)")
                                .font(.system(size: 10))
                                .foregroundColor(Color("SlateMid"))
                            Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                                .font(.system(size: 11))
                                .foregroundColor(Color("SlateMid"))
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()

            // Items
            if !isCollapsed {
                ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                    MenuItemRow(item: item)
                }
            }
        }
    }
}

// MARK: - Menu item row
private struct MenuItemRow: View {
    let item: MenuItemData

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color("Foreground"))
                if let desc = item.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 11))
                        .foregroundColor(Color("SlateMid"))
                        .lineSpacing(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let price = item.price, !price.isEmpty {
                Text(price)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color("TFTSlate"))
                    .fixedSize()
            }
        }
        .padding(.bottom, 6)
    }
}
