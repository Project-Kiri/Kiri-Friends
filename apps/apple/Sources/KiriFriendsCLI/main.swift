import Foundation
import KiriFriendsCore

@main
struct KiriFriendsCLI {
    static func main() throws {
        let snapshot = StateSnapshot.placeholder
        let data = try snapshot.prettyJSONData()
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }
}
