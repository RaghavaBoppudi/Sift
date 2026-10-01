import Foundation

public struct AnalysisResult: Sendable {
    public let conflictGroups: [ConflictGroup]
    public let reuseGroups: [ReuseGroup]
}
