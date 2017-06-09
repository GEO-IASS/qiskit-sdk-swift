//
//  If.swift
//  qiskit
//
//  Created by Joe Ligman on 6/4/17.
//  Copyright © 2017 IBM. All rights reserved.
//

import Foundation

@objc public class NodeIf: Node {

    public init() {
        super.init(type: .N_IF)
    }
    
    override public func qasm() -> String {
        preconditionFailure("qasm not implemented")
    }
}
