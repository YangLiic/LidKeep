import Foundation
import SwiftUI

let args = Array(CommandLine.arguments.dropFirst())
if !args.isEmpty { exit(CLI.run(arguments: args)) }
LidKeepApp.main()
