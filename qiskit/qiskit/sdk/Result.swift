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

/**
 Result Class.
 Class internal properties.
 Methods to process the quantum program after it has been run
 Internal::
     qobj =  { -- the quantum object that was complied --}
     result =
         [
             {
             "data":
                 {  #### DATA CAN BE A DIFFERENT DICTIONARY FOR EACH BACKEND ####
                 "counts": {’00000’: XXXX, ’00001’: XXXXX},
                 "time"  : xx.xxxxxxxx
                 },
             "status": --status (string)--
             },
             ...
        ]
 */
public final class Result: CustomStringConvertible {

    private var __qobj: [String:Any]
    private var __result: [String:Any]

    init() {
        self.__qobj = [:]
        self.__result = [:]
    }

    init(_ qobj_result: [String:Any], _ qobj: [String:Any]) {
        self.__qobj = qobj
        self.__result = qobj_result
    }

    /**
     Get the status of the run.
     Returns:
     the status of the results.
     */
    public var description: String {
        return self.get_status() ?? ""
    }

    /**
     Append a Result object to current Result object.
     Arg:
        other (Result): a Result object to append.
     Returns:
        The current object with appended results.
     */
    public static func += (left: inout Result, right: Result) throws {
        if let leftConfig = left.__qobj["config"] as? [String:Any],
            let rightConfig = right.__qobj["config"] as? [String:Any] {
            if NSDictionary(dictionary: leftConfig).isEqual(to: rightConfig) {
                if let leftId = left.__qobj["id"] as? String {
                    left.__qobj["id"] = [leftId]
                }
                if var leftIds = left.__qobj["id"] as? [String] {
                    if let rightId = right.__qobj["id"] as? String {
                        leftIds.append(rightId)
                    }
                    else if let rightIds = right.__qobj["id"] as? [String] {
                        leftIds.append(contentsOf:rightIds)
                    }
                    left.__qobj["id"] = leftIds
                }
                if let rightCircuits = right.__qobj["circuits"] as? [Any] {
                    if var leftCircuits = left.__qobj["circuits"] as? [Any] {
                        leftCircuits.append(contentsOf: rightCircuits)
                        left.__qobj["circuits"] = leftCircuits
                    }
                    else {
                        left.__qobj["circuits"] = rightCircuits
                    }
                }
                if let rightResults = right.__result["result"] as? [Any] {
                    if var leftResults = left.__result["result"] as? [Any] {
                        leftResults.append(contentsOf: rightResults)
                        left.__result["result"] = leftResults
                    }
                    else {
                        left.__result["result"] = rightResults
                    }
                }
                return
            }
        }
        throw QISKitError.invalidResultsCombine
    }

    /**
     Combine Result objects.
        Note that the qobj id of the returned result will be the same as the
        first result.
     Arg:
        other (Result): a Result object to combine.
     Returns:
        A new Result object consisting of combined objects.
     */
    public static func + (left: Result, right: Result) throws -> Result {
        var ret =  Result(left.__result, left.__qobj)
        try ret += right
        return ret
    }

    public func is_error() -> Bool {
        if let status = self.__result["status"] as? String {
            return status == "ERROR"
        }
        return false
    }

    /**
     Get the status of the run.
     Returns:
     the status of the results.
     */
    public func get_status() -> String? {
        guard let status = self.__result["status"] as? String else {
            return nil
        }
        return status
    }

    /**
     Return statuses of all circuits

     Return:
     List of status result strings.
     */
    public func circuit_statuses() -> [String] {
        var ret: [String] = []
        if let results = self.__result["result"] as? [[String:Any]] {
            for result in results {
                if let status = result["status"] as? String {
                    ret.append(status)
                }
            }
        }
        return ret
    }

    /**
     Return the status of circuit at index icircuit.

     Args:
     icircuit (int): index of circuit
     */
    public func get_circuit_status(icircuit: Int) -> String? {
        if let results = self.__result["result"] as? [[String:Any]] {
            if !results.isEmpty && icircuit >= 0 && icircuit < results.count {
                if let status = results[icircuit]["status"] as? String {
                    return status
                }
            }
        }
        return nil
    }

    public func get_error() -> String {
        if self.is_error() {
            if let result = self.__result["result"] as? String {
                return result
            }
        }
        return ""
    }

    /**
     Get the ran qasm for the named circuit and backend.
     Args:
     name (str): the name of the quantum circuit.
     Returns:
     A text version of the qasm file that has been run
     */
    public func get_ran_qasm(_ name: String) throws -> String {
        let qobj = self.__qobj
        if let circuits = qobj["circuits"] as? [[String:Any]] {
            for circuit in circuits {
                if let n = circuit["name"] as? String {
                    if n == name {
                        if let ret = circuit["compiled_circuit_qasm"] as? String {
                            return ret
                        }
                    }
                }
            }
        }
        throw QISKitError.noQASM(name: name)
    }

