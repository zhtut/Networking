//
//  File.swift
//  
//
//  Created by zhtg on 2023/3/18.
//

import Foundation

public enum WebSocketError: Error {
    case noTask
    case taskNotRunning
}

public enum WebSocketState {
    case connecting
    case connected
    case closing
    case closed
}
