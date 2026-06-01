import AppKit

struct PasteboardSnapshot {
    private let pasteboard: NSPasteboard
    private let items: [NSPasteboardItem]

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
        items = pasteboard.pasteboardItems?.compactMap { item in
            let copy = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    copy.setData(data, forType: type)
                }
            }
            return copy
        } ?? []
    }

    func restore() {
        pasteboard.clearContents()
        pasteboard.writeObjects(items)
    }
}
