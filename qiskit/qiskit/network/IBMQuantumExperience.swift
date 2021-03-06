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
 The Connector Class to do request to QX Platform
 */
public final class IBMQuantumExperience {

    private static let __names_backend_ibmqxv2 = Set<String>(["ibmqx5qv2", "ibmqx2", "qx5qv2", "qx5q", "real"])
    private static let __names_backend_ibmqxv3 = Set<String>(["ibmqx3"])
    private static let __names_backend_simulator = Set<String>(["simulator", "sim_trivial_2", "ibmqx_qasm_simulator"])

    private let token: String?
    private let config: Qconfig?
    private var request: Request? = nil

    /**
     Creates Quantum Experience object with a given configuration.
     
     - parameter token: API token
     - parameter config: Qconfig object
     */
    public init(_ token: String? = nil, _ config: Qconfig? = nil) throws {
        self.token = token
        self.config = config
    }

    private func getRequest(_ responseHandler: @escaping ((_:Request?, _:IBMQuantumExperienceError?) -> Void)) {
        if let req = self.request {
            responseHandler(req,nil)
            return
        }
        do {
            let req = try Request(self.token,self.config)
            req.initialize() { (request,error) -> Void in
                self.request = request
                responseHandler(self.request,error)
            }
        } catch let error as IBMQuantumExperienceError {
            responseHandler(nil,error)
        } catch {
            responseHandler(nil,IBMQuantumExperienceError.internalError(error: error))
        }
    }

    /**
     Check if the name of a backend is valid to run in QX Platform
     */
    private func _check_backend(_ back: String,
                                _ endpoint: String,
                                _ responseHandler: @escaping ((_:String?, _:IBMQuantumExperienceError?) -> Void)) {
        // First check against hacks for old backend names
        let original_backend = back
        let backend = back.lowercased()
        var ret: String? = nil
        if endpoint == "experiment" {
            if IBMQuantumExperience.__names_backend_ibmqxv2.contains(backend) {
                ret = "real"
            }
            else if IBMQuantumExperience.__names_backend_ibmqxv3.contains(backend) {
                ret = "ibmqx3"
            }
            else if IBMQuantumExperience.__names_backend_simulator.contains(backend) {
                ret = "sim_trivial_2"
            }
        }
        else if endpoint == "job" {
            if IBMQuantumExperience.__names_backend_ibmqxv2.contains(backend) {
                ret = "ibmqx2"
            }
            else if IBMQuantumExperience.__names_backend_ibmqxv3.contains(backend) {
                ret = "ibmqx3"
            }
            else if IBMQuantumExperience.__names_backend_simulator.contains(backend) {
                ret = "simulator"
            }
        }
        else if endpoint == "status" {
            if IBMQuantumExperience.__names_backend_ibmqxv2.contains(backend) {
                ret = "ibmqx2"
            }
            else if IBMQuantumExperience.__names_backend_ibmqxv3.contains(backend) {
                ret = "ibmqx3"
            }
            else if IBMQuantumExperience.__names_backend_simulator.contains(backend) {
                ret = "ibmqx_qasm_simulator"
            }
        }
        else if endpoint == "calibration" {
            if IBMQuantumExperience.__names_backend_ibmqxv2.contains(backend) {
                ret = "ibmqx2"
            }
            else if IBMQuantumExperience.__names_backend_ibmqxv3.contains(backend) {
                ret = "ibmqx3"
            }
            else if IBMQuantumExperience.__names_backend_simulator.contains(backend) {
                ret = "ibmqx_qasm_simulator"
            }
        }
        if ret != nil {
            responseHandler(ret,nil)
            return
        }
        // Check for new-style backends
        self.available_backends() { (backends,error) -> Void in
            if error != nil {
                responseHandler(nil,error)
                return
            }
            for backend in backends {
                guard let name = backend["name"] as? String else {
                    continue
                }
                if name != original_backend {
                    continue
                }
                if let simulator = backend["simulator"] as? Bool {
                    if simulator {
                        responseHandler("chip_simulator",nil)
                        return
                    }
                }
                responseHandler(original_backend,nil)
                return
            }
            // backend unrecognized
            responseHandler(nil,nil)
        }
    }

    /**
     Check if the user has permission in QX platform
     */
    public func check_credentials() -> Bool {
        if let req = self.request {
            return req.credential.get_token() != nil
        }
        return false
    }

