import SwiftUI
import SceneCore

/// V0.7 "Custom layout build" canvas editor — the visual counterpart to the
/// split-tree data model in `LayoutNode`. Users see a preview of their layout
/// and directly manipulate it: click any slot for a menu (split H / split V /
/// delete), drag the seam between two siblings to adjust the split ratio.
///
/// This is the second editor path in `LayoutDraftEditor`: when a draft's
/// `customTree` is non-nil we render this instead of the template-based
/// `LayoutEditorView`. The existing Save/Cancel flow (local `@State` draft,
/// explicit commit through `LayoutStore.update`, `.id(layout.id)` reset on
/// selection change) applies unchanged.
///
/// Design notes:
/// - The tree mutates through recursive `@Binding<LayoutNode>` pairs. Each
///   `LayoutNodeEditorView` owns a binding to its own subtree and publishes
///   child bindings to its children; setter closures rebuild the `.hSplit` /
///   `.vSplit` case on each mutation so SwiftUI sees a fresh value-type tree.
/// - "Delete this slot" on a leaf is carried out by the **parent**. Each split
///   passes its children an `onDelete` closure that, when invoked, replaces the
///   split itself with its surviving sibling. The root leaf gets `onDelete = nil`,
///   which disables the Delete menu item (there's nothing sensible to collapse
///   to — the root IS the whole canvas).
/// - Per V0.7 spec answers (Q1), no minimum slot size is enforced. Users can
///   drag a seam all the way to 0 or 1; the slot at the collapsed end becomes
///   zero-size but the tree stays valid and the user can merge/delete from the
///   menu. The seam handle has a 12pt hit area so it remains grabbable even
///   when the visible stripe is at an extreme position.
struct CustomLayoutCanvasEditor: View {
    @Binding var draft: CustomLayout
    /// Dirty-state flag supplied by the parent. When false, the Save button
    /// is disabled (darkened) so the user gets immediate feedback that they
    /// either have no pending changes or their last save already landed.
    let canSave: Bool
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("layouts.editor.name", text: $draft.name)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text(String(format: String(localized: "layouts.custom.slot_count"), currentTree.slotCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text("layouts.custom.canvas_hint")
                .font(.caption)
                .foregroundStyle(.secondary)

            canvas

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button("settings.action.cancel", action: onCancel)
                Button("settings.action.save", action: onSave)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .padding()
    }

    private var currentTree: LayoutNode {
        draft.customTree ?? .leaf
    }

    private var canvas: some View {
        GeometryReader { geo in
            LayoutNodeEditorView(node: treeBinding, onDelete: nil)
                .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(Color.black.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .frame(minHeight: 260)
    }

    /// Binding over `draft.customTree`. If the draft somehow arrives with a nil
    /// tree (shouldn't happen via `LayoutDraftEditor`'s routing, but defensive)
    /// we substitute `.leaf` so the canvas always has something to render.
    private var treeBinding: Binding<LayoutNode> {
        Binding(
            get: { draft.customTree ?? .leaf },
            set: { draft.customTree = $0 }
        )
    }
}

// MARK: - Recursive node editor

/// Renders one `LayoutNode` and recursively delegates to child views for
/// splits. Stateless — all mutation flows through `@Binding<LayoutNode>`.
private struct LayoutNodeEditorView: View {
    @Binding var node: LayoutNode
    /// Invoked when a descendant leaf requests self-deletion. The parent split
    /// provides this closure; the root caller passes `nil`, which turns the
    /// leaf's "Delete" menu item off (there's no parent to collapse to).
    let onDelete: (() -> Void)?

    var body: some View {
        switch node {
        case .leaf:
            LeafRectView(
                onSplitH: { node = .splitH() },
                onSplitV: { node = .splitV() },
                onDelete: onDelete
            )
        case .hSplit:
            hSplitView
        case .vSplit:
            vSplitView
        }
    }

    // MARK: - Split renderers

    @ViewBuilder
    private var hSplitView: some View {
        GeometryReader { geo in
            if case .hSplit(let ratio, let top, let bottom) = node {
                let r = clampedRatio(ratio)
                let topH = geo.size.height * CGFloat(r)
                ZStack(alignment: .topLeading) {
                    LayoutNodeEditorView(
                        node: firstChildBinding,
                        onDelete: { node = bottom }
                    )
                    .frame(width: geo.size.width, height: topH)

                    LayoutNodeEditorView(
                        node: secondChildBinding,
                        onDelete: { node = top }
                    )
                    .frame(width: geo.size.width, height: geo.size.height - topH)
                    .offset(x: 0, y: topH)

                    SeamHandleView(
                        orientation: .horizontal,
                        ratio: ratioBinding,
                        containerSize: geo.size
                    )
                    .frame(width: geo.size.width, height: 12)
                    .offset(x: 0, y: topH - 6)
                }
            }
        }
    }

    @ViewBuilder
    private var vSplitView: some View {
        GeometryReader { geo in
            if case .vSplit(let ratio, let left, let right) = node {
                let r = clampedRatio(ratio)
                let leftW = geo.size.width * CGFloat(r)
                ZStack(alignment: .topLeading) {
                    LayoutNodeEditorView(
                        node: firstChildBinding,
                        onDelete: { node = right }
                    )
                    .frame(width: leftW, height: geo.size.height)

                    LayoutNodeEditorView(
                        node: secondChildBinding,
                        onDelete: { node = left }
                    )
                    .frame(width: geo.size.width - leftW, height: geo.size.height)
                    .offset(x: leftW, y: 0)

                    SeamHandleView(
                        orientation: .vertical,
                        ratio: ratioBinding,
                        containerSize: geo.size
                    )
                    .frame(width: 12, height: geo.size.height)
                    .offset(x: leftW - 6, y: 0)
                }
            }
        }
    }

    private func clampedRatio(_ r: Double) -> Double {
        guard !r.isNaN else { return 0.5 }
        return min(max(r, 0), 1)
    }

    // MARK: - Child bindings

    /// Binding over the FIRST child (top for `.hSplit`, left for `.vSplit`).
    /// Getter returns `.leaf` for the `.leaf` case so the compiler is satisfied;
    /// in practice this view is never rendered for a `.leaf` node.
    private var firstChildBinding: Binding<LayoutNode> {
        Binding(
            get: {
                switch node {
                case .leaf:                         return .leaf
                case .hSplit(_, let top, _):        return top
                case .vSplit(_, let left, _):       return left
                }
            },
            set: { newValue in
                switch node {
                case .leaf:
                    break
                case .hSplit(let r, _, let b):
                    node = .hSplit(ratio: r, top: newValue, bottom: b)
                case .vSplit(let r, _, let rt):
                    node = .vSplit(ratio: r, left: newValue, right: rt)
                }
            }
        )
    }

    /// Binding over the SECOND child (bottom for `.hSplit`, right for `.vSplit`).
    private var secondChildBinding: Binding<LayoutNode> {
        Binding(
            get: {
                switch node {
                case .leaf:                         return .leaf
                case .hSplit(_, _, let bottom):     return bottom
                case .vSplit(_, _, let right):      return right
                }
            },
            set: { newValue in
                switch node {
                case .leaf:
                    break
                case .hSplit(let r, let t, _):
                    node = .hSplit(ratio: r, top: t, bottom: newValue)
                case .vSplit(let r, let l, _):
                    node = .vSplit(ratio: r, left: l, right: newValue)
                }
            }
        )
    }

    /// Binding over the split ratio. No-op setter for `.leaf` (never invoked
    /// by any renderer, but keeps the property pure).
    private var ratioBinding: Binding<Double> {
        Binding(
            get: {
                switch node {
                case .leaf:                              return 0.5
                case .hSplit(let ratio, _, _):           return ratio
                case .vSplit(let ratio, _, _):           return ratio
                }
            },
            set: { newRatio in
                switch node {
                case .leaf:
                    break
                case .hSplit(_, let t, let b):
                    node = .hSplit(ratio: newRatio, top: t, bottom: b)
                case .vSplit(_, let l, let r):
                    node = .vSplit(ratio: newRatio, left: l, right: r)
                }
            }
        )
    }
}

// MARK: - Leaf

private struct LeafRectView: View {
    let onSplitH: () -> Void
    let onSplitV: () -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        ZStack {
            // Square (non-rounded) fill that butts directly against sibling leaves.
            // Previous version wrapped the rect in `.padding(2)` which produced a
            // visible 2pt gap between every adjacent slot — users read that as an
            // "extra line" separate from the seam stripe. Removing the padding lets
            // neighbouring leaves share an edge; the seam handle (2pt accent stripe
            // rendered on top) becomes the only visual divider.
            Rectangle()
                .fill(Color.accentColor.opacity(0.18))

            Menu {
                Button("layouts.custom.split_horizontal", action: onSplitH)
                Button("layouts.custom.split_vertical", action: onSplitV)
                if let onDelete {
                    Divider()
                    Button("layouts.custom.delete_slot", role: .destructive, action: onDelete)
                }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, Color.accentColor)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("layouts.custom.leaf_menu_help")
        }
    }
}

// MARK: - Seam handle

private struct SeamHandleView: View {
    enum Orientation { case horizontal, vertical }
    let orientation: Orientation
    @Binding var ratio: Double
    let containerSize: CGSize

    /// Captured at the start of a drag so subsequent frames can apply a delta
    /// relative to the initial ratio. `onEnded` clears it. Using `@State`
    /// instead of `@GestureState` because `@GestureState` would reset
    /// mid-drag if the parent view re-renders (which it does, since our ratio
    /// binding mutates the tree on every drag frame).
    @State private var dragStartRatio: Double?

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .overlay(
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(
                        width: orientation == .vertical ? 2 : nil,
                        height: orientation == .horizontal ? 2 : nil
                    )
            )
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        if dragStartRatio == nil { dragStartRatio = ratio }
                        guard let start = dragStartRatio else { return }
                        let delta: CGFloat
                        let total: CGFloat
                        switch orientation {
                        case .horizontal:
                            delta = value.translation.height
                            total = containerSize.height
                        case .vertical:
                            delta = value.translation.width
                            total = containerSize.width
                        }
                        guard total > 0 else { return }
                        let next = start + Double(delta / total)
                        ratio = min(max(next, 0), 1)
                    }
                    .onEnded { _ in
                        dragStartRatio = nil
                    }
            )
            .onHover { inside in
                // Native resize cursor while hovering over the seam — a strong
                // visual signal that this edge is draggable.
                if inside {
                    switch orientation {
                    case .horizontal: NSCursor.resizeUpDown.push()
                    case .vertical:   NSCursor.resizeLeftRight.push()
                    }
                } else {
                    NSCursor.pop()
                }
            }
    }
}
