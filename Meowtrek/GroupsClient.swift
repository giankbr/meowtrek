import Foundation

extension AppState {
    /// The current group code, remembered across launches.
    var groupCode: String {
        get { UserDefaults.standard.string(forKey: "groupCode") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "groupCode") }
    }

    private var isoWeekCalendar: Calendar {
        var c = Calendar.current
        c.firstWeekday = 2
        c.minimumDaysInFirstWeek = 4
        return c
    }

    var weekID: String {
        let comp = isoWeekCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
        return String(format: "%04d-W%02d", comp.yearForWeekOfYear ?? 0, comp.weekOfYear ?? 0)
    }

    var isoWeekSteps: Int {
        let c = isoWeekCalendar
        guard let start = c.dateInterval(of: .weekOfYear, for: .now)?.start else { return 0 }
        var total = 0, d = start
        let today = c.startOfDay(for: .now)
        while d <= today {
            total += steps.steps(on: d)
            d = c.date(byAdding: .day, value: 1, to: d)!
        }
        return total
    }

    private func memberBody() -> GroupsAPI.MemberBody {
        GroupsAPI.MemberBody(name: petName.isEmpty ? "Walker" : petName,
                             fur: equipped[.fur] ?? "fur_ginger",
                             steps: isoWeekSteps, week: weekID)
    }

    @MainActor func createGroup(name: String, goal: Int) async {
        do {
            let g = try await GroupsAPI.create(device: profileID, name: name, goal: goal, member: memberBody())
            group = g; groupCode = g.code
            Telemetry.track("group_created")
        } catch {
            show(error.localizedDescription)
        }
    }

    @MainActor func joinGroup(code: String) async {
        let code = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard code.count == 6 else { show(loc("A group code is 6 letters.")); return }
        do {
            let g = try await GroupsAPI.join(device: profileID, code: code, member: memberBody())
            group = g; groupCode = g.code
            Telemetry.track("group_joined")
        } catch {
            show(error.localizedDescription)
        }
    }

    @MainActor func syncGroup() async {
        guard !groupCode.isEmpty else { return }
        do {
            group = try await GroupsAPI.sync(device: profileID, code: groupCode, member: memberBody())
        } catch GroupError.noGroup {
            group = nil; groupCode = ""
        } catch {
            // keep the last-known board on a transient network error
        }
    }

    @MainActor func leaveGroup() async {
        let code = groupCode
        group = nil; groupCode = ""
        guard !code.isEmpty else { return }
        try? await GroupsAPI.leave(device: profileID, code: code)
    }
}
