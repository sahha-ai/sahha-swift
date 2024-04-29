// Copyright © 2022 Sahha. All rights reserved.

import Foundation

public struct SahhaDemographic: Codable, Equatable {
    public var age: Int?
    public var gender: String?
    public var country: String?
    public var birthCountry: String?
    public var ethnicity: String?
    public var occupation: String?
    public var industry: String?
    public var incomeRange: String?
    public var education: String?
    public var relationship: String?
    public var locale: String?
    public var livingArrangement: String?
    public var birthDate: String?

    public init(age: Int? = nil, gender: String? = nil, country: String? = nil, birthCountry: String? = nil, ethnicity: String? = nil, occupation: String? = nil, industry: String? = nil, incomeRange: String? = nil, education: String? = nil, relationship: String? = nil, locale: String? = nil, livingArrangement: String? = nil, birthDate: String? = nil) {
        self.age = age
        self.gender = gender
        self.country = country
        self.birthCountry = birthCountry
        self.ethnicity = ethnicity
        self.occupation = occupation
        self.industry = industry
        self.incomeRange = incomeRange
        self.education = education
        self.relationship = relationship
        self.locale = locale
        self.livingArrangement = livingArrangement
        self.birthDate = birthDate
    }
    
    public static func == (lhs: SahhaDemographic, rhs: SahhaDemographic) -> Bool {
        return lhs.age == rhs.age &&
        lhs.gender?.lowercased() == rhs.gender?.lowercased() &&
        lhs.country?.lowercased() == rhs.country?.lowercased() &&
        lhs.birthCountry?.lowercased() == rhs.birthCountry?.lowercased() &&
        lhs.ethnicity?.lowercased() == rhs.ethnicity?.lowercased() &&
        lhs.occupation?.lowercased() == rhs.occupation?.lowercased() &&
        lhs.industry?.lowercased() == rhs.industry?.lowercased() &&
        lhs.incomeRange?.lowercased() == rhs.incomeRange?.lowercased() &&
        lhs.education?.lowercased() == rhs.education?.lowercased() &&
        lhs.relationship?.lowercased() == rhs.relationship?.lowercased() &&
        lhs.locale?.lowercased() == rhs.locale?.lowercased() &&
        lhs.livingArrangement?.lowercased() == rhs.livingArrangement?.lowercased() &&
        lhs.birthDate?.lowercased() == rhs.birthDate?.lowercased()
    }
}