    /**
     Gets execution information. Asynchronous.

     - parameter idExecution: execution identifier
     - parameter responseHandler: Closure to be called upon completion
     */
    public func get_execution(id_execution: String,
                              access_token: String? = nil,
                              user_id: String? = nil,
                              responseHandler: @escaping ((_:[String:Any]?, _:IBMQuantumExperienceError?) -> Void)) {
        self.getRequest() { (req,error) -> Void in
            if error != nil {
                responseHandler(nil, error)
                return
            }
            if let token = access_token {
                req!.credential.set_token(token)
            }
            if let user = user_id {
                req!.credential.set_user_id(user)
            }
            if !self.check_credentials() {
                responseHandler([:],IBMQuantumExperienceError.invalidCredentials)
                return
            }
            req!.get(path: "Executions/\(id_execution)") { (out, error) -> Void in
                if error != nil {
                    responseHandler(nil, error)
                    return
                }
                guard var execution = out as? [String:Any] else {
                    responseHandler(nil,IBMQuantumExperienceError.invalidResponseData)
                    return
                }
                guard let codeId = execution["codeId"] as? String else {
                    responseHandler(execution, error)
                    return
                }
                self.get_code(id_code: codeId) { (code, error) -> Void in
                    if error != nil {
                        responseHandler(nil, error)
                        return
                    }
                    execution["code"] = code
                    responseHandler(execution, error)
                }
            }
        }
    }

    /**
     Get the result of a execution, byt the execution id
     */
    public func get_result_from_execution(id_execution: String,
                                          access_token: String? = nil,
                                          user_id: String? = nil,
                                          responseHandler: @escaping ((_:[String:Any]?, _:IBMQuantumExperienceError?) -> Void)) {
        self.getRequest() { (req,error) -> Void in
            if error != nil {
                responseHandler(nil, error)
                return
            }
            if let token = access_token {
                req!.credential.set_token(token)
            }
            if let user = user_id {
                req!.credential.set_user_id(user)
            }
            if !self.check_credentials() {
                responseHandler([:],IBMQuantumExperienceError.invalidCredentials)
                return
            }
            req!.get(path: "Executions/\(id_execution)") { (out, error) -> Void in
                if error != nil {
                    responseHandler(nil, error)
                    return
                }
                guard let execution = out as? [String:Any] else {
                    responseHandler(nil,IBMQuantumExperienceError.invalidResponseData)
                    return
                }
                var result: [String:Any] = [:]
                if let executionResult = execution["result"] as? [String:Any] {
                    if let data =  executionResult["data"] as? [String:Any] {
                        if let p = data["p"] {
                            result["measure"] = p
                        }
                        if let valsxyz = data["valsxyz"] {
                            result["bloch"] = valsxyz
                        }
                        if let additionalData = data["additionalData"] {
                            result["extraInfo"] = additionalData
                        }
                        if let calibration = execution["calibration"] {
                            result["calibration"] = calibration
                        }
                        if let cregLabels = data["cregLabels"] {
                            result["creg_labels"] = cregLabels
                        }
                        if let time = data["time"] {
                            result["time_taken"] = time
                        }
                    }
                }
                if let calibration = execution["calibration"] as? [String:Any] {
                    result["calibration"] = calibration
                }
                responseHandler(result, error)
            }
        }
    }

    /**
     Get a code, by its id
     */
    public func get_code(id_code: String,
                         access_token: String? = nil,
                         user_id: String? = nil,
                         responseHandler: @escaping ((_:[String:Any]?, _:IBMQuantumExperienceError?) -> Void)) {
        self.getRequest() { (req,error) -> Void in
            if error != nil {
                responseHandler(nil, error)
                return
            }
            if let token = access_token {
                req!.credential.set_token(token)
            }
            if let user = user_id {
                req!.credential.set_user_id(user)
            }
            if !self.check_credentials() {
                responseHandler([:],IBMQuantumExperienceError.invalidCredentials)
                return
            }

            req!.get(path: "Codes/\(id_code)") { (out, error) -> Void in
                if error != nil {
                    responseHandler(nil, error)
                    return
                }
                guard var code = out as? [String:Any] else {
                    responseHandler(nil,IBMQuantumExperienceError.invalidResponseData)
                    return
                }
                req!.get(path:"Codes/\(id_code)/executions",
                params:"filter={\"limit\":3}") { (executions, error) -> Void in
                    if error != nil {
                        responseHandler(nil, error)
                        return
                    }
                    code["executions"] = executions
                    responseHandler(code, error)
                }
            }
        }
    }

