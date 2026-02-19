#include "bms_model.h"
#include "bms_config.h"
#include <math.h>
#include <stdio.h>

static float clampf(float x, float lo, float hi)
{
    if (x < lo) return lo;
    if (x > hi) return hi;
    return x;
}

/* Simple OCV model */
static float ocv_from_soc(float soc)
{
    soc = clampf(soc, SOC_MIN, SOC_MAX);
    return 3.2f + 1.0f * soc; /* SOC=0 -> 3.2V, SOC=1 -> 4.2V */
}

void BMS_Init(BMS_State *state)
{
    if (state == NULL) return;

    state->soc = 1.0f;
    state->v1 = 0.0f;
    state->v_terminal = ocv_from_soc(state->soc);
    state->i_prev = 0.0f;
    state->step_count = 0;
}

void BMS_ECM_Step(BMS_State *state, float current, float dt)
{
    if (state == NULL || dt <= 0.0f) return;

    /* Use Abs(I) for RC and IR drop */
    const float i_eff = fabsf(current);

    /* RC branch dynamics */
    const float tau = R1 * C1;  /* Time constant in seconds */
    
    /* Calculate alpha = exp(-dt/tau) */
    float alpha;
    if (tau > 1e-6f) {
        alpha = expf(-dt / tau);
    } else {
        alpha = 0.0f;
    }
    
    /* Update polarization voltage V1 */
    state->v1 = state->v1 * alpha + (i_eff * R1) * (1.0f - alpha);

    /* SOC coulomb counting */
    const float capacity_coulombs = NOMINAL_CAPACITY * 3600.0f;
    
    if (capacity_coulombs > 1e-12f) {
        float delta_soc = (current * dt) / capacity_coulombs;
        state->soc += delta_soc;
        if (state->soc < SOC_MIN) state->soc = SOC_MIN;
        if (state->soc > SOC_MAX) state->soc = SOC_MAX;
    }

    /* Terminal voltage: Vt = OCV - V1 - |I|*R0 */
    const float ocv = ocv_from_soc(state->soc);
    state->v_terminal = ocv - state->v1 - i_eff * R0;

    state->i_prev = current;
    state->step_count++;
}

float BMS_GetVoltage(const BMS_State *state, float current)
{
    if (state == NULL) return 0.0f;

    const float ocv = ocv_from_soc(state->soc);
    const float i_eff = fabsf(current);
    
    return ocv - state->v1 - i_eff * R0;
}

void BMS_UpdateCoulombCount(BMS_State *state, float current, float dt)
{
    if (state == NULL || dt <= 0.0f) return;

    const float capacity_coulombs = NOMINAL_CAPACITY * 3600.0f;
    if (capacity_coulombs > 1e-12f) {
        state->soc += (current * dt) / capacity_coulombs;
        state->soc = clampf(state->soc, SOC_MIN, SOC_MAX);
    }
}