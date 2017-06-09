//
//  Measure.swift
//  qiskit
//
//  Created by Joe Ligman on 6/4/17.
//  Copyright © 2017 IBM. All rights reserved.
//

import Foundation

@objc public class NodeMeasure: Node {

    public init() {
        super.init(type: .N_MEASURE)
    }
    
    override public func qasm() -> String {
        preconditionFailure("qasm not implemented")
    }
}
