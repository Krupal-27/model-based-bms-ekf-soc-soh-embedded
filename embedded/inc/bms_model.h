#ifndef BMS_MODEL_H
#define BMS_MODEL_H

#include <stdint.h>
#include <stdbool.h>

/* Core BMS/ECM State */
typedef struct {
    /* Core states */
    float soc;           /* State of Charge (0..1) */
    float v1;            /* RC polarization voltage (V) */
    float v_terminal;    /* Terminal voltage prediction (V) */

    /* Internal / debug */
    float i_prev;        /* Previous current (optional) */
    uint32_t step_count; /* Steps executed */
} BMS_State;

/* Initialize BMS state */
void BMS_Init(BMS_State *state);

/* One ECM step (fixed-step, no dynamic allocation)
   Sign convention:
     discharge: current < 0  -> SOC decreases
     charge:    current > 0  -> SOC increases
*/
void BMS_ECM_Step(BMS_State *state, float current, float dt);

/* Get terminal voltage prediction using current state */
float BMS_GetVoltage(const BMS_State *state, float current);

/* Coulomb counting SOC update only */
void BMS_UpdateCoulombCount(BMS_State *state, float current, float dt);

#endif