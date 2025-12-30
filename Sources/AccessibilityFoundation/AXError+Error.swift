import AppKit

extension AXError: @retroactive _BridgedNSError {}
extension AXError: @retroactive _ObjectiveCBridgeableError {}
extension AXError: @retroactive Error { }
