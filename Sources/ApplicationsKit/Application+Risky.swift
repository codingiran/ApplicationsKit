//
//  Application+Risky.swift
//  ApplicationsKit
//
//  Created by CodingIran on 2025/4/2.
//

import Foundation

#if os(macOS)

    // MARK: - Risky Detection

    public extension Application {
        func codeSign() throws -> CodesignUtils.CodeSignInfo {
            let codeSign = try CodesignUtils.checkApplicationCodeSign(self)
            return codeSign
        }

        func checkRiskyCodeSign(_ codeSign: CodesignUtils.CodeSignInfo? = nil) -> Result<Void, RiskyReason> {
            do {
                let codeSign = try codeSign ?? self.codeSign()
                let authorities = codeSign.authorities
                guard let authorities, !authorities.isEmpty else {
                    // No authority
                    return .failure(.emptyAuthority)
                }
                let dangerousAuthority = authorities.first {
                    let lower = $0.lowercased()
                    return lower.contains("tnt") || lower.contains("hciso") || lower.contains("ediso")
                }
                if let dangerousAuthority, !dangerousAuthority.isEmpty {
                    return .failure(.dangerousAuthority(flag: String(dangerousAuthority)))
                }
                return .success(())
            } catch {
                return .failure(.codesignCheckFailed(error))
            }
        }

        enum RiskyReason: LocalizedError, Sendable {
            case codesignCheckFailed(Error? = nil)
            case emptyAuthority
            case dangerousAuthority(flag: String)
            case emptyTeamID

            public var errorDescription: String? {
                switch self {
                case let .codesignCheckFailed(error):
                    if let error {
                        return "Codesign Check Failed for \(error.localizedDescription)"
                    } else {
                        return "Codesign Check Failed"
                    }
                case .emptyAuthority:
                    return "Empty Authority"
                case let .dangerousAuthority(flag):
                    return "Dangerous Authority of \(flag)"
                case .emptyTeamID:
                    return "Empty Team ID"
                }
            }

            public var reason: String {
                switch self {
                case .codesignCheckFailed:
                    return "签名异常"
                case .emptyAuthority,
                     .emptyTeamID:
                    return "应用未鉴权"
                case let .dangerousAuthority(flag):
                    return "\(flag)破解软件"
                }
            }
        }
    }

    public extension Application {
        var isCodeSignedValid: Bool {
            let result = checkRiskyCodeSign()
            switch result {
            case .success:
                return true
            case .failure:
                return false
            }
        }

        var isRisky: Bool { !isCodeSignedValid }
    }

#endif
