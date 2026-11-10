import Foundation
import IOKit.ps

enum BatteryMonitor {
    /// Returns nil on machines with no internal battery, which is what keeps
    /// the low-battery rule from ever firing on a desktop Mac.
    static func current() -> BatteryState? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?
                .takeUnretainedValue() as? [String: Any],
                description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                let capacity = description[kIOPSCurrentCapacityKey] as? Int,
                let maximum = description[kIOPSMaxCapacityKey] as? Int,
                maximum > 0
            else { continue }

            let powerState = description[kIOPSPowerSourceStateKey] as? String
            return BatteryState(
                percentage: Int((Double(capacity) / Double(maximum) * 100).rounded()),
                isPluggedIn: powerState == kIOPSACPowerValue
            )
        }
        return nil
    }
}
