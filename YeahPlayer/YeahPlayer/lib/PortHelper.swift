//
//  yeahPlayer sample code
//
//  Created by Alex Bird 07/03/2025.
//

/// Reserve an ephemeral port from the system
/// https://stackoverflow.com/a/77897502/673333
///
/// First we `bind` to port 0 in order to allocate an ephemeral port.
/// Next, we `connect` to that port to establish a connection.
/// Finally, we close the port and put it into the `TIME_WAIT` state.
///
/// This allows another process to `bind` the port with `SO_REUSEADDR` specified.
/// However, for the next ~120 seconds, the system will not re-use this port.
/// - Returns: A port number that is valid for ~120 seconds.
func reservePort() throws -> UInt16 {
    let serverSock = socket(AF_INET, SOCK_STREAM, 0)
    guard serverSock >= 0 else {
        throw ServerError.cannotReservePort
    }
    defer {
        close(serverSock)
    }
    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_addr.s_addr = INADDR_ANY
    addr.sin_port = 0 // request an ephemeral port

    var len = socklen_t(MemoryLayout<sockaddr_in>.stride)
    let res = withUnsafeMutablePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            let res1 = bind(serverSock, $0, len)
            let res2 = getsockname(serverSock, $0, &len)
            return (res1, res2)
        }
    }
    guard res.0 == 0 && res.1 == 0 else {
        throw ServerError.cannotReservePort
    }

    guard listen(serverSock, 1) == 0 else {
        throw ServerError.cannotReservePort
    }

    let clientSock = socket(AF_INET, SOCK_STREAM, 0)
    guard clientSock >= 0 else {
        throw ServerError.cannotReservePort
    }
    defer {
        close(clientSock)
    }
    let res3 = withUnsafeMutablePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            Darwin.connect(clientSock, $0, len)
        }
    }
    guard res3 == 0 else {
        throw ServerError.cannotReservePort
    }

    let acceptSock = accept(serverSock, nil, nil)
    guard acceptSock >= 0 else {
        throw ServerError.cannotReservePort
    }
    defer {
        close(acceptSock)
    }
    return addr.sin_port.byteSwapped
}

enum ServerError: Error {
    case cannotReservePort
}