    /**
     Get the image of a code, by its id
     */
    public func get_image_code(id_code: String,
                               access_token: String? = nil,
                               user_id: String? = nil,
                               responseHandler: @escaping ((_:[String:Any]?, _:IBMQuantumExperienceError?) -> Void)) {
        self.getRequest() { (req,error) -> Void in
            if error != nil {
                responseHandler(nil, error)
                return
            }
            if let token = access_token {
                req!.credential.set_token(token)
            }
            if let user = user_id {
                req!.credential.set_user_id(user)
            }
            if !self.check_credentials() {
                responseHandler([:],IBMQuantumExperienceError.invalidCredentials)
                return
            }

            req!.get(path: "Codes/\(id_code)/export/png/url") { (out, error) -> Void in
                if error != nil {
                    responseHandler(nil, error)
                    return
                }
                guard let image = out as? [String:Any] else {
                    responseHandler(nil,IBMQuantumExperienceError.invalidResponseData)
                    return
                }
                responseHandler(image, error)
            }
        }
    }

    /**
     Get the last codes of the user
     */
    public func get_last_codes(access_token: String? = nil,
                               user_id: String? = nil,
                               responseHandler: @escaping ((_:[String:Any]?, _:IBMQuantumExperienceError?) -> Void)) {
        self.getRequest() { (req,error) -> Void in
            if error != nil {
                responseHandler(nil, error)
                return
            }
            if let token = access_token {
                req!.credential.set_token(token)
            }
            if let user = user_id {
                req!.credential.set_user_id(user)
            }
            if !self.check_credentials() {
                responseHandler([:],IBMQuantumExperienceError.invalidCredentials)
                return
            }

            req!.get(path: "users/\(req!.credential.get_user_id()!)/codes/latest",
                         params: "&includeExecutions=true") { (out, error) -> Void in
                            if error != nil {
                                responseHandler(nil, error)
                                return
                            }
                            guard let result = out as? [String:Any] else {
                                responseHandler(nil,IBMQuantumExperienceError.invalidResponseData)
                                return
                            }
                            responseHandler(result["codes"] as? [String:Any], error)
            }
        }
    }

    /**
     Execute and experiment
     */
    public func run_experiment(qasm: String,
                               backend: String = "simulator",
                               shots: Int = 1,
                               name: String? = nil,
                               seed: Int? = nil,
                               timeout: Int = 60,
                               access_token: String? = nil,
                               user_id: String? = nil,
                               responseHandler: @escaping ((_:[String:Any]?, _:IBMQuantumExperienceError?) -> Void)) {
        self.getRequest() { (req,error) -> Void in
            if error != nil {
                responseHandler(nil, error)
                return
            }
            if let token = access_token {
                req!.credential.set_token(token)
            }
            if let user = user_id {
                req!.credential.set_user_id(user)
            }
            if !self.check_credentials() {
                responseHandler([:],IBMQuantumExperienceError.invalidCredentials)
                return
            }

            self._check_backend(backend, "experiment") { (backend_type,error) -> Void in
                if error != nil {
                    responseHandler(nil, error)
                    return
                }
                if backend_type == nil {
                    responseHandler(nil,IBMQuantumExperienceError.missingBackend(backend: backend))
                    return
                }
                if !IBMQuantumExperience.__names_backend_simulator.contains(backend) && seed != nil {
                    responseHandler(nil,IBMQuantumExperienceError.errorSeed(backend: backend))
                    return
                }
                var data: [String : Any] = [:]
                if let n = name {
                    data["name"] = n
                } else {
                    let date = Date()
                    let calendar = Calendar.current
                    let c = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
                    data["name"] = "Experiment #\(c.year!)\(c.month!)\(c.day!)\(c.hour!)\(c.minute!)\(c.second!))"

                }
                data["qasm"] = qasm.replacingOccurrences(of: "IBMQASM 2.0;", with: "").replacingOccurrences(of: "OPENQASM 2.0;", with: "")
                data["codeType"] = "QASM2"

                if seed != nil {
                    if String(seed!).characters.count >= 11 {
                        responseHandler(nil,IBMQuantumExperienceError.errorSeedLength)
                        return
                    }
                    req!.post(path: "codes/execute",
                                  params: "&shots=\(shots)&seed=\(seed!)&deviceRunType=\(backend_type!)",
                    data: data) { (out, error) -> Void in
                        guard let execution = out as? [String:Any] else {
                            responseHandler(nil,IBMQuantumExperienceError.invalidResponseData)
                            return
                        }
                        self.post_run_experiment(execution: execution,
                                                 error: error,
                                                 timeout: timeout,
                                                 access_token: access_token,
                                                 user_id: user_id,
                                                 responseHandler: responseHandler)
                    }
                }
                else {
                    req!.post(path: "codes/execute",
                                  params: "&shots=\(shots)&deviceRunType=\(backend_type!)",
                    data: data) { (out, error) -> Void in
                        guard let execution = out as? [String:Any] else {
                            responseHandler(nil,IBMQuantumExperienceError.invalidResponseData)
                            return
                        }
                        self.post_run_experiment(execution: execution,
                                                 error: error,
                                                 timeout: timeout,
                                                 access_token: access_token,
                                                 user_id: user_id,
                                                 responseHandler: responseHandler)
                    }
                }
            }
        }
    }

