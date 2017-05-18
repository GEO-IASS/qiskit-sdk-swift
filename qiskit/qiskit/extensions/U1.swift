//
//  U1.swift
//  qiskit
//
//  Created by Manoel Marques on 5/15/17.
//  Copyright © 2017 IBM. All rights reserved.
//

import Cocoa

/**
 Diagonal single qubit gate
 */
public final class U1Gate: Gate {

    public init(_ theta: Double, _ qubit: QuantumRegisterTuple) {
        super.init("u1", [theta], [qubit])
    }

    public override var description: String {
        let theta = String(format:"%.15f",self.params[0])
        return self._qasmif("\(name)(\(theta)) \(self.args[0].identifier)")
    }
}
