import Foundation
import IOKit
import IOKit.ps

/// Public extension point for future vendor SDKs. Implementations must remain read-only and use
/// documented interfaces. Drawstate ships without a vendor-specific provider.
public protocol PowerBankTelemetryProvider {
    func readPowerBanks(now: Date) -> [PowerBankSample]
}

public protocol PowerBankIdentityProvider {
    func identities() -> [USBPowerBankIdentity]
}

public struct USBPowerBankIdentity: Equatable, Sendable {
    public let vendorID: Int
    public let productID: Int
    public let name: String?
    public let serialNumber: String?

    public init(vendorID: Int, productID: Int, name: String?, serialNumber: String?) {
        self.vendorID = vendorID
        self.productID = productID
        self.name = name
        self.serialNumber = serialNumber
    }
}

public struct IOPowerSourcesPowerBankProvider: PowerBankTelemetryProvider {
    public init() {}

    public func readPowerBanks(now: Date = Date()) -> [PowerBankSample] {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else { return [] }

        return sources.compactMap { source in
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?
                .takeUnretainedValue() as? [String: Any]
            else { return nil }
            return PowerBankParser.powerSource(description, now: now)
        }
    }
}

/// Uses the documented USB host device class and descriptor property names. Identity data never
/// creates a card by itself; it only enriches a compatible UPS already publishing power telemetry.
public struct IOKitUSBIdentityProvider: PowerBankIdentityProvider {
    public init() {}

    public func identities() -> [USBPowerBankIdentity] {
        guard let matching = IOServiceMatching("IOUSBHostDevice") else { return [] }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS
        else { return [] }
        defer { IOObjectRelease(iterator) }

        var results: [USBPowerBankIdentity] = []
        while case let service = IOIteratorNext(iterator), service != 0 {
            defer { IOObjectRelease(service) }
            var unmanaged: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(
                service,
                &unmanaged,
                kCFAllocatorDefault,
                0
            ) == KERN_SUCCESS,
            let properties = unmanaged?.takeRetainedValue() as? [String: Any],
            let vendor = (properties["idVendor"] as? NSNumber)?.intValue,
            let product = (properties["idProduct"] as? NSNumber)?.intValue
            else { continue }

            results.append(USBPowerBankIdentity(
                vendorID: vendor,
                productID: product,
                name: (properties["USB Product Name"] as? String)
                    ?? (properties["kUSBProductString"] as? String),
                serialNumber: properties["USB Serial Number"] as? String
            ))
        }
        return results
    }
}

public struct PowerBankTelemetryReader {
    private let telemetryProviders: [any PowerBankTelemetryProvider]
    private let identityProvider: any PowerBankIdentityProvider

    public init(
        telemetryProviders: [any PowerBankTelemetryProvider] = [IOPowerSourcesPowerBankProvider()],
        identityProvider: any PowerBankIdentityProvider = IOKitUSBIdentityProvider()
    ) {
        self.telemetryProviders = telemetryProviders
        self.identityProvider = identityProvider
    }

    public func read(now: Date = Date()) -> [PowerBankSample] {
        // IOPowerSources is the public HID/UPS bridge. USB enumeration only supplements identity;
        // ordinary USB-C devices must never be inferred to be power banks.
        let samples = telemetryProviders
            .flatMap { $0.readPowerBanks(now: now) }
            .filter(\.hasUsableTelemetry)
        guard !samples.isEmpty else { return [] }
        let identities = identityProvider.identities()
        return samples
            .map { sample in enrich(sample, with: identities) }
    }

    private func enrich(
        _ sample: PowerBankSample,
        with identities: [USBPowerBankIdentity]
    ) -> PowerBankSample {
        // Standard IOPowerSources descriptions normally already contain the best product name.
        // Use a unique serial match only; guessing by cable position or generic USB name is unsafe.
        guard let identity = identities.first(where: { candidate in
            if let serial = sample.serialNumber, let candidateSerial = candidate.serialNumber {
                return serial == candidateSerial
            }
            return sample.vendorID == candidate.vendorID && sample.productID == candidate.productID
        }) else { return sample }
        var enriched = sample
        if enriched.name == "Power Bank", let name = identity.name { enriched.name = name }
        if enriched.model == nil { enriched.model = identity.name }
        return enriched
    }
}
