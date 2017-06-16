//
//  GateDecl.swift
//  qiskit
//
//  Created by Joe Ligman on 6/4/17.
//  Copyright © 2017 IBM. All rights reserved.
//

import Foundation

@objc public class NodeGateDecl: Node {

    var gate: Node?
    var identifier: Node?
    var idlist1: Node?
    var idlist2: Node?
    public init(gate: Node?, identifier: Node?, idlist1: Node?, idlist2: Node?) {
        super.init(type: .N_GATEDECL)
        self.gate = gate
        self.identifier = identifier
        self.idlist1 = idlist1
        self.idlist2 = idlist2
    }
    
    override public func qasm() -> String {
        guard let g8 = gate else {
            assertionFailure("Invalid NodeGateDecl Operation")
            return ""
        }
        guard let ident = identifier else {
            assertionFailure("Invalid NodeGateDecl Operation")
            return ""
        }
        guard let list1 = idlist1 else {
            assertionFailure("Invalid NodeGateDecl Operation")
            return ""
        }
        if let list2 = idlist2 {
            return "\(g8.qasm()) \(ident.qasm()) (\(list1.qasm())) \(list2.qasm()) {"
        }
        
        return "\(g8.qasm()) \(list1.qasm()) {" // FIXME: figure out the correct parenthesis 
    }
}
