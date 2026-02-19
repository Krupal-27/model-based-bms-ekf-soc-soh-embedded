#ifndef SOH_ESTIMATOR_H_
#define SOH_ESTIMATOR_H_

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct
{
    /* Capacity estimates */
    float capacity_initial_Ah;  /* initial capacity (Ah), e.g. 1.862 */
    float capacity_est_Ah;       /* latest estimated capacity (Ah) */
    float soh_percent;           /* 0..100 */

    /* Cycle bookkeeping */
    uint32_t total_cycles;       /* number of completed discharge cycles */
    uint32_t cycles_since_update; /* cycles since last SOH update */

    /* Per-discharge-cycle accumulation */
    bool  is_charging;           /* true if charging, false if discharging */
    float discharged_Ah;         /* accumulated discharged Ah in current cycle */

    /* Tracking to help cycle end detection */
    float v_min_cycle;
    float v_max_cycle;
    
    /* Previous voltage for cycle detection */
    float prev_voltage;

} SOH_State;

/* Initialize with initial capacity (Ah) */
void SOH_Init(SOH_State *soh, float capacity_initial_Ah);

/*
  Call every fixed step.

  Sign convention:
    Discharge current < 0
*/
void SOH_Update(SOH_State *soh,
                float current_A,
                float voltage_V,
                float dt_s);

/*
  Check if cycle just completed
  Returns true exactly once when a discharge cycle completes.
*/
bool SOH_CheckCycleComplete(SOH_State *soh, float voltage);

/* Get SOH percentage (0..100) */
float SOH_GetPercentage(const SOH_State *soh);

/* Get estimated capacity (Ah) */
float SOH_GetCapacityAh(const SOH_State *soh);

#ifdef __cplusplus
}
#endif

#endif