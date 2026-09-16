import Foundation

public func logError(_ message: String) {
    FileHandle.standardError.write(Data("shift-happens: \(message)\n".utf8))
}