    private func post_run_experiment(execution: [String:Any],
                                     error:IBMQuantumExperienceError?,
                                     timeout: Int,
                                     access_token: String?,
                                     user_id: String?,
                                     responseHandler: @escaping ((_:[String:Any]?, _:IBMQuantumExperienceError?) -> Void)) {
        if error != nil {
            responseHandler(nil, error)
            return
        }
        var respond: [String:Any] = [:]
        guard let statusMap = execution["status"] as? [String:Any] else {
            responseHandler(nil, IBMQuantumExperienceError.missingStatus)
            return
        }
        guard let status = statusMap["id"] as? String else {
            responseHandler(nil, IBMQuantumExperienceError.missingStatus)
            return
        }
        //print("Status: \(status)")
        guard let id_execution = execution["id"] as? String else {
            responseHandler(nil, IBMQuantumExperienceError.missingExecutionId)
            return
        }
        var result: [String:Any] = [:]
        respond["status"] = status
        respond["idExecution"] = id_execution
        respond["idCode"] = execution["codeId"]
        if let infoQueue = execution["infoQueue"] as? [String:Any] {
            respond["infoQueue"] = infoQueue
        }

        if status == "DONE" {
            if let executionResult = execution["result"] as? [String:Any] {
                if let data =  executionResult["data"] as? [String:Any] {
                    if let additionalData = data["additionalData"] {
                        result["extraInfo"] = additionalData
                    }
                    if let p = data["p"] {
                        result["measure"] = p
                    }
                    if let valsxyz = data["valsxyz"] {
                        result["bloch"] = valsxyz
                    }
                    respond["result"] = result
                    respond.removeValue(forKey: "infoQueue")
                }
            }
            responseHandler(respond, nil)
            return
        }
        if status == "ERROR" {
            respond.removeValue(forKey: "infoQueue")
            responseHandler(respond, nil)
            return
        }
        //print("Waiting for results...")
        self.getCompleteResultFromExecution(id_execution: id_execution,
                                            timeOut: ((timeout > 300) ? 300 : timeout),
                                            access_token: access_token,
                                            user_id: user_id) { (out, error) in
            if error != nil {
                responseHandler(nil, error)
                return
            }
            if let result = out {
                respond["status"] = "DONE"
                respond["result"] = result
                if let calibration = result["calibration"] {
                    respond["calibration"] = calibration
                }
                respond.removeValue(forKey: "infoQueue")
            }
            responseHandler(respond, error)
        }
    }

    private func getCompleteResultFromExecution(id_execution: String,
                                                timeOut: Int,
                                                access_token: String?,
                                                user_id: String?,
                                                responseHandler: @escaping ((_:[String:Any]?, _:IBMQuantumExperienceError?) -> Void)) {
        self.getRequest() { (req,error) -> Void in
            if error != nil {
                responseHandler(nil, error)
                return
            }
            self.get_result_from_execution(id_execution: id_execution,
                                           access_token: access_token,
                                           user_id: user_id) { (execution, error) -> Void in
                if error != nil {
                    responseHandler(nil, error)
                    return
                }
                if timeOut <= 0 {
                    responseHandler(execution, error)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.getCompleteResultFromExecution(id_execution: id_execution,
                                                        timeOut: timeOut-1,
                                                        access_token: access_token,
                                                        user_id: user_id,
                                                        responseHandler: responseHandler)
                }
            }
        }
    }

