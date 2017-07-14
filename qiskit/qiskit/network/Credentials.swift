//
//  Credentials.swift
//  qiskit
//
//  Created by Manoel Marques on 4/5/17.
//  Copyright © 2017 IBM. All rights reserved.
//

import Foundation

final class Credentials {

    /**
     Configuration setted to connect with QX Platform
     */
    let config: Qconfig
    private let token_unique: String
    private(set) var data_credentials: [String:Any] = [:]

    /**
     Get Authenticated Token to connect with QX Platform
     */
    var token: String? {
        return self.data_credentials["id"] as? String
    }
    /**
     Get User Id in QX Platform
     */
    var userId: String? {
        return self.data_credentials["userId"] as? String
    }

    init() throws {
        self.token_unique = ""
        self.config = try Qconfig()
    }
    
    init(_ token: String, _ config: Qconfig? = nil) throws {
        self.token_unique = token
        if let c = config {
            self.config = c
        }
        else {
            self.config = try Qconfig()
        }
    }

    func obtainToken(request: Request, responseHandler: @escaping ((_:IBMQuantumExperienceError?) -> Void)) {
        let path = "users/loginWithToken"
        guard let url = URL(string: path, relativeTo: self.config.url) else {
            DispatchQueue.main.async {
                responseHandler(IBMQuantumExperienceError.invalidURL(url: "\(self.config.url.description)/\(path)"))
            }
            return
        }
        request.postInternal(url: url, data: ["apiToken": self.token_unique]) { (out, error) -> Void in
            if error != nil {
                responseHandler(error)
                return
            }
            guard let json = out as? [String:Any] else {
                responseHandler(IBMQuantumExperienceError.invalidResponseData)
                return
            }
            self.data_credentials = json
            responseHandler(nil)
        }
    }
}
