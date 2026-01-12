import AppKit
import Foundation

final class AppTerminationController {
    static let shared = AppTerminationController()
    private init() {}

    var allowTerminate = false
}

