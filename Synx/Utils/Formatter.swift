//
//  Formatter.swift
//  Synx
//
//  Created by Zifan Deng on 11/27/24.
//

import Foundation
import libPhoneNumber

class Formatter {
    private static var phoneUtil: NBPhoneNumberUtil? {
        return NBPhoneNumberUtil.sharedInstance()
    }
    
    // MARK: - Country Code Utilities
    
    /// A cache to store the country code mapping
    private static var countryCodeMapCache: [String: String]?
    
    /// Fetches a mapping of numeric country codes to ISO country codes using libPhoneNumber.
    /// - Returns: A dictionary of numeric country codes to ISO country codes.
    static func fetchCountryCodeMapping() -> [String: String] {
        // Return cached mapping if available
        if let cached = countryCodeMapCache {
            return cached
        }
        
        guard let phoneUtil = phoneUtil else {
            print("[Error] Phone number utility is unavailable.")
            return [:]
        }
        
        var mapping: [String: String] = [:]
        
        // Create mapping using known country codes
        let regions = [
            "US", "GB", "CA", "AU", "DE", "FR", "IT", "ES", "JP", "CN",
            "IN", "BR", "RU", "MX", "KR", "ID", "TR", "SA", "ZA", "NG",
            "EG", "PK", "BD", "VN", "PH", "TH", "MY", "SG", "AE", "IL",
            "CH", "SE", "NO", "DK", "FI", "NL", "BE", "IE", "PT", "GR",
            "PL", "CZ", "HU", "AT", "RO", "UA", "BY", "KZ", "UZ", "NZ"
        ]
        
        for region in regions {
            if let code = phoneUtil.getCountryCode(forRegion: region) {
                mapping[code.stringValue] = region
            } else {
                print("[Error] Failed to get country code for region \(region)")
            }
        }
        
        // Cache the mapping for future use
        countryCodeMapCache = mapping
        return mapping
    }
    
    /// Retrieves the numeric country code for a given ISO country code.
    /// - Parameter isoCode: The ISO 3166-1 alpha-2 country code (e.g., "US", "GB")
    /// - Returns: The numeric country code as a String, or nil if not found
    static func getNumericCode(forCountry isoCode: String) -> String? {
        guard let phoneUtil = phoneUtil else {
            print("[Error] Phone number utility is unavailable.")
            return nil
        }
        
        guard let code = phoneUtil.getCountryCode(forRegion: isoCode) else {
            print("[Error] Failed to get numeric code for \(isoCode)")
            return nil
        }
        
        return code.stringValue
    }
    
    /// Retrieves all supported country codes and their corresponding regions.
    /// - Returns: An array of tuples containing (numeric code, ISO code, country name)
    static func getAllCountryCodes() -> [(numericCode: String, isoCode: String, name: String)] {
        let mapping = fetchCountryCodeMapping()
        
        return mapping.compactMap { numericCode, isoCode in
            guard let countryName = Locale.current.localizedString(forRegionCode: isoCode) else {
                return nil
            }
            return (numericCode: numericCode, isoCode: isoCode, name: countryName)
        }.sorted { $0.name < $1.name }
    }
    
    /// Converts a numeric country code to an ISO 3166-1 alpha-2 country code.
    /// - Parameter numericCode: The numeric country code as a `String`.
    /// - Returns: The ISO country code as a `String` or `nil` if not found.
    static func numericToISOCode(_ numericCode: String) -> String? {
        return fetchCountryCodeMapping()[numericCode]
    }
    
    
    
    
    /// Formats a phone number to international format based on its numeric country code.
    /// - Parameters:
    ///   - rawNumber: The raw phone number as a `String`.
    ///   - numericCode: The numeric country code (e.g., `"1"` for US/Canada, `"44"` for UK).
    /// - Returns: A formatted phone number as a `String`, or `nil` if the number is invalid or phoneUtil is unavailable.
    static func formatPhoneNumber(_ rawNumber: String, numericCode: String) -> String? {
        guard let isoCode = numericToISOCode(numericCode) else {
            print("[Error] Invalid numeric country code: \(numericCode)")
            return nil
        }
        
        return formatPhoneNumber(rawNumber, forCountry: isoCode)
    }

