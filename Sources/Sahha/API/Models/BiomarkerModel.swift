//
//  BiomarkerModel.swift
//  Sahha
//
//  Created by Hee-Min Chae on 26/11/2024.
//

import Foundation

public enum SahhaBiomarkerCategory: String {
    case activity
    case body
    case characteristic
    case reproductive
    case sleep
    case vitals
    case exercise
    case device
}

public enum SahhaBiomarkerType: String {
    case steps
    case floors_climbed
    case active_hours
    case active_duration
    case activity_low_intensity_duration
    case activity_mid_intensity_duration
    case activity_high_intensity_duration
    case activity_sedentary_duration
    case active_energy_burned
    case total_energy_burned
    case height
    case weight
    case body_mass_index
    case body_fat
    case fat_mass
    case lean_mass
    case waist_circumference
    case resting_energy_burned
    case age
    case biological_sex
    case date_of_birth
    case menstrual_cycle_length
    case menstrual_cycle_start_date
    case menstrual_cycle_end_date
    case menstrual_phase
    case menstrual_phase_start_date
    case menstrual_phase_end_date
    case menstrual_phase_length
    case sleep_start_time
    case sleep_end_time
    case sleep_duration
    case sleep_debt
    case sleep_interruptions
    case sleep_in_bed_duration
    case sleep_awake_duration
    case sleep_light_duration
    case sleep_rem_duration
    case sleep_deep_duration
    case sleep_regularity
    case sleep_latency
    case sleep_efficiency
    case heart_rate_resting
    case heart_rate_sleep
    case heart_rate_variability_sdnn
    case heart_rate_variability_rmssd
    case respiratory_rate
    case respiratory_rate_sleep
    case oxygen_saturation
    case oxygen_saturation_sleep
    case vo2_max
    case blood_glucose
    case blood_pressure_systolic
    case blood_pressure_diastolic
    case body_temperature_basal
    case skin_temperature_sleep
}
