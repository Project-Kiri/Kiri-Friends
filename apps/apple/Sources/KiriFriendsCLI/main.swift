import Foundation
import KiriFriendsCore

@main
struct KiriFriendsCLI {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        switch arguments.first {
        case "--empty-snapshot":
            try printJSON(StateSnapshot.empty)
        case "--help", "-h", nil:
            printHelp()
        default:
            printHelp()
            throw CLIError.unknownArgument(arguments.first ?? "")
        }
    }

    private static func printJSON<T: Encodable>(_ value: T) throws {
        let data = try value.prettyJSONData()
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }

    private static func printHelp() {
        let text = """
        KiriFriendsCLI

        Usage:
          KiriFriendsCLI --help
          KiriFriendsCLI --empty-snapshot

        The Mac-side runtime is KiriFriendsBuddyMac. This helper prints
        runtime-safe diagnostics and never emits sample approval data.
        """
        FileHandle.standardOutput.write(Data("\(text)\n".utf8))
    }

    private enum CLIError: Error {
        case unknownArgument(String)
    }
}
