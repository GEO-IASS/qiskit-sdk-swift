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

final class Request {

    private static let HTTPSTATUSOK: Int = 200
    private static let REACHTIMEOUT: TimeInterval = 90.0
    private static let CONNTIMEOUT: TimeInterval = 120.0
    private static let HEADER_CLIENT_APPLICATION = "x-qx-client-application"

    let credential: Credentials
    private var urlSession: URLSession
    private let retries: Int
    private let timeout_interval: Double

    init(_ token: String?,
         _ config: Qconfig? = nil,
         _ retries: Int = 5,
         _ timeout_interval: TimeInterval = 1.0) throws {
        self.credential = try Credentials(token, config)
        self.retries = retries
        self.timeout_interval = timeout_interval
        if self.retries < 0 {
            throw IBMQuantumExperienceError.retriesPositive
        }
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.allowsCellularAccess = true
        sessionConfig.timeoutIntervalForRequest = Request.REACHTIMEOUT
        sessionConfig.timeoutIntervalForResource = Request.CONNTIMEOUT
        self.urlSession = URLSession(configuration: sessionConfig)
    }

    func initialize(responseHandler: @escaping ((_:Request, _:IBMQuantumExperienceError?) -> Void)) {
        self.credential.initialize(self) { (error) -> Void in
            responseHandler(self,error)
        }
    }

    /**
     Check is the user's token is valid
     */
    private func check_token(_ error: IBMQuantumExperienceError?,
                             responseHandler: @escaping ((_:Bool, _:IBMQuantumExperienceError?) -> Void)) {
        if error != nil {
            if case IBMQuantumExperienceError.httpError(let status, _) = error! {
                if status == 401 {
                    self.credential.obtain_token(self) { (error) -> Void in
                        responseHandler(true,error)
                    }
                    return
                }
            }
        }
        responseHandler(false,error)
    }

    func post(path: String,
              params: String = "",
              data: [String : Any] = [:],
              responseHandler: @escaping ((_:Any?, _:IBMQuantumExperienceError?) -> Void)) {
        self.postRetry(path: path, params: params, data: data, retries: self.retries, responseHandler: responseHandler)
    }

