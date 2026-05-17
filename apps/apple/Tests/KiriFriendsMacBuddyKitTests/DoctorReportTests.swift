// DoctorReportTests.swift
// Validates the Phase 9 health snapshot.

import Foundation
import KiriFriendsMacBuddyKit
import Testing

@Suite("DoctorReport")
struct DoctorReportTests {
    @Test("Report flags a missing bridge port as critical")
    func missingBridgePortCritical() async {
        let store = MacBuddyStateStore()
        let dnd = DoNotDisturbState()
        let doctor = DoctorService(store: store, dnd: dnd)
        let report = await doctor.generate(bridgePort: nil, bundledThemeCount: 3)
        let portFinding = report.findings.first { $0.id == "bridge-port" }
        #expect(portFinding?.severity == .critical)
    }

    @Test("Report marks listening bridge as ok")
    func listeningBridgeOk() async {
        let store = MacBuddyStateStore()
        let dnd = DoNotDisturbState()
        let doctor = DoctorService(store: store, dnd: dnd)
        let report = await doctor.generate(bridgePort: 7474, bundledThemeCount: 3)
        let portFinding = report.findings.first { $0.id == "bridge-port" }
        #expect(portFinding?.severity == .ok)
        #expect(report.bridgePort == 7474)
    }

    @Test("Report surfaces DND when enabled")
    func reportsDnd() async {
        let store = MacBuddyStateStore()
        let dnd = DoNotDisturbState(initial: true)
        let doctor = DoctorService(store: store, dnd: dnd)
        let report = await doctor.generate(bridgePort: 7474, bundledThemeCount: 3)
        let dndFinding = report.findings.first { $0.id == "dnd" }
        #expect(dndFinding?.severity == .info)
        #expect(report.doNotDisturb == true)
    }

    @Test("Report flags missing themes as warning")
    func missingThemesWarning() async {
        let store = MacBuddyStateStore()
        let dnd = DoNotDisturbState()
        let doctor = DoctorService(store: store, dnd: dnd)
        let report = await doctor.generate(bridgePort: 7474, bundledThemeCount: 0)
        let themeFinding = report.findings.first { $0.id == "themes" }
        #expect(themeFinding?.severity == .warning)
    }
}
