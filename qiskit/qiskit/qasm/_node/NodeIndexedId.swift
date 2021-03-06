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
Node for an OPENQASM indexed id.
children[0] is an id node.
children[1] is an integer (not a node).
*/
public final class NodeIndexedId: Node {

    public let identifer: Node?
    public private(set) var _name: String = ""
    public private(set) var line: Int = 0
    public private(set) var file: String = ""
    public private(set) var index: Int = -1
    
    @objc public init(identifier: Node, index: Node?) {
        self.identifer = identifier
        self.index = (index as? NodeNNInt)?.value ?? -1
        if let _id = self.identifer as? NodeId{
            // Name of the qreg
            self._name = _id.name
            // Source line number
            self.line = _id.line
            // Source file name
            self.file = _id.file
        }
            
   }

    public override var type: NodeType {
        return .N_INDEXEDID
    }

    public override var name: String {
        return _name
    }
    
    public override func qasm(_ prec: Int) -> String {
        guard let ident = identifer else {
            assertionFailure("Invalid NodeIndexedId Operation")
            return ""
        }
        var qasm: String = "\(ident.qasm(prec))"
        if index >= 0 {
            qasm += " [\(index)]"
        }
        return qasm
    }
    
}
