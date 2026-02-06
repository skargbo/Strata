import Foundation

/// A folder/group that contains sessions in the sidebar
@Observable
final class SessionGroup: Identifiable {
    let id: UUID
    var name: String
    var isExpanded: Bool
    var order: Int

    init(id: UUID = UUID(), name: String, isExpanded: Bool = true, order: Int = 0) {
        self.id = id
        self.name = name
        self.isExpanded = isExpanded
        self.order = order
    }

    init(from data: SessionGroupData) {
        self.id = data.id
        self.name = data.name
        self.isExpanded = data.isExpanded
        self.order = data.order
    }

    func toData() -> SessionGroupData {
        SessionGroupData(id: id, name: name, isExpanded: isExpanded, order: order)
    }
}