    /**
     Runs a job. Asynchronous.
     */
    public func run_job(qasms: [[String:Any]],
                        backend: String = "simulator",
                        shots: Int = 1,
                        maxCredits: Int = 3,
                        seed: Int? = nil,
                        access_token: String? = nil,
                        user_id: String? = nil,
                        responseHandler: @escaping ((_:[String:Any]?, _:IBMQuantumExperienceError?) -> Void)) {

        self.getRequest() { (req,error) -> Void in
            if error != nil {
                responseHandler(nil, error)
                return
            }
            if let token = access_token {
                req!.credential.set_token(token)
            }
            if let user = user_id {
                req!.credential.set_user_id(user)
            }
            if !self.check_credentials() {
                responseHandler([:],IBMQuantumExperienceError.invalidCredentials)
                return
            }

            var data: [String : Any] = [:]
            var qasmArray: [[String:Any]] = []
            for var dict in qasms {
                if var value = dict["qasm"] as? String {
                    value = value.replacingOccurrences(of: "IBMQASM 2.0;", with: "")
                    dict["qasm"] = value.replacingOccurrences(of: "OPENQASM 2.0;", with: "") 
                }
                qasmArray.append(dict)
            }
            data["qasms"] = qasmArray 
            data["shots"] = shots 
            data["maxCredits"] = maxCredits

            self._check_backend(backend, "job") { (backend_type,error) -> Void in
                if error != nil {
                    responseHandler(nil, error)
                    return
                }
                if backend_type == nil {
                    responseHandler(nil,IBMQuantumExperienceError.missingBackend(backend: backend))
                    return
                }
                if !IBMQuantumExperience.__names_backend_simulator.contains(backend) && seed != nil {
                    responseHandler(nil,IBMQuantumExperienceError.errorSeed(backend: backend))
                    return
                }
                if seed != nil {
                    if String(seed!).characters.count >= 11 {
                        responseHandler(nil,IBMQuantumExperienceError.errorSeedLength)
                        return
                    }
                    data["seed"] = seed!
                }
                var backendDict: [String:String] = [:]
                backendDict["name"] = backend_type!
                data["backend"] = backendDict

                req!.post(path: "Jobs", data: data) { (out, error) -> Void in
                    if error != nil {
                        responseHandler(nil, error)
                        return
                    }
                    guard let json = out as? [String:Any] else {
                        responseHandler(nil,IBMQuantumExperienceError.invalidResponseData)
                        return
                    }
                    responseHandler(json, error)
                }

            }

        }
    }

    /**
     Gets job information. Asynchronous.

     - parameter jobId: job identifier
     - parameter responseHandler: Closure to be called upon completion
     */
    public func get_job(jobId: String,
                        access_token: String? = nil,
                        user_id: String? = nil,
                        responseHandler: @escaping ((_:[String:Any]?, _:IBMQuantumExperienceError?) -> Void)) {
        self.getRequest() { (req,error) -> Void in
            if error != nil {
                responseHandler(nil, error)
                return
            }
            if let token = access_token {
                req!.credential.set_token(token)
            }
            if let user = user_id {
                req!.credential.set_user_id(user)
            }
            if !self.check_credentials() {
                responseHandler([:],IBMQuantumExperienceError.invalidCredentials)
                return
            }
            req!.get(path: "Jobs/\(jobId)") { (out, error) -> Void in
                guard var job = out as? [String:Any] else {
                    responseHandler(nil,IBMQuantumExperienceError.invalidResponseData)
                    return
                }
                // To remove result object and add the attributes to data object
                if let qasms = job["qasms"] as? [[String:Any]] {
                    var new_qasms: [[String:Any]] = []
                    for qasm in qasms {
                        var new_qasm = qasm
                        if var result = new_qasm["result"] as? [String:Any] {
                            if var data = result["data"] as? [String:Any] {
                                new_qasm.removeValue(forKey:"result")
                                result.removeValue(forKey:"data")
                                for (key,value) in result {
                                    data[key] = value
                                }
                                new_qasm["data"] = data
                            }
                        }
                        new_qasms.append(new_qasm)
                    }
                    job["qasms"] = new_qasms
                }
                responseHandler(job, error)
            }
        }
    }

