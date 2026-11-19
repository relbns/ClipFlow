import os

enum Log {
    private static let subsystem = "com.singalong.clipflow"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let expansion = Logger(subsystem: subsystem, category: "expansion")
    static let clipboard = Logger(subsystem: subsystem, category: "clipboard")
    static let storage = Logger(subsystem: subsystem, category: "storage")
    static let ui = Logger(subsystem: subsystem, category: "ui")
}
