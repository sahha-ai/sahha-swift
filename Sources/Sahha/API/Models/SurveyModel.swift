// Copyright © 2022 Sahha. All rights reserved.

import Foundation

public struct SahhaSurveyQuestion: Encodable {
    public var question: String
    public var answer: String
    
    public init(question: String, answer: String) {
        self.question = question
        self.answer = answer
    }
}

public struct SahhaSurvey: Encodable {
    public var surveyType: String
    public var questions: [SahhaSurveyQuestion]
    public var startDateTime: String
    public var endDateTime: String
    public var createdAt: String
    
    public init(surveyType: String, questions: [SahhaSurveyQuestion], startDate: Date = Date(), endDate: Date = Date()) {
        self.surveyType = surveyType
        self.questions = questions
        self.startDateTime = startDate.toDateTime
        self.endDateTime = endDate.toDateTime
        self.createdAt = Date().toDateTime
    }
}