    /**
     Gets jobs information. Asynchronous.
     -limit: max result
     - parameter responseHandler: Closure to be called upon completion
     */
    public func get_jobs(limit: Int = 50,
                         access_token: String? = nil,
                         user_id: String? = nil,
                         responseHandler: @escaping ((_:[String:Any]?, _:IBMQuantumExperienceError?) -> Void)) {
        self.getRequest() { (req,error) -> Void in
            if error != nil {
                responseHandler(nil, error)
                return
            }
            if let token = access_token {
                req!.credential.set_token(token)
            }
            if let user = user_id {
                req!.credential.set_user_id(user)
            }
            if !self.check_credentials() {
                responseHandler([:],IBMQuantumExperienceError.invalidCredentials)
                return
            }
            req!.get(path: "Jobs", params: "&filter={\"limit\":\(limit)}") { (out, error) -> Void in
                guard let json = out as? [String:Any] else {
                    responseHandler(nil,IBMQuantumExperienceError.invalidResponseData)
                    return
                }
                responseHandler(json, error)
            }
        }
    }

    /**
     Get the status of a chip
     */
    public func backend_status(backend: String = "ibmqx4",
                               access_token: String? = nil,
                               user_id: String? = nil,
                               responseHandler: @escaping ((_:[String:Any]?, _:IBMQuantumExperienceError?) -> Void)) {
        self._check_backend(backend, "status") { (backend_type,error) -> Void in
            if error != nil {
                responseHandler(nil, error)
                return
            }
            if backend_type == nil {
                responseHandler(nil,IBMQuantumExperienceError.missingBackend(backend: backend))
                return
            }
            self.getRequest() { (req,error) -> Void in
                if error != nil {
                    responseHandler(nil, error)
                    return
                }
                req!.get(path:"Backends/\(backend_type!)/queue/status",with_token: false) { (out, error) -> Void in
                    guard let status = out as? [String:Any] else {
                        responseHandler(nil,IBMQuantumExperienceError.invalidResponseData)
                        return
                    }
                    var ret: [String:Any] = [:]
                    if let state = status["state"] as? Bool {
                        ret["available"] = state
                    }
                    if let busy = status["busy"] as? Bool {
                        ret["busy"] = busy
                    }
                    if let lengthQueue = status["lengthQueue"] {
                        ret["pending_jobs"] = lengthQueue
                    }
                    ret["backend"] = backend_type!
                    responseHandler(ret, error)
                }
            }
        }
    }

    /**
     Get the calibration of a real chip
     */
    public func backend_calibration(backend: String = "ibmqx4",
                                    access_token: String? = nil,
                                    user_id: String? = nil,
                                    responseHandler: @escaping ((_:[String:Any]?, _:IBMQuantumExperienceError?) -> Void)) {
        self.getRequest() { (req,error) -> Void in
            if error != nil {
                responseHandler(nil, error)
                return
            }
            if let token = access_token {
                req!.credential.set_token(token)
            }
            if let user = user_id {
                req!.credential.set_user_id(user)
            }
            if !self.check_credentials() {
                responseHandler([:],IBMQuantumExperienceError.invalidCredentials)
                return
            }
            self._check_backend(backend, "calibration") { (backend_type,error) -> Void in
                if error != nil {
                    responseHandler(nil, error)
                    return
                }
                if backend_type == nil {
                    responseHandler(nil,IBMQuantumExperienceError.missingBackend(backend: backend))
                    return
                }
                if IBMQuantumExperience.__names_backend_simulator.contains(backend_type!) {
                    responseHandler(["backend" : backend_type!],nil)
                    return
                }
                req!.get(path:"Backends/\(backend_type!)/calibration") { (out, error) -> Void in
                    if error != nil {
                        responseHandler(nil, error)
                        return
                    }
                    guard var ret = out as? [String:Any] else {
                        responseHandler(nil,IBMQuantumExperienceError.invalidResponseData)
                        return
                    }
                    ret["backend"] = backend_type!
                    responseHandler(ret,error)
                }
            }
        }
    }

