import Foundation

#if canImport(FamilyControls)
import FamilyControls
#endif

#if canImport(ManagedSettings)
import ManagedSettings
#endif

@MainActor
enum ScreenTimeSetupService {
    private static let selectionStorageKey = "PushPass.RestrictedActivitySelection"

    static func refreshDashboard(_ dashboard: DashboardState) {
        #if canImport(FamilyControls)
        let isAuthorized = isAuthorizedStatus(AuthorizationCenter.shared.authorizationStatus)
        dashboard.isScreenTimeAuthorized = isAuthorized
        dashboard.hasRestrictedSelection = hasRestrictedActivitySelection

        if !isAuthorized {
            dashboard.restrictionStatus = .notConfigured
        } else if dashboard.hasRestrictedSelection {
            dashboard.restrictionStatus = .appsAvailable
        } else {
            dashboard.restrictionStatus = .notConfigured
        }
        #else
        dashboard.isScreenTimeAuthorized = false
        dashboard.hasRestrictedSelection = false
        dashboard.restrictionStatus = .authorizationUnavailable
        #endif
    }

    static func syncRestrictions(dashboard: DashboardState, accessExpirationDate: Date?) {
        refreshDashboard(dashboard)

        let isAccessActive = accessExpirationDate.map { $0 > .now } ?? false
        let remainingSeconds = max(0, Int((accessExpirationDate ?? .now).timeIntervalSinceNow))
        dashboard.earnedMinutesAvailable = Int(ceil(Double(remainingSeconds) / 60.0))

        if isAccessActive {
            dashboard.restrictionStatus = .earnedSessionActive
        } else if dashboard.isScreenTimeAuthorized, dashboard.hasRestrictedSelection {
            dashboard.restrictionStatus = .appsShielded
        }

        applyShielding(shouldShield: !isAccessActive)
    }

    static func requestAuthorizationIfNeeded(for dashboard: DashboardState) async -> String? {
        #if canImport(FamilyControls)
        let center = AuthorizationCenter.shared
        guard !isAuthorizedStatus(center.authorizationStatus) else {
            refreshDashboard(dashboard)
            return nil
        }

        do {
            try await center.requestAuthorization(for: .individual)
            refreshDashboard(dashboard)
            return nil
        } catch {
            refreshDashboard(dashboard)
            return error.localizedDescription
        }
        #else
        refreshDashboard(dashboard)
        return "Screen Time authorization is unavailable on this platform."
        #endif
    }

    #if canImport(FamilyControls)
    static var storedSelection: FamilyActivitySelection {
        guard let data = UserDefaults.standard.data(forKey: selectionStorageKey),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return FamilyActivitySelection()
        }

        return selection
    }

    static func store(selection: FamilyActivitySelection, dashboard: DashboardState) {
        if let data = try? JSONEncoder().encode(selection) {
            UserDefaults.standard.set(data, forKey: selectionStorageKey)
        }

        refreshDashboard(dashboard)
    }

    static func applyShielding(shouldShield: Bool) {
        #if canImport(FamilyControls) && canImport(ManagedSettings)
        let store = ManagedSettingsStore(named: ManagedSettingsStore.Name(AppConstants.ScreenTime.managedSettingsStoreName))

        guard shouldShield else {
            store.shield.applications = nil
            store.shield.applicationCategories = nil
            store.shield.webDomains = nil
            store.shield.webDomainCategories = nil
            return
        }

        let selection = storedSelection
        guard hasSelection(selection) else {
            store.shield.applications = nil
            store.shield.applicationCategories = nil
            store.shield.webDomains = nil
            store.shield.webDomainCategories = nil
            return
        }

        store.shield.applications = selection.applicationTokens.isEmpty ? nil : selection.applicationTokens
        store.shield.applicationCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        store.shield.webDomains = selection.webDomainTokens.isEmpty ? nil : selection.webDomainTokens
        store.shield.webDomainCategories = selection.categoryTokens.isEmpty ? nil : .specific(selection.categoryTokens)
        #endif
    }

    static var hasRestrictedActivitySelection: Bool {
        hasSelection(storedSelection)
    }

    static func hasSelection(_ selection: FamilyActivitySelection) -> Bool {
        !selection.applicationTokens.isEmpty ||
        !selection.categoryTokens.isEmpty ||
        !selection.webDomainTokens.isEmpty
    }

    static func isAuthorizedStatus(_ status: AuthorizationStatus) -> Bool {
        switch status {
        case .approved, .approvedWithDataAccess:
            true
        case .denied, .notDetermined:
            false
        @unknown default:
            false
        }
    }
    #endif
}