    private func postRetry(path: String,
              params: String,
              data: [String : Any],
              retries: Int,
              responseHandler: @escaping ((_:Any?, _:IBMQuantumExperienceError?) -> Void)) {
        self.postWithCheckToken(path: path, params: params, data: data) { (json, error) in
            if error != nil {
                if retries > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + self.timeout_interval) {
                        self.postRetry(path: path, params: params, data: data, retries: retries-1,responseHandler: responseHandler)
                    }
                    return
                }
            }
            DispatchQueue.main.async {
                responseHandler(json, error)
            }
        }
    }

    private func postWithCheckToken(path: String,
                                    params: String,
                                    data: [String : Any],
                                    responseHandler: @escaping ((_:Any?, _:IBMQuantumExperienceError?) -> Void)) {
        self.postInternal(path: path, params: params, data: data) { (json, error) in
            self.check_token(error) { (postAgain, error) in
                if error != nil {
                    responseHandler(nil, error)
                    return
                }
                if !postAgain {
                    responseHandler(json, error)
                    return
                }
                self.postInternal(path: path, params: params, data: data) { (json, error) in
                    responseHandler(json, error)
                }
            }
        }
    }

    private func postInternal(path: String,
                              params: String = "",
                              data: [String : Any] = [:],
                              responseHandler: @escaping ((_:Any?, _:IBMQuantumExperienceError?) -> Void)) {
        guard let token = self.credential.get_token() else {
            responseHandler(nil, IBMQuantumExperienceError.missingTokenId)
            return
        }
        let fullPath = "\(path)?access_token=\(token)\(params)"
        guard let url = URL(string: fullPath, relativeTo: self.credential.config.url) else {
            responseHandler(nil,
                    IBMQuantumExperienceError.invalidURL(url: "\(self.credential.config.url.description)\(fullPath)"))
            return
        }
        postInternal(url: url, data: data, responseHandler: responseHandler)
    }

    func postInternal(url: URL,
                      data: [String : Any] = [:],
                      responseHandler: @escaping ((_:Any?, _:IBMQuantumExperienceError?) -> Void)) {
        //print(url.absoluteString)
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData,
                                 timeoutInterval: Request.CONNTIMEOUT)
        request.httpMethod = "POST"
        request.addValue(self.credential.config.client_application, forHTTPHeaderField: Request.HEADER_CLIENT_APPLICATION)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
            //let dataString = String(data: request.httpBody!, encoding: .utf8)
            //print(dataString!)
        } catch let error {
            DispatchQueue.main.async {
                responseHandler(nil, IBMQuantumExperienceError.internalError(error: error))
            }
            return
        }
        let task = self.urlSession.dataTask(with: request) { (data, response, error) -> Void in
            if error != nil {
                DispatchQueue.main.async {
                    responseHandler(nil, IBMQuantumExperienceError.internalError(error: error!))
                }
                return
            }
            if response == nil {
                DispatchQueue.main.async {
                    responseHandler(nil, IBMQuantumExperienceError.nullResponse(url: url.absoluteString))
                }
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    responseHandler(nil, IBMQuantumExperienceError.invalidHTTPResponse(response: response!))
                }
                return
            }
            if data == nil {
                DispatchQueue.main.async {
                    responseHandler(nil, IBMQuantumExperienceError.nullResponseData(url: url.absoluteString))
                }
                return
            }
            do {
                //if let dataString = String(data: data!, encoding: .utf8) {
                //   print(dataString)
                //}
                let jsonAny = try JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                var msg = ""
                if let json = jsonAny as? [String:Any] {
                    if let errorObj = json["error"] as? [String:Any] {
                        if let status = errorObj["status"] as? Int {
                            msg.append("Status: \(status)")
                        }
                        if let code = errorObj["code"] as? String {
                            msg.append("; Code: \(code)")
                        }
                        if let message = errorObj["message"] as? String {
                            msg.append("; Msg: \(message)")
                        }
                    }
                }
                if httpResponse.statusCode != Request.HTTPSTATUSOK {
                    DispatchQueue.main.async {
                        responseHandler(nil, IBMQuantumExperienceError.httpError(status: httpResponse.statusCode, msg: msg))
                    }
                    return
                }
                DispatchQueue.main.async {
                    responseHandler(jsonAny, nil)
                }
            } catch let error {
                DispatchQueue.main.async {
                    responseHandler(nil, IBMQuantumExperienceError.internalError(error: error))
                }
            }
        }
        task.resume()
    }

    func put(path: String,
              params: String = "",
              data: [String : Any] = [:],
              responseHandler: @escaping ((_:Any?, _:IBMQuantumExperienceError?) -> Void)) {
        self.putRetry(path: path, params: params, data: data, retries: self.retries, responseHandler: responseHandler)
    }

    private func putRetry(path: String,
                           params: String,
                           data: [String : Any],
                           retries: Int,
                           responseHandler: @escaping ((_:Any?, _:IBMQuantumExperienceError?) -> Void)) {
        self.putWithCheckToken(path: path, params: params, data: data) { (json, error) in
            if error != nil {
                if retries > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + self.timeout_interval) {
                        self.putRetry(path: path, params: params, data: data, retries: retries-1,responseHandler: responseHandler)
                    }
                    return
                }
            }
            DispatchQueue.main.async {
                responseHandler(json, error)
            }
        }
    }

    private func putWithCheckToken(path: String,
                                    params: String,
                                    data: [String : Any],
                                    responseHandler: @escaping ((_:Any?, _:IBMQuantumExperienceError?) -> Void)) {
        self.putInternal(path: path, params: params, data: data) { (json, error) in
            self.check_token(error) { (putAgain, error) in
                if error != nil {
                    responseHandler(nil, error)
                    return
                }
                if !putAgain {
                    responseHandler(json, error)
                    return
                }
                self.putInternal(path: path, params: params, data: data) { (json, error) in
                    responseHandler(json, error)
                }
            }
        }
    }

    private func putInternal(path: String,
                              params: String = "",
                              data: [String : Any] = [:],
                              responseHandler: @escaping ((_:Any?, _:IBMQuantumExperienceError?) -> Void)) {
        guard let token = self.credential.get_token() else {
            responseHandler(nil, IBMQuantumExperienceError.missingTokenId)
            return
        }
        let fullPath = "\(path)?access_token=\(token)\(params)"
        guard let url = URL(string: fullPath, relativeTo: self.credential.config.url) else {
            responseHandler(nil,
                            IBMQuantumExperienceError.invalidURL(url: "\(self.credential.config.url.description)\(fullPath)"))
            return
        }
        putInternal(url: url, data: data, responseHandler: responseHandler)
    }

    private func putInternal(url: URL,
                      data: [String : Any] = [:],
                      responseHandler: @escaping ((_:Any?, _:IBMQuantumExperienceError?) -> Void)) {
        //print(url.absoluteString)
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData,
                                 timeoutInterval: Request.CONNTIMEOUT)
        request.httpMethod = "PUT"
        request.addValue(self.credential.config.client_application, forHTTPHeaderField: Request.HEADER_CLIENT_APPLICATION)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
            //let dataString = String(data: request.httpBody!, encoding: .utf8)
            //print(dataString!)
        } catch let error {
            DispatchQueue.main.async {
                responseHandler(nil, IBMQuantumExperienceError.internalError(error: error))
            }
            return
        }
        let task = self.urlSession.dataTask(with: request) { (data, response, error) -> Void in
            if error != nil {
                responseHandler(nil, IBMQuantumExperienceError.internalError(error: error!))
                return
            }
            if response == nil {
                responseHandler(nil, IBMQuantumExperienceError.nullResponse(url: url.absoluteString))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                responseHandler(nil, IBMQuantumExperienceError.invalidHTTPResponse(response: response!))
                return
            }
            if data == nil {
                responseHandler(nil, IBMQuantumExperienceError.nullResponseData(url: url.absoluteString))
                return
            }
            do {
                //if let dataString = String(data: data!, encoding: .utf8) {
                //   print(dataString)
                //}
                let jsonAny = try JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                var msg = ""
                if let json = jsonAny as? [String:Any] {
                    if let errorObj = json["error"] as? [String:Any] {
                        if let status = errorObj["status"] as? Int {
                            msg.append("Status: \(status)")
                        }
                        if let code = errorObj["code"] as? String {
                            msg.append("; Code: \(code)")
                        }
                        if let message = errorObj["message"] as? String {
                            msg.append("; Msg: \(message)")
                        }
                    }
                }
                if httpResponse.statusCode != Request.HTTPSTATUSOK {
                    responseHandler(nil, IBMQuantumExperienceError.httpError(status: httpResponse.statusCode, msg: msg))
                    return
                }
                responseHandler(jsonAny, nil)
            } catch let error {
                responseHandler(nil, IBMQuantumExperienceError.internalError(error: error))
            }
        }
        task.resume()
    }

    func get(path: String, params: String = "", with_token: Bool = true,
             responseHandler: @escaping ((_:Any?, _:IBMQuantumExperienceError?) -> Void)) {
        self.getRetry(path: path, params: params, with_token: with_token, retries: self.retries, responseHandler: responseHandler)
    }

    private func getRetry(path: String,
                          params: String,
                          with_token: Bool,
                          retries: Int,
                          responseHandler: @escaping ((_:Any?, _:IBMQuantumExperienceError?) -> Void)) {
        self.getWithCheckToken(path: path, params: params, with_token: with_token) { (json, error) in
            if error != nil {
                if retries > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + self.timeout_interval) {
                        self.getRetry(path: path, params: params, with_token: with_token, retries: retries-1,responseHandler: responseHandler)
                    }
                    return
                }
            }
            DispatchQueue.main.async {
                responseHandler(json, error)
            }
        }
    }

    private func getWithCheckToken(path: String,
                                   params: String,
                                   with_token: Bool,
                                   responseHandler: @escaping ((_:Any?, _:IBMQuantumExperienceError?) -> Void)) {
        self.getInternal(path: path, params: params, with_token: with_token) { (json, error) in
            self.check_token(error) { (retry, error) in
                if error != nil {
                    responseHandler(nil, error)
                    return
                }
                if !retry {
                    responseHandler(json, error)
                    return
                }
                self.getInternal(path: path, params: params, with_token: with_token) { (json, error) in
                    responseHandler(json, error)
                }
            }
        }
    }

    private func getInternal(path: String,
                             params: String,
                             with_token: Bool,
                             responseHandler: @escaping ((_:Any?, _:IBMQuantumExperienceError?) -> Void)) {
        var access_token = ""
        if with_token {
            if let token = self.credential.get_token() {
                access_token = "?access_token=\(token)"
            }
            else {
                responseHandler(nil, IBMQuantumExperienceError.missingTokenId)
                return
            }
        }
        let fullPath = "\(path)\(access_token)\(params)"
        guard let url = URL(string: fullPath, relativeTo:self.credential.config.url) else {
            responseHandler(nil,
                IBMQuantumExperienceError.invalidURL(url: "\(self.credential.config.url.description)\(fullPath)"))
            return
        }
        //print(url.absoluteString)
        var request = URLRequest(url:url, cachePolicy:.reloadIgnoringLocalCacheData,
                                 timeoutInterval:Request.CONNTIMEOUT)
        request.httpMethod = "GET"
        request.addValue(self.credential.config.client_application, forHTTPHeaderField: Request.HEADER_CLIENT_APPLICATION)
        let task = self.urlSession.dataTask(with: request) { (data, response, error) -> Void in
            if error != nil {
                responseHandler(nil, IBMQuantumExperienceError.internalError(error: error!))
                return
            }
            if response == nil {
                responseHandler(nil, IBMQuantumExperienceError.nullResponse(url: url.absoluteString))
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                responseHandler(nil, IBMQuantumExperienceError.invalidHTTPResponse(response: response!))
                return
            }
            if data == nil {
                responseHandler(nil, IBMQuantumExperienceError.nullResponseData(url: url.absoluteString))
                return
            }
            do {
               // if let dataString = String(data: data!, encoding: .utf8) {
                //    print(dataString)
                //}
                let jsonAny = try JSONSerialization.jsonObject(with: data!, options: .allowFragments)
                var msg = ""
                if let json = jsonAny as? [String:Any] {
                    if let errorObj = json["error"] as? [String:Any] {
                        if let status = errorObj["status"] as? Int {
                            msg.append("Status: \(status)")
                        }
                        if let code = errorObj["code"] as? String {
                            msg.append("; Code: \(code)")
                        }
                        if let message = errorObj["message"] as? String {
                            msg.append("; Msg: \(message)")
                        }
                    }
                }
                if httpResponse.statusCode != Request.HTTPSTATUSOK {
                    responseHandler(nil, IBMQuantumExperienceError.httpError(status: httpResponse.statusCode, msg: msg))
                    return
                }
                responseHandler(jsonAny, nil)
            } catch let error {
                responseHandler(nil, IBMQuantumExperienceError.internalError(error: error))
            }
        }
        task.resume()
    }
}
