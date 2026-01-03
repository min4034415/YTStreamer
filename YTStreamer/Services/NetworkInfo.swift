import Foundation
import Network

/// Get network information
class NetworkInfo {

    static let shared = NetworkInfo()

    private init() {}

    /// Get local IP address
    var localIPAddress: String? {
        var address: String?

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }

            guard let interface = ptr?.pointee else { continue }
            let addrFamily = interface.ifa_addr.pointee.sa_family

            // Check for IPv4
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)

                // Skip loopback
                if name == "lo0" { continue }

                // Prefer en0 (WiFi) or en1 (Ethernet)
                if name.hasPrefix("en") {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(
                        interface.ifa_addr,
                        socklen_t(interface.ifa_addr.pointee.sa_len),
                        &hostname,
                        socklen_t(hostname.count),
                        nil,
                        socklen_t(0),
                        NI_NUMERICHOST
                    )
                    address = String(cString: hostname)
                    break
                }
            }
        }

        return address
    }

    /// Get stream URL
    func streamURL(port: UInt16 = 8000, filename: String = "stream.mp3") -> String? {
        guard let ip = localIPAddress else { return nil }
        return "http://\(ip):\(port)/\(filename)"
    }
}
