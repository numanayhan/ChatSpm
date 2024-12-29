//
// Copyright 2023 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
public import LibSignalClient

public enum WhoAmIRequestFactory {

    public enum Responses {

        public struct WhoAmI: Decodable {
            private enum CodingKeys: String, CodingKey {
                case aci = "uuid"
                case pni
                case e164 = "number"
                case usernameHash
            }

            @AciUuid public var aci: Aci
            @PniUuid public var pni: Pni
            public let e164: E164
            public let usernameHash: String?
        }

        public enum AmIDeregistered: Int, UnknownEnumCodable {
            case notDeregistered = 200
            case deregistered = 401
            case unexpectedError = -1

            static public var unknown: Self { .unexpectedError }
        }
    }

    /// Response body should be a `Responses.WhoAmI` json.
    public static func whoAmIRequest(
        auth: ChatServiceAuth
    ) -> TSRequest {
        let urlPathComponents = URLPathComponents(
            ["v1", "accounts", "whoami"]
        )
        var urlComponents = URLComponents()
        urlComponents.percentEncodedPath = urlPathComponents.percentEncoded
        let url = urlComponents.url!

        let result = TSRequest(url: url, method: "GET", parameters: [:])
        result.shouldHaveAuthorizationHeaders = true
        result.setAuth(auth)
        return result
    }

    /// Usage of this request is limited to checking if the account is deregistered via REST.
    /// This means the result contents are irrelevant; all that matters is if we get a 200, 401, or something else.
    /// See `Responses.AmIDeregistered`
    public static func amIDeregisteredRequest() -> TSRequest {
        let urlPathComponents = URLPathComponents(
            ["v1", "accounts", "whoami"]
        )
        var urlComponents = URLComponents()
        urlComponents.percentEncodedPath = urlPathComponents.percentEncoded
        let url = urlComponents.url!

        let result = TSRequest(url: url, method: "GET", parameters: [:])
        result.shouldHaveAuthorizationHeaders = true
        // As counterintuitive as this is, we want this flag to be false.
        // (As of writing, it defaults to false anyway, but we want to be sure).
        // This flag is what tells us to make _this_ request to check for
        // de-registration, so we don't want to loop forever.
        result.shouldCheckDeregisteredOn401 = false
        return result
    }
}
