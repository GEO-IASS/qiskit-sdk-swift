//
//  Qreg.swift
//  qiskit
//
//  Created by Joe Ligman on 6/4/17.
//  Copyright © 2017 IBM. All rights reserved.
//

import Foundation

@objc public class NodeQreg: Node {

    var id: Node? = nil
    
    public init(children: [Node]) {
        super.init(type: .N_QREG, children: children)
        
        self.id = children[0]        
    }
    
    override public func qasm() -> String {
        return "TODO"
    }
}
