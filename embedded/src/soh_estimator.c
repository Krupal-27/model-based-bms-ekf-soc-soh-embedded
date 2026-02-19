#include "soh_estimator.h"
#include "bms_config.h"
#include <math.h>
#include <stddef.h>

void SOH_Init(SOH_State *soh, float capacity_initial_Ah) {
    if (soh == NULL) return;
    
    soh->capacity_initial_Ah = capacity_initial_Ah;
    soh->capacity_est_Ah = capacity_initial_Ah;
    soh->soh_percent = 100.0f;
    
    soh->total_cycles = 0;
    soh->cycles_since_update = 0;
    soh->discharged_Ah = 0.0f;
    soh->is_charging = false;
    soh->v_min_cycle = 5.0f;
    soh->v_max_cycle = 0.0f;
    soh->prev_voltage = 5.0f;
}

void SOH_Update(SOH_State *soh, float current_A, float voltage_V, float dt_s) {
    if (soh == NULL || dt_s <= 0.0f) return;
    
    /* Track min/max voltage */
    if (voltage_V < soh->v_min_cycle) soh->v_min_cycle = voltage_V;
    if (voltage_V > soh->v_max_cycle) soh->v_max_cycle = voltage_V;
    
    /* Detect charge/discharge direction */
    bool was_charging = soh->is_charging;
    soh->is_charging = (current_A > 0.05f);
    
    /* Coulomb counting for discharge */
    if (!soh->is_charging && current_A < -0.05f) {
        soh->discharged_Ah += (-current_A) * dt_s / 3600.0f;
    }
    
    /* Cycle detection: charging -> discharging transition */
    if (was_charging && !soh->is_charging) {
        soh->v_min_cycle = voltage_V;
        soh->v_max_cycle = voltage_V;
    }
    
    /* Check for cycle completion */
    SOH_CheckCycleComplete(soh, voltage_V);
    
    soh->prev_voltage = voltage_V;
}

bool SOH_CheckCycleComplete(SOH_State *soh, float voltage) {
    if (soh == NULL) return false;
    
    bool cycle_complete = false;
    
    /* Detect end of discharge */
    if (!soh->is_charging && voltage <= VOLTAGE_MIN + 0.1f && voltage > soh->prev_voltage) {
        soh->total_cycles++;
        soh->cycles_since_update++;
        
        if (soh->discharged_Ah > 0.1f) {
            if (soh->cycles_since_update >= SOH_UPDATE_CYCLES) {
                float new_capacity = soh->discharged_Ah;
                soh->capacity_est_Ah = 0.9f * soh->capacity_est_Ah + 0.1f * new_capacity;
                soh->soh_percent = (soh->capacity_est_Ah / soh->capacity_initial_Ah) * 100.0f;
                soh->cycles_since_update = 0;
            }
            
            soh->discharged_Ah = 0.0f;
            soh->v_min_cycle = 5.0f;
            soh->v_max_cycle = 0.0f;
            cycle_complete = true;
        }
    }
    
    return cycle_complete;
}

float SOH_GetPercentage(const SOH_State *soh) {
    return (soh != NULL) ? soh->soh_percent : 0.0f;
}

float SOH_GetCapacityAh(const SOH_State *soh) {
    return (soh != NULL) ? soh->capacity_est_Ah : 0.0f;
}