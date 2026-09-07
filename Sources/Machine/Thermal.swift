import Foundation

/// How hot the machine says it is.
///
/// `ProcessInfo.thermalState` is the only heat signal that needs no
/// entitlement and no sensor reading. It is a judgement, not a temperature,
/// and the app trusts it as one.
enum ThermalLevel: Int, Codable, Comparable, CaseIterable {
    case nominal, fair, serious, critical

    init(_ state: ProcessInfo.ThermalState) {
        switch state {
        case .nominal: self = .nominal
        case .fair: self = .fair
        case .serious: self = .serious
        case .critical: self = .critical
        @unknown default: self = .nominal
        }
    }

    static func < (lhs: ThermalLevel, rhs: ThermalLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum Thermal {
    static func read() -> ThermalLevel {
        ThermalLevel(ProcessInfo.processInfo.thermalState)
    }
}
