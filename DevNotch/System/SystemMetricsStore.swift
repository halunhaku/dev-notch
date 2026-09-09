import Combine
import Darwin
import Foundation
import IOKit.ps
import SystemConfiguration

struct CPUTickSnapshot: Equatable, Sendable {
    let user: UInt32
    let system: UInt32
    let nice: UInt32
    let idle: UInt32
}

struct NetworkCounterSnapshot: Equatable, Sendable {
    let interfaceName: String
    let receivedBytes: UInt64
    let sentBytes: UInt64
    let timestamp: Date
}

enum MemoryPressureLevel: String, Equatable, Sendable {
    case normal
    case warning
    case critical

    var label: String {
        switch self {
        case .normal: "Normal"
        case .warning: "Elevated"
        case .critical: "Critical"
        }
    }
}

enum SystemThermalLevel: String, Equatable, Sendable {
    case nominal
    case fair
    case serious
    case critical

    init(_ state: ProcessInfo.ThermalState) {
        switch state {
        case .nominal: self = .nominal
        case .fair: self = .fair
        case .serious: self = .serious
        case .critical: self = .critical
        @unknown default: self = .fair
        }
    }

    var label: String {
        switch self {
        case .nominal: "Nominal"
        case .fair: "Fair"
        case .serious: "Serious"
        case .critical: "Critical"
        }
    }
}

struct BatteryMetrics: Equatable, Sendable {
    let level: Double
    let isCharging: Bool
    let isOnACPower: Bool
}

struct SystemMetricsSnapshot: Equatable, Sendable {
    var cpuUsage: Double?
    var memoryUsedBytes: UInt64
    var memoryTotalBytes: UInt64
    var memoryPressure: MemoryPressureLevel
    var downloadBytesPerSecond: Double
    var uploadBytesPerSecond: Double
    var networkInterfaceName: String?
    var battery: BatteryMetrics?
    var thermalLevel: SystemThermalLevel

    static let empty = SystemMetricsSnapshot(
        cpuUsage: nil,
        memoryUsedBytes: 0,
        memoryTotalBytes: ProcessInfo.processInfo.physicalMemory,
        memoryPressure: .normal,
        downloadBytesPerSecond: 0,
        uploadBytesPerSecond: 0,
        networkInterfaceName: nil,
        battery: nil,
        thermalLevel: .nominal
    )

    var memoryUsage: Double {
        guard memoryTotalBytes > 0 else { return 0 }
        return min(1, Double(memoryUsedBytes) / Double(memoryTotalBytes))
    }
}

struct MetricHistory: Equatable, Sendable {
    let capacity: Int
    private var storage: [Double]
    private var startIndex = 0
    private(set) var count = 0

    init(capacity: Int = 60) {
        precondition(capacity > 0)
        self.capacity = capacity
        self.storage = Array(repeating: 0, count: capacity)
    }

    mutating func append(_ value: Double) {
        let boundedValue = value.isFinite ? value : 0
        if count < capacity {
            storage[(startIndex + count) % capacity] = boundedValue
            count += 1
        } else {
            storage[startIndex] = boundedValue
            startIndex = (startIndex + 1) % capacity
        }
    }

    subscript(index: Int) -> Double {
        precondition(index >= 0 && index < count)
        return storage[(startIndex + index) % capacity]
    }

    var maximum: Double {
        guard count > 0 else { return 0 }
        var result = self[0]
        for index in 1..<count {
            result = max(result, self[index])
        }
        return result
    }
}

struct SystemMetricHistory: Equatable, Sendable {
    var cpu = MetricHistory()
    var memory = MetricHistory()
    var download = MetricHistory()
    var upload = MetricHistory()
}

@MainActor
final class SystemMetricsSampler {
    private var previousCPUTicks: CPUTickSnapshot?
    private var previousNetworkCounters: NetworkCounterSnapshot?

    func resetDeltas() {
        previousCPUTicks = nil
        previousNetworkCounters = nil
    }

    func sample() -> SystemMetricsSnapshot {
        let currentCPUTicks = readCPUTicks()
        let cpuUsage: Double?
        if let currentCPUTicks {
            if let previousCPUTicks {
                cpuUsage = Self.cpuUsage(from: previousCPUTicks, to: currentCPUTicks)
            } else {
                cpuUsage = nil
            }
            previousCPUTicks = currentCPUTicks
        } else {
            cpuUsage = nil
        }

        let memory = readMemory()
        let currentNetworkCounters = readNetworkCounters()
        let networkRates = currentNetworkCounters.map { current in
            defer { previousNetworkCounters = current }
            guard let previousNetworkCounters,
                  previousNetworkCounters.interfaceName == current.interfaceName else {
                return (download: 0.0, upload: 0.0)
            }
            let duration = current.timestamp.timeIntervalSince(previousNetworkCounters.timestamp)
            return Self.networkRates(from: previousNetworkCounters, to: current, duration: duration)
        } ?? (download: 0, upload: 0)

        return SystemMetricsSnapshot(
            cpuUsage: cpuUsage,
            memoryUsedBytes: memory.usedBytes,
            memoryTotalBytes: memory.totalBytes,
            memoryPressure: memory.pressure,
            downloadBytesPerSecond: networkRates.download,
            uploadBytesPerSecond: networkRates.upload,
            networkInterfaceName: currentNetworkCounters?.interfaceName,
            battery: readBattery(),
            thermalLevel: SystemThermalLevel(ProcessInfo.processInfo.thermalState)
        )
    }

    static func cpuUsage(from previous: CPUTickSnapshot, to current: CPUTickSnapshot) -> Double {
        let user = UInt64(current.user &- previous.user)
        let system = UInt64(current.system &- previous.system)
        let nice = UInt64(current.nice &- previous.nice)
        let idle = UInt64(current.idle &- previous.idle)
        let active = user + system + nice
        let total = active + idle
        guard total > 0 else { return 0 }
        return min(1, Double(active) / Double(total))
    }

