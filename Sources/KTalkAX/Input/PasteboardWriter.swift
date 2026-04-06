import AppKit
import Foundation

struct PasteboardSnapshot {
    let items: [[String: Data]]
}

enum PasteboardWriter {
    static func backup() -> PasteboardSnapshot {
        let items = NSPasteboard.general.pasteboardItems?.map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in
                item.data(forType: type).map { (type.rawValue, $0) }
            })
        } ?? []
        return PasteboardSnapshot(items: items)
    }

    static func write(string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    static func restore(_ snapshot: PasteboardSnapshot) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        for itemMap in snapshot.items {
            let item = NSPasteboardItem()
            for (type, data) in itemMap {
                item.setData(data, forType: NSPasteboard.PasteboardType(type))
            }
            pasteboard.writeObjects([item])
        }
    }
}