    /**
     "Get the data of cicuit name.
     The data format will depend on the backend. For a real device it
     will be for the form::
     "counts": {’00000’: XXXX, ’00001’: XXXX},
     "time"  : xx.xxxxxxxx
     for the qasm simulators of 1 shot::
     'quantum_state': array([ XXX,  ..., XXX]),
     'classical_state': 0
     for the qasm simulators of n shots::
     'counts': {'0000': XXXX, '1001': XXXX}
     for the unitary simulators::
     'unitary': np.array([[ XX + XXj
     ...
     XX + XX]
     ...
     [ XX + XXj
     ...
     XX + XXj]]
     Args:
     name (str): the name of the quantum circuit.
     Returns:
     A dictionary of data for the different backends
     */
    public func get_data(_ name: String) throws -> [String:Any] {
        let qobj = self.__qobj
        if let circuits = qobj["circuits"] as? [[String:Any]], 
            let results = self.__result["result"] as? [[String:Any]] {
            for (index, circuit) in circuits.enumerated() {
                if let n = circuit["name"] as? String {
                    if n == name {
                        if let data = results[index]["data"] as? [String:Any] {
                            return data
                        }
                    }
                }
            }
        }
        throw QISKitError.noData(name: name)
    }

    /**
     Get the histogram data of cicuit name.
     The data from the a qasm circuit is dictionary of the format
     {’00000’: XXXX, ’00001’: XXXXX}.
     Args:
     name (str): the name of the quantum circuit.
     backend (str): the name of the backend the data was run on.
     Returns:
     A dictionary of counts {’00000’: XXXX, ’00001’: XXXXX}.
     */
    public func get_counts(_ name: String) throws -> [String:Int] {
        if let counts = try self.get_data(name)["counts"] as? [String:Int] {
            return counts
        }
        throw QISKitError.noCounts(name: name)
    }

    /**
     Get the circuit names of the results.

     Returns:
     A list of circuit names.
     */
    public func get_names() -> [String] {
        var names: [String] = []
        if let circuits = self.__qobj["circuits"] as? [[String:Any]] {
            for circuit in circuits {
                if let name = circuit["name"] as? String {
                    names.append(name)
                }
            }
        }
        return names
    }

    /**
     Compute the mean value of an diagonal observable.
     Takes in an observable in dictionary format and then
     calculates the sum_i value(i) P(i) where value(i) is the value of
     the observable for state i.
     Args:
     name (str): the name of the quantum circuit
     observable (dict): The observable to be averaged over. As an example
     ZZ on qubits equals {"00": 1, "11": 1, "01": -1, "10": -1}
     Returns:
     a double for the average of the observable
     */
    public func average_data(_ name: String, _ observable: [String:Int]) throws -> Double {
        let counts = try self.get_counts(name)
        var tot: Double = 0
        for (_,countValue) in counts {
            tot += Double(countValue)
        }
        var temp: Double = 0
        for (key,countValue) in counts {
            if let value = observable[key] {
                temp += Double(countValue) * Double(value) / tot
            }
        }
        return temp
    }

    /**
     Compute the polarization of each qubit for all circuits and pull out each circuits
     xval into an array. Assumes that each circuit has the same number of qubits and that
     all qubits are measured.

     Args:
     xvals_dict: dictionary of xvals for each circuit {'circuitname1': xval1,...}. If this
     is none then the xvals list is just left as an array of zeros

     Returns:
     qubit_pol: mxn double array where m is the number of circuit, n the number of qubits
     xvals: mx1 array of the circuit xvals
     */
    public func get_qubitpol_vs_xval(_ xvals_dict: [String:Double]? = nil) throws -> ([[Double]],[Double]) {
        guard let circuits = self.__qobj["circuits"] as? [[String:Any]] else {
            return ([],[])
        }
        if circuits.isEmpty {
            return ([],[])
        }
        let ncircuits = circuits.count
        //Is this the best way to get the number of qubits?
        guard let compiled_circuit = circuits[0]["compiled_circuit"] as? [String:Any] else {
            return ([],[])
        }
        guard let header = compiled_circuit["header"] as? [String:Any] else {
            return ([],[])
        }
        guard let nqubits = header["number_of_qubits"] as? Int else {
            return ([],[])
        }
        var qubitpol: [[Double]] = [[Double]](repeating: [Double](repeating: 0.0, count: nqubits), count: ncircuits)
        var xvals: [Double] = [Double](repeating: 0.0, count: ncircuits)

        //build Z operators for each qubit
        var z_dicts:[[String:Int]] = []
        for qubit_ind in 0..<nqubits {
            z_dicts.append([:])
            for qubit_state in 0..<Int(pow(2.0,Double(nqubits))) {
                let binaryString = String(qubit_state, radix: 2)
                let new_key = String(repeating: "0", count: nqubits - binaryString.characters.count) + binaryString
                z_dicts[z_dicts.count-1][new_key] = -1
                let index = new_key.index(new_key.startIndex, offsetBy: nqubits - qubit_ind - 1)
                if new_key[index] == "1" {
                    z_dicts[z_dicts.count-1][new_key] = 1
                }
            }
        }
        //go through each circuit and for eqch qubit and apply the operators using "average_data"
        for circuit_ind in 0..<ncircuits {
            if let name = circuits[circuit_ind]["name"] as? String {
                if let dict = xvals_dict,
                    let val = dict[name] {
                    xvals[circuit_ind] = val
                }
                for qubit_ind in 0..<nqubits {
                    qubitpol[circuit_ind][qubit_ind] = try self.average_data(name, z_dicts[qubit_ind])
                }
            }
        }
        return (qubitpol,xvals)
    }
}
