import Foundation
import Observation

/// The timer engine: phase machine, cycle bookkeeping and session recording.
///
/// Remaining time is derived from a wall-clock end date rather than counted
/// down tick by tick, so the timer stays accurate across display sleep.
@Observable
final class FocusTimer {
    static let shared = FocusTimer()

    private(set) var phase: Phase = .focus
    private(set) var state: RunState = .pending
    private(set) var remainingSeconds: Int = 25 * 60
    /// Completed focus sessions inside the current cycle (0 ..< cycleLength).
    private(set) var completedFlowsInCycle: Int = 0

    /// Called with (finishedPhase, nextPhase) whenever a segment runs out.
    var onPhaseCompleted: ((Phase, Phase) -> Void)?
    /// Called on every observable change, for the menu bar.
    var onTick: (() -> Void)?

    private let settings = AppSettings.shared
    private let store = SessionStore.shared
    private var endDate: Date?
    private var ticker: Timer?
    private var record: Session?
    private var openInterruption: Interruption?

    private init() {
        completedFlowsInCycle = settings.resetCycleAtLaunch ? 0 : UserDefaults.standard.integer(forKey: "lastCompletedFlows")
        if settings.resetCycleAtLaunch {
            phase = .focus
        } else {
            phase = Phase(rawValue: UserDefaults.standard.string(forKey: "lastPhase") ?? "") ?? .focus
        }
        remainingSeconds = plannedSeconds
    }

    // MARK: - Derived state

    var plannedSeconds: Int { settings.duration(for: phase) * 60 }

    var progress: Double {
        let planned = Double(plannedSeconds)
        guard planned > 0 else { return 0 }
        return min(1, max(0, 1 - Double(remainingSeconds) / planned))
    }

    var isRunning: Bool { state == .running }

    /// What the menu bar and window show as a headline.
    var statusTitle: String {
        switch state {
        case .pending: return phase.title
        case .running: return phase == .focus ? settings.sessionTitle : phase.title
        case .paused: return "Paused"
        case .completed: return "\(phase.title) complete"
        }
    }

    var clock: String { formatClock(remainingSeconds) }

    /// Index of the next long break, e.g. "2 / 4".
    var cyclePosition: String { "\(min(completedFlowsInCycle + 1, settings.cycleLength)) / \(settings.cycleLength)" }

    /// True while commitment mode locks pause / skip / reset.
    var isLocked: Bool { settings.enableCommitmentMode && state == .running && phase == .focus }

    // MARK: - Controls

    func start() {
        guard state != .running else { return }
        if record == nil { beginRecord() }
        if let interruption = openInterruption {
            var closed = interruption
            closed.finishedAt = Date()
            record?.interruptions.append(closed)
            openInterruption = nil
        }
        endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        state = .running
        startTicker()
        SoundService.shared.setTicking(settings.enableTickingSound && phase == .focus)
        AppBlocker.shared.setActive(phase == .focus)
        persistState()
        onTick?()
    }

    func pause() {
        guard state == .running, !isLocked else { return }
        syncRemaining()
        state = .paused
        stopTicker()
        SoundService.shared.setTicking(false)
        AppBlocker.shared.setActive(false)
        openInterruption = Interruption(startedAt: Date())
        persistState()
        onTick?()
    }

    func toggle() {
        state == .running ? pause() : start()
    }

    /// Ends the current segment without completing it and moves on.
    func skip() {
        guard !isLocked else { return }
        finishRecord(completed: false)
        advance(after: phase, countFlow: false)
    }

    /// Reloads the current segment from the start; a second press steps back
    /// to the previous segment.
    func previous() {
        guard !isLocked else { return }
        if remainingSeconds < plannedSeconds || state != .pending {
            reset()
            return
        }
        discardRecord()
        switch phase {
        case .focus:
            if completedFlowsInCycle > 0 {
                completedFlowsInCycle -= 1
                phase = completedFlowsInCycle % settings.cycleLength == settings.cycleLength - 1 ? .longBreak : .shortBreak
            }
        case .shortBreak, .longBreak:
            phase = .focus
        }
        prepare(phase)
    }

