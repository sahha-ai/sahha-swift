// Copyright © 2022 Sahha. All rights reserved.

import Foundation

public struct SahhaDemographic: Codable {
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
}
