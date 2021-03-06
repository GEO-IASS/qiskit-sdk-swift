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
Node for an OPENQASM primarylist.
children is a list of primary nodes. Primary nodes are indexedid or id.
*/

public final class NodePrimaryList: Node {
    
    public private(set) var identifiers: [Node]? = nil
   
    @objc public init(identifier: Node?) {
        super.init()
        if let ident = identifier {
            self.identifiers = [ident]
        }
    }
    
    @objc public func addIdentifier(identifier: Node) {
        identifiers?.append(identifier)
    }
    
    public override var type: NodeType {
        return .N_PRIMARYLIST
    }
    
    public override var children: [Node] {
        return (identifiers != nil) ? identifiers! : []
    }
    
    public override func qasm(_ prec: Int) -> String {
        var qasms: [String] = []
        if let list = identifiers {
            qasms = list.flatMap({ (node: Node) -> String in
                return node.qasm(prec)
            })
        }
        return qasms.joined(separator: ",")
    }
}