    /**
     Get the parameters of calibration of a real chip
     */
    public func backend_parameters(backend: String = "ibmqx4",
                                   access_token: String? = nil,
                                   user_id: String? = nil,
                                  responseHandler: @escaping ((_:[String:Any]?, _:IBMQuantumExperienceError?) -> Void)) {
        self.getRequest() { (req,error) -> Void in
            if error != nil {
                responseHandler(nil, error)
                return
            }
            if let token = access_token {
                req!.credential.set_token(token)
            }
            if let user = user_id {
                req!.credential.set_user_id(user)
            }
            if !self.check_credentials() {
                responseHandler([:],IBMQuantumExperienceError.invalidCredentials)
                return
            }
            self._check_backend(backend, "calibration") { (backend_type,error) -> Void in
                if error != nil {
                    responseHandler(nil, error)
                    return
                }
                if backend_type == nil {
                    responseHandler(nil,IBMQuantumExperienceError.missingBackend(backend: backend))
                    return
                }
                if IBMQuantumExperience.__names_backend_simulator.contains(backend_type!) {
                    responseHandler(["backend" : backend_type!],nil)
                    return
                }
                req!.get(path:"Backends/\(backend_type!)/parameters") { (out, error) -> Void in
                    if error != nil {
                        responseHandler(nil, error)
                        return
                    }
                    guard var ret = out as? [String:Any] else {
                        responseHandler(nil,IBMQuantumExperienceError.invalidResponseData)
                        return
                    }
                    ret["backend"] = backend_type!
                    responseHandler(ret,error)
                }
            }
        }
    }

    /**
     Get the backends availables to use in the QX Platform
     */
    public func available_backends(access_token: String? = nil,
                                   user_id: String? = nil,
                                   responseHandler: @escaping ((_:[[String:Any]], _:IBMQuantumExperienceError?) -> Void)) {
        self.getRequest() { (req,error) -> Void in
            if error != nil {
                responseHandler([], error)
                return
            }
            if let token = access_token {
                req!.credential.set_token(token)
            }
            if let user = user_id {
                req!.credential.set_user_id(user)
            }
            if !self.check_credentials() {
                responseHandler([],IBMQuantumExperienceError.invalidCredentials)
                return
            }

            req!.get(path: "Backends") { (out, error) -> Void in
                if error != nil {
                    responseHandler([], error)
                    return
                }
                guard let backends = out as? [[String:Any]] else {
                    responseHandler([],IBMQuantumExperienceError.missingBackends)
                    return
                }
                var ret: [[String:Any]] = []
                for backend in backends {
                    if let status = backend["status"] as? String {
                        if "on" == status {
                            ret.append(backend)
                        }
                    }
                }
                responseHandler(ret, nil)
            }
        }
    }

    /**
     Get the backend simulators available to use in the QX Platform
     */
    public func available_backend_simulators(access_token: String? = nil,
                                             user_id: String? = nil,
                                             responseHandler: @escaping ((_:[[String:Any]], _:IBMQuantumExperienceError?) -> Void)) {
        self.available_backends(access_token: access_token,
                                user_id: user_id) { (backends,error) -> Void in
            if error != nil {
                responseHandler([], error)
                return
            }
            var ret: [[String:Any]] = []
            for backend in backends {
                if let simulator = backend["simulator"] as? Bool {
                    if simulator {
                        ret.append(backend)
                    }
                }
            }
            responseHandler(ret, nil)
        }
    }

    /**
     Get the the credits by user to use in the QX Platform
     */
    public func get_my_credits(access_token: String? = nil,
                               user_id: String? = nil,
                               responseHandler: @escaping ((_:[String:Any], _:IBMQuantumExperienceError?) -> Void)) {
        self.getRequest() { (req,error) -> Void in
            if error != nil {
                responseHandler([:], error)
                return
            }
            if let token = access_token {
                req!.credential.set_token(token)
            }
            if let user = user_id {
                req!.credential.set_user_id(user)
            }
            if !self.check_credentials() {
                responseHandler([:],IBMQuantumExperienceError.invalidCredentials)
                return
            }

            req!.get(path: "users/\(req!.credential.get_user_id()!)") { (out, error) -> Void in
                if error != nil {
                    responseHandler([:], error)
                    return
                }
                guard let user_data = out as? [String:Any] else {
                    responseHandler([:],IBMQuantumExperienceError.invalidResponseData)
                    return
                }
                if var credit = user_data["credit"] as? [String:Any] {
                    if credit["promotionalCodesUsed"] != nil {
                        credit.removeValue(forKey: "promotionalCodesUsed")
                    }
                    if credit["lastRefill"] != nil {
                        credit.removeValue(forKey: "lastRefill")
                    }
                    responseHandler(credit,nil)
                    return
                }
                responseHandler([:], nil)
            }
        }
    }
}
