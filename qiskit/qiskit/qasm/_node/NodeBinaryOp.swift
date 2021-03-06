// Copyright 2017 IBM RESEARCH. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// =============================================================================


import Foundation

/*
 Node for an OPENQASM binary operation exprssion.
 children[0] is the operation, as a character.
 children[1] is the left expression.
 children[2] is the right expression.
 */

public final class NodeBinaryOp: Node, NodeRealValueProtocol {

    public let op: String
    public let _children: [Node]
    
    @objc public init(op: String, children: [Node]) {
        self.op = op
        self._children = children
    }
    
    public override var type: NodeType {
        return .N_BINARYOP
    }
    
    public override func qasm(_ prec: Int) -> String {
        let lhs = _children[0]
        let rhs = _children[1]
        
        var lhsqasm = lhs.qasm(prec)
        if lhs.type == .N_BINARYOP {
            if (lhs as! NodeBinaryOp).op == "+" || (lhs as! NodeBinaryOp).op == "-" {
                lhsqasm = "(\(lhs.qasm(prec)))"
            }
        }
        
        return "\(lhsqasm) \(op) \(rhs.qasm(prec))"
    }

    public func real(_ nested_scope: [[String:NodeRealValueProtocol]]? = nil) throws -> Double {
        let operation = self.op
        guard let lexpr = self._children[0] as? NodeRealValueProtocol else {
            throw QasmException.errorBinop(qasm: self.qasm(15))
        }
        guard let rexpr = self._children[1] as? NodeRealValueProtocol else {
            throw QasmException.errorBinop(qasm: self.qasm(15))
        }
        let lhs = try lexpr.real(nested_scope)
        let rhs = try rexpr.real(nested_scope)
        if operation == "+" {
            return lhs + rhs
        }
        if operation == "-" {
            return lhs - rhs
        }
        if operation == "*" {
            return lhs * rhs
        }
        if operation == "/" {
            return lhs / rhs
        }
        if operation == "^" {
            return pow(lhs,rhs)
        }
        throw QasmException.errorBinop(qasm: self.qasm(15))
    }
}