    /// Formats a phone number to international format based on its ISO country code.
    /// - Parameters:
    ///   - rawNumber: The raw phone number as a `String`.
    ///   - countryCode: The ISO 3166-1 alpha-2 country code (e.g., "US", "GB"). Defaults to "US".
    /// - Returns: A formatted phone number as a `String`, or `nil` if the number is invalid or phoneUtil is unavailable.
    static func formatPhoneNumber(_ rawNumber: String, forCountry countryCode: String = "US") -> String? {
        guard let phoneUtil = phoneUtil else {
            print("[Error] Phone number utility is unavailable.")
            return nil
        }

        let cleanedNumber = rawNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        guard !cleanedNumber.isEmpty else {
            print("[Error] Phone number is empty or invalid.")
            return nil
        }

        do {
            // Parse the phone number
            let phoneNumber = try phoneUtil.parse(cleanedNumber, defaultRegion: countryCode)
            
            // Format to E.164 standard
            let formattedNumber = try phoneUtil.format(phoneNumber, numberFormat: .E164)
            return formattedNumber
        } catch let error as NSError {
            print("[Error] Failed to parse or format phone number: \(error.localizedDescription)")
            return nil
        }
    }

    
    
    
    /// Validates a phone number for a given numeric country code.
    /// - Parameters:
    ///   - rawNumber: The raw phone number as a `String`.
    ///   - numericCode: The numeric country code (e.g., `"1"`, `"44"`).
    /// - Returns: A `Bool` indicating whether the phone number is valid or `false` if phoneUtil is unavailable.
    static func isValidPhoneNumber(_ rawNumber: String, numericCode: String) -> Bool {
        guard let isoCode = numericToISOCode(numericCode) else {
            print("[Error] Invalid numeric country code: \(numericCode)")
            return false
        }
        
        return isValidPhoneNumber(rawNumber, forCountry: isoCode)
    }

    /// Validates a phone number for a given ISO country code.
    /// - Parameters:
    ///   - rawNumber: The raw phone number as a `String`.
    ///   - countryCode: The ISO 3166-1 alpha-2 country code (e.g., "US", "GB"). Defaults to "US".
    /// - Returns: A `Bool` indicating whether the phone number is valid or `false` if phoneUtil is unavailable.
    static func isValidPhoneNumber(_ rawNumber: String, forCountry countryCode: String = "US") -> Bool {
        guard let phoneUtil = phoneUtil else {
            print("[Error] Phone number utility is unavailable.")
            return false
        }

        let cleanedNumber = rawNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()

        guard !cleanedNumber.isEmpty else {
            print("[Error] Phone number is empty or invalid.")
            return false
        }

        do {
            let phoneNumber = try phoneUtil.parse(cleanedNumber, defaultRegion: countryCode)
            return phoneUtil.isValidNumber(phoneNumber)
        } catch let error as NSError {
            print("[Error] Failed to validate phone number: \(error.localizedDescription)")
            return false
        }
    }

    
    
    
    
    
    // MARK: - Email Utilities
    
    /// Formats an email address by trimming whitespace and converting to lowercase.
    /// - Parameter email: The raw email address as a `String`.
    /// - Returns: A formatted email address as a `String`, or `nil` if the email is invalid.
    static func formatEmail(_ email: String) -> String? {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Validate email format
        guard isValidEmail(trimmedEmail) else {
            print("[Error] Invalid email address.")
            return nil
        }
        
        return trimmedEmail
    }
    
    /// Validates an email address using a regular expression.
    /// - Parameter email: The email address as a `String`.
    /// - Returns: A `Bool` indicating whether the email address is valid.
    static func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}
