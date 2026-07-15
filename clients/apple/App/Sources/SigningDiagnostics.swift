import Foundation
import Security

private typealias SigningTaskReference = OpaquePointer

@_silgen_name("SecTaskCreateFromSelf")
private func SigningTaskCreateFromSelf(
    _ allocator: CFAllocator?
) -> SigningTaskReference?

@_silgen_name("SecTaskCopySigningIdentifier")
private func SigningTaskCopySigningIdentifier(
    _ task: SigningTaskReference,
    _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?
) -> CFString?

@_silgen_name("SecTaskCopyValueForEntitlement")
private func SigningTaskCopyValueForEntitlement(
    _ task: SigningTaskReference,
    _ entitlement: CFString,
    _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?
) -> CFTypeRef?

@_silgen_name("CFRelease")
private func SigningDiagnosticsCFRelease(_ value: CFTypeRef)

struct SigningDiagnostics: Equatable {
    let capturedAt: Date
    let bundleIdentifier: String
    let signingIdentifier: String?
    let runtimeTeamIdentifier: String?
    let runtimeHealthKitEntitlement: Bool
    let embeddedProfilePresent: Bool
    let profileName: String?
    let profileApplicationIdentifier: String?
    let profileTeamIdentifier: String?
    let profileHealthKitEntitlement: Bool?
    let profileExpirationDate: Date?
    let profileReadError: String?

    static func capture() -> SigningDiagnostics {
        let runtime = captureRuntimeEntitlements()
        let profile = EmbeddedProvisioningProfile.load()

        return SigningDiagnostics(
            capturedAt: Date(),
            bundleIdentifier: Bundle.main.bundleIdentifier ?? "unknown",
            signingIdentifier: runtime.signingIdentifier,
            runtimeTeamIdentifier: runtime.teamIdentifier,
            runtimeHealthKitEntitlement: runtime.healthKit,
            embeddedProfilePresent: profile.isPresent,
            profileName: profile.name,
            profileApplicationIdentifier: profile.applicationIdentifier,
            profileTeamIdentifier: profile.teamIdentifier,
            profileHealthKitEntitlement: profile.healthKitEntitlement,
            profileExpirationDate: profile.expirationDate,
            profileReadError: profile.error
        )
    }

    private static func captureRuntimeEntitlements() -> (
        signingIdentifier: String?,
        teamIdentifier: String?,
        healthKit: Bool
    ) {
        guard let task = SigningTaskCreateFromSelf(nil) else {
            return (nil, nil, false)
        }
        defer {
            SigningDiagnosticsCFRelease(unsafeBitCast(task, to: CFTypeRef.self))
        }

        let signingIdentifier = SigningTaskCopySigningIdentifier(task, nil) as String?
        let teamIdentifier = SigningTaskCopyValueForEntitlement(
            task,
            "com.apple.developer.team-identifier" as CFString,
            nil
        ) as? String
        let healthKitValue = SigningTaskCopyValueForEntitlement(
            task,
            "com.apple.developer.healthkit" as CFString,
            nil
        )
        let healthKit = (healthKitValue as? NSNumber)?.boolValue
            ?? (healthKitValue as? Bool)
            ?? false

        return (signingIdentifier, teamIdentifier, healthKit)
    }

    var conclusion: String {
        if runtimeHealthKitEntitlement && profileHealthKitEntitlement == true {
            return "运行签名和 provisioning profile 均包含 HealthKit。"
        }
        if !runtimeHealthKitEntitlement && profileHealthKitEntitlement == true {
            return "Profile 允许 HealthKit，但最终代码签名没有声明该权限。"
        }
        if runtimeHealthKitEntitlement && profileHealthKitEntitlement != true {
            return "代码签名声明了 HealthKit，但 profile 没有授权，签名配置不一致。"
        }
        if embeddedProfilePresent {
            return "最终签名和 AltStore profile 均未包含 HealthKit。"
        }
        return "最终签名没有 HealthKit，且 App 中未找到 embedded.mobileprovision。"
    }

    var report: String {
        let expiration = profileExpirationDate?.formatted(.iso8601) ?? "nil"
        return """
        HealthMonitorAI signing diagnostics
        capturedAt: \(capturedAt.formatted(.iso8601))
        bundleIdentifier: \(bundleIdentifier)
        signingIdentifier: \(signingIdentifier ?? "nil")
        runtimeTeamIdentifier: \(runtimeTeamIdentifier ?? "nil")
        runtimeHealthKitEntitlement: \(runtimeHealthKitEntitlement)
        embeddedProfilePresent: \(embeddedProfilePresent)
        profileName: \(profileName ?? "nil")
        profileApplicationIdentifier: \(profileApplicationIdentifier ?? "nil")
        profileTeamIdentifier: \(profileTeamIdentifier ?? "nil")
        profileHealthKitEntitlement: \(profileHealthKitEntitlement.map(String.init) ?? "nil")
        profileExpirationDate: \(expiration)
        profileReadError: \(profileReadError ?? "nil")
        conclusion: \(conclusion)
        """
    }
}

private struct EmbeddedProvisioningProfile {
    let isPresent: Bool
    let name: String?
    let applicationIdentifier: String?
    let teamIdentifier: String?
    let healthKitEntitlement: Bool?
    let expirationDate: Date?
    let error: String?

    static func load() -> EmbeddedProvisioningProfile {
        guard let url = Bundle.main.url(
            forResource: "embedded",
            withExtension: "mobileprovision"
        ) else {
            return EmbeddedProvisioningProfile(
                isPresent: false,
                name: nil,
                applicationIdentifier: nil,
                teamIdentifier: nil,
                healthKitEntitlement: nil,
                expirationDate: nil,
                error: "embedded.mobileprovision not found"
            )
        }

        do {
            let data = try Data(contentsOf: url)
            let xmlStartMarker = Data("<?xml".utf8)
            let xmlEndMarker = Data("</plist>".utf8)
            guard let start = data.range(of: xmlStartMarker),
                  let end = data.range(
                    of: xmlEndMarker,
                    in: start.lowerBound..<data.endIndex
                  ) else {
                throw ProfileReadError.plistPayloadNotFound
            }

            let plistData = data.subdata(in: start.lowerBound..<end.upperBound)
            guard let root = try PropertyListSerialization.propertyList(
                from: plistData,
                format: nil
            ) as? [String: Any] else {
                throw ProfileReadError.invalidPropertyList
            }

            let entitlements = root["Entitlements"] as? [String: Any]
            let teams = root["TeamIdentifier"] as? [String]
            return EmbeddedProvisioningProfile(
                isPresent: true,
                name: root["Name"] as? String,
                applicationIdentifier: entitlements?["application-identifier"] as? String,
                teamIdentifier: (entitlements?["com.apple.developer.team-identifier"] as? String)
                    ?? teams?.first,
                healthKitEntitlement: entitlements?["com.apple.developer.healthkit"] as? Bool,
                expirationDate: root["ExpirationDate"] as? Date,
                error: nil
            )
        } catch {
            return EmbeddedProvisioningProfile(
                isPresent: true,
                name: nil,
                applicationIdentifier: nil,
                teamIdentifier: nil,
                healthKitEntitlement: nil,
                expirationDate: nil,
                error: error.localizedDescription
            )
        }
    }

    private enum ProfileReadError: LocalizedError {
        case plistPayloadNotFound
        case invalidPropertyList

        var errorDescription: String? {
            switch self {
            case .plistPayloadNotFound:
                "Could not locate the property list inside embedded.mobileprovision."
            case .invalidPropertyList:
                "The embedded provisioning profile property list is invalid."
            }
        }
    }
}
