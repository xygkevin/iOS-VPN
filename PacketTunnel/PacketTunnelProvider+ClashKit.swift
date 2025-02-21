import os
import ClashKit

fileprivate extension Logger {
    static let tunnel = Logger(subsystem: "com.Arror.Clash.PacketTunnel", category: "Clash")
}

extension PacketTunnelProvider: ClashPacketFlowProtocol, ClashTrafficReceiverProtocol, ClashRealTimeLoggerProtocol {
    
    func setupClash() throws {
        let config = """
        mixed-port: 8080
        mode: \(UserDefaults.shared.string(forKey: Clash.tunnelMode) ?? Clash.TunnelMode.rule.rawValue)
        log-level: \(UserDefaults.shared.string(forKey: Clash.logLevel) ?? Clash.LogLevel.silent.rawValue)
        """
        var error: NSError? = nil
        ClashSetup(self, Clash.homeDirectoryURL.path, config, &error)
        if let error = error {
            throw error
        }
        ClashSetRealTimeLogger(self)
        ClashSetTrafficReceiver(self)
    }
    
    func setCurrentConfig() throws {
        var error: NSError? = nil
        ClashSetConfig(UserDefaults.shared.string(forKey: Clash.currentConfigUUID), &error)
        guard let error = error else {
            return
        }
        throw error
    }
    
    func patchSelectGroup() {
        guard let id = UserDefaults.shared.string(forKey: Clash.currentConfigUUID), !id.isEmpty,
              let mapping = UserDefaults.shared.dictionary(forKey: id) as? [String: String], !mapping.isEmpty else {
            return
        }
        do {
            ClashPatchSelectGroup(try JSONEncoder().encode(mapping))
        } catch {
            debugPrint(error.localizedDescription)
        }
    }
    
    func writePacket(_ packet: Data?) {
        guard let packet = packet else {
            return
        }
        self.packetFlow.writePackets([packet], withProtocols: [AF_INET as NSNumber])
    }
    
    func receiveTraffic(_ up: Int64, down: Int64) {
        UserDefaults.shared.set(Double(up), forKey: Clash.Traffic.up.rawValue)
        UserDefaults.shared.set(Double(down), forKey: Clash.Traffic.down.rawValue)
    }
    
    func log(_ level: String?, payload: String?) {
        guard let level = level.flatMap(Clash.LogLevel.init(rawValue:)),
              let payload = payload, !payload.isEmpty else {
            return
        }
        switch level {
        case .silent:
            break
        case .info, .debug:
            Logger.tunnel.notice("\(payload, privacy: .public)")
        case .warning:
            Logger.tunnel.warning("\(payload, privacy: .public)")
        case .error:
            Logger.tunnel.critical("\(payload, privacy: .public)")
        }
    }
}