    /// Restarts the current segment.
    func reset() {
        guard !isLocked else { return }
        discardRecord()
        prepare(phase)
    }

    /// Back to the first focus session of a fresh cycle.
    func restartCycle() {
        guard !isLocked else { return }
        discardRecord()
        completedFlowsInCycle = 0
        phase = .focus
        prepare(.focus)
    }

    func setTitle(_ title: String) {
        settings.sessionTitle = title.isEmpty ? "Focus" : title
        record?.title = settings.sessionTitle
        onTick?()
    }

    /// Re-reads the duration of the current phase after a settings change.
    func durationsChanged() {
        guard state == .pending else { return }
        remainingSeconds = plannedSeconds
        onTick?()
    }

    // MARK: - Phase machine

    private func nextPhase(after finished: Phase, completedFlows: Int) -> Phase {
        switch finished {
        case .focus:
            // A long break is due only once a full cycle of focus sessions is
            // actually done — skipping the first session must not trigger one.
            return completedFlows > 0 && completedFlows % max(1, settings.cycleLength) == 0
                ? .longBreak
                : .shortBreak
        case .shortBreak, .longBreak:
            return .focus
        }
    }

    private func prepare(_ next: Phase) {
        phase = next
        state = .pending
        remainingSeconds = plannedSeconds
        endDate = nil
        stopTicker()
        SoundService.shared.setTicking(false)
        AppBlocker.shared.setActive(false)
        persistState()
        onTick?()
    }

    private func advance(after finished: Phase, countFlow: Bool) {
        if countFlow && finished == .focus {
            completedFlowsInCycle += 1
        }
        let next = nextPhase(after: finished, completedFlows: completedFlowsInCycle)
        if next == .focus && finished == .longBreak {
            completedFlowsInCycle = 0
        }
        prepare(next)
        onPhaseCompleted?(finished, next)

        let autoStart = next == .focus ? settings.startFlowsAutomatically : settings.startBreaksAutomatically
        if autoStart { start() }
    }

    private func complete() {
        syncRemaining()
        remainingSeconds = 0
        let finished = phase
        finishRecord(completed: true)
        advance(after: finished, countFlow: true)
    }

    // MARK: - Ticking

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard state == .running, let endDate else { return }
        let remaining = Int(endDate.timeIntervalSinceNow.rounded(.up))
        if remaining <= 0 {
            complete()
        } else if remaining != remainingSeconds {
            remainingSeconds = remaining
            persistState()
            onTick?()
        }
    }

    private func syncRemaining() {
        guard let endDate else { return }
        remainingSeconds = max(0, Int(endDate.timeIntervalSinceNow.rounded(.up)))
    }

    // MARK: - Recording

    private func beginRecord() {
        record = Session(
            phase: phase,
            title: phase == .focus ? settings.sessionTitle : phase.title,
            startedAt: Date(),
            finishedAt: nil,
            activeSeconds: 0,
            plannedSeconds: plannedSeconds,
            completed: false,
            interruptions: []
        )
    }

    private func finishRecord(completed: Bool) {
        guard var record else { return }
        syncRemaining()
        if let interruption = openInterruption {
            var closed = interruption
            closed.finishedAt = Date()
            record.interruptions.append(closed)
            openInterruption = nil
        }
        record.finishedAt = Date()
        record.activeSeconds = max(0, record.plannedSeconds - remainingSeconds)
        record.completed = completed
        // Don't clutter the log with sessions that barely started.
        if record.activeSeconds >= 5 || completed {
            store.save(record)
        }
        self.record = nil
    }

    private func discardRecord() {
        if record != nil { finishRecord(completed: false) }
        openInterruption = nil
    }

    private func persistState() {
        let d = UserDefaults.standard
        d.set(phase.rawValue, forKey: "lastPhase")
        d.set(state.rawValue, forKey: "lastName")
        d.set(remainingSeconds, forKey: "lastRemainingSeconds")
        d.set(completedFlowsInCycle, forKey: "lastCompletedFlows")
    }
}
