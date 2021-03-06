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

public protocol RegisterArgument {
    var identifier: String { get }
}

public protocol Register: RegisterArgument, CustomStringConvertible {

    var name:String { get }
    var size:Int { get }
}

extension Register {

    public var identifier: String {
        return self.name
    }

    /**
     Check that i is a valid index.
     */
    public func check_range(_ i: Int) throws {
        if i < 0 || i >= self.size {
            throw QISKitError.regIndexRange
        }
    }

    func checkProperties() throws {
        var matches: Int = 0
        do {
            let regex = try NSRegularExpression(pattern: "[a-z][a-zA-Z0-9_]*")
            let nsString = self.name as NSString
            matches = regex.numberOfMatches(in: name, options: [], range: NSRange(location: 0, length: nsString.length))
        } catch {
            throw QISKitError.internalError(error: error)
        }
        if matches <= 0 {
            throw QISKitError.regName
        }
        if self.size <= 0 {
            throw QISKitError.regSize
        }
    }
}
