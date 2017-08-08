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
 Node for an OPENQASM gate definition.
 children[0] is an id node.
 If len(children) is 3, children[1] is an idlist node,
 and children[2] is a gatebody node.
 Otherwise, children[1] is an expressionlist node,
 children[2] is an idlist node, and children[3] is a gatebody node.
 */

@objc public final class NodeGate: Node {

    public let identifier: Node?
    public let arguments: Node?
    public let bitlist: Node?
    public let body: Node?

    public var _name: String = ""
    public var line: Int = 0
    public var file: String = ""
    public var index: Int = 0

    public var n_args: Int {
        get{
            return arguments?.children.count ?? 0
        }
    }
    
    public var n_bits: Int {
        get {
            return bitlist?.children.count ?? 0
        }
    }
    
    public init(identifier: Node?, arguments: Node?, bitlist: Node?, body: Node?) {
        self.identifier = identifier
        self.arguments = arguments
        self.bitlist = bitlist
        self.body = body
        
        if let _id = self.identifier as? NodeId {
            // Name of the qreg
            self._name = _id.name
            // Source line number
            self.line = _id.line
            // Source file name
            self.file = _id.file
            // Size of the register
            self.index = _id.index
        }
        
    }
    
    public override var type: NodeType {
        return .N_GATE
    }
    
    public override var name: String {
        return _name
    }
 
    public override var children: [Node] {
        var _children: [Node] = []
        if let ident = identifier {
            _children.append(ident)
        }
        if let args = arguments {
            _children.append(args)
        }
        if let btlist = bitlist {
            _children.append(btlist)
        }
        if let body = body {
            _children.append(body)
        }
        return _children
    }
    
    public override func qasm() -> String {
        var qasm = "gate \(self.name)"
        if let args = self.arguments {
            qasm += "(" + args.qasm() + ")"
        }
        if let bits = self.bitlist {
            qasm += " \(bits.qasm())\n"
        }
        if let bdy = self.body {
            qasm += "{\n \(bdy.qasm()) }"
        }
        return qasm
    }
    
 
}