    static func networkRates(
        from previous: NetworkCounterSnapshot,
        to current: NetworkCounterSnapshot,
        duration: TimeInterval
    ) -> (download: Double, upload: Double) {
        guard duration > 0,
              previous.interfaceName == current.interfaceName else {
            return (0, 0)
        }
        let receivedDelta = current.receivedBytes >= previous.receivedBytes
            ? current.receivedBytes - previous.receivedBytes
            : 0
        let sentDelta = current.sentBytes >= previous.sentBytes
            ? current.sentBytes - previous.sentBytes
            : 0
        return (Double(receivedDelta) / duration, Double(sentDelta) / duration)
    }

    private func readCPUTicks() -> CPUTickSnapshot? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return CPUTickSnapshot(
            user: info.cpu_ticks.0,
            system: info.cpu_ticks.1,
            nice: info.cpu_ticks.3,
            idle: info.cpu_ticks.2
        )
    }

    private func readMemory() -> (usedBytes: UInt64, totalBytes: UInt64, pressure: MemoryPressureLevel) {
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }

        let totalBytes = ProcessInfo.processInfo.physicalMemory
        guard result == KERN_SUCCESS else {
            return (0, totalBytes, readMemoryPressure())
        }

        let residentPages = UInt64(info.active_count)
            + UInt64(info.inactive_count)
            + UInt64(info.speculative_count)
            + UInt64(info.wire_count)
            + UInt64(info.compressor_page_count)
        let reclaimablePages = UInt64(info.purgeable_count) + UInt64(info.external_page_count)
        let usedPages = residentPages >= reclaimablePages ? residentPages - reclaimablePages : 0
        let usedBytes = min(totalBytes, usedPages * UInt64(getpagesize()))
        return (usedBytes, totalBytes, readMemoryPressure())
    }

    private func readMemoryPressure() -> MemoryPressureLevel {
        var pressure = Int32(0)
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.memorystatus_vm_pressure_level", &pressure, &size, nil, 0) == 0 else {
            return .normal
        }
        switch pressure {
        case 2: return .warning
        case 4: return .critical
        default: return .normal
        }
    }

    private func readNetworkCounters() -> NetworkCounterSnapshot? {
        guard let interfaceName = primaryInterfaceName() else { return nil }
        var addressList: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addressList) == 0, let firstAddress = addressList else { return nil }
        defer { freeifaddrs(addressList) }

        var pointer: UnsafeMutablePointer<ifaddrs>? = firstAddress
        while let currentPointer = pointer {
            let address = currentPointer.pointee
            defer { pointer = address.ifa_next }

            guard String(cString: address.ifa_name) == interfaceName,
                  let socketAddress = address.ifa_addr,
                  Int32(socketAddress.pointee.sa_family) == AF_LINK,
                  let rawData = address.ifa_data else {
                continue
            }

            let data = rawData.assumingMemoryBound(to: if_data.self).pointee
            return NetworkCounterSnapshot(
                interfaceName: interfaceName,
                receivedBytes: UInt64(data.ifi_ibytes),
                sentBytes: UInt64(data.ifi_obytes),
                timestamp: Date()
            )
        }
        return nil
    }

    private func primaryInterfaceName() -> String? {
        let keys = ["State:/Network/Global/IPv4", "State:/Network/Global/IPv6"]
        for key in keys {
            guard let dictionary = SCDynamicStoreCopyValue(nil, key as CFString) as? [String: Any] else {
                continue
            }
            if let name = dictionary[kSCDynamicStorePropNetPrimaryInterface as String] as? String {
                return name
            }
        }
        return nil
    }

    private func readBattery() -> BatteryMetrics? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  let current = description[kIOPSCurrentCapacityKey] as? NSNumber,
                  let maximum = description[kIOPSMaxCapacityKey] as? NSNumber,
                  maximum.doubleValue > 0 else {
                continue
            }
            let isCharging = (description[kIOPSIsChargingKey] as? NSNumber)?.boolValue ?? false
            let powerState = description[kIOPSPowerSourceStateKey] as? String
            return BatteryMetrics(
                level: min(1, current.doubleValue / maximum.doubleValue),
                isCharging: isCharging,
                isOnACPower: powerState == kIOPSACPowerValue
            )
        }
        return nil
    }
}

@MainActor
final class SystemMetricsStore: ObservableObject {
    @Published private(set) var snapshot = SystemMetricsSnapshot.empty
    @Published private(set) var history = SystemMetricHistory()
    @Published private(set) var isSampling = false

    private let sampler: SystemMetricsSampler
    private var samplingTask: Task<Void, Never>?

    init(sampler: SystemMetricsSampler = SystemMetricsSampler()) {
        self.sampler = sampler
    }

    func setActive(_ active: Bool) {
        guard active != isSampling else { return }
        if active {
            isSampling = true
            takeSample()
            samplingTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled else { return }
                    self?.takeSample()
                }
            }
        } else {
            isSampling = false
            samplingTask?.cancel()
            samplingTask = nil
            sampler.resetDeltas()
        }
    }

    private func takeSample() {
        let nextSnapshot = sampler.sample()
        snapshot = nextSnapshot
        if let cpuUsage = nextSnapshot.cpuUsage {
            history.cpu.append(cpuUsage)
        }
        history.memory.append(nextSnapshot.memoryUsage)
        history.download.append(nextSnapshot.downloadBytesPerSecond)
        history.upload.append(nextSnapshot.uploadBytesPerSecond)
    }

    deinit {
        samplingTask?.cancel()
    }
}
