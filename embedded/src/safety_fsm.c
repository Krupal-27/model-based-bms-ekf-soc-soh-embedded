#include "safety_fsm.h"
#include "bms_config.h"
#include <math.h>

static float absf(float x) { return (x < 0.0f) ? -x : x; }

void Safety_Init(Safety_FSM *fsm)
{
    if (!fsm) return;

    fsm->current_state = BMS_STATE_INIT;
    fsm->fault_flags   = FAULT_NONE;

    fsm->fault_start_time = 0u;
    fsm->protection_count = 0u;

    /* Default limits from config */
    fsm->current_limit = CURRENT_MAX;

    fsm->state_entry_time = 0u;
    fsm->current_time = 0u;
}

static void set_fault(Safety_FSM *fsm, uint8_t flag)
{
    if (!fsm) return;
    fsm->fault_flags |= flag;
}

static void clear_fault(Safety_FSM *fsm, uint8_t flag)
{
    if (!fsm) return;
    fsm->fault_flags &= (uint8_t)(~flag);
}

void Safety_Check(Safety_FSM *fsm,
                  float voltage,
                  float current,
                  float temperature,
                  float soc)
{
    if (!fsm) return;

    /* --- Fault detection --- */
    if (voltage > VOLTAGE_MAX) set_fault(fsm, FAULT_OVERVOLTAGE);
    else                        clear_fault(fsm, FAULT_OVERVOLTAGE);

    if (voltage < VOLTAGE_MIN) set_fault(fsm, FAULT_UNDERVOLTAGE);
    else                        clear_fault(fsm, FAULT_UNDERVOLTAGE);

    if (absf(current) > CURRENT_MAX) set_fault(fsm, FAULT_OVERCURRENT);
    else                              clear_fault(fsm, FAULT_OVERCURRENT);

    if (temperature > TEMP_MAX) set_fault(fsm, FAULT_OVERTEMP);
    else                         clear_fault(fsm, FAULT_OVERTEMP);

    if (temperature < TEMP_MIN) set_fault(fsm, FAULT_UNDERTEMP);
    else                         clear_fault(fsm, FAULT_UNDERTEMP);

    if (soc <= SOC_MIN + 1e-6f) set_fault(fsm, FAULT_SOC_LOW);
    else                         clear_fault(fsm, FAULT_SOC_LOW);

    /* --- State transitions --- */
    switch (fsm->current_state)
    {
        case BMS_STATE_INIT:
            fsm->current_state = (fsm->fault_flags == FAULT_NONE) ? BMS_STATE_NORMAL : BMS_STATE_FAULT;
            fsm->state_entry_time = fsm->current_time;
            break;

        case BMS_STATE_NORMAL:
        case BMS_STATE_CHARGING:
        case BMS_STATE_DISCHARGING:
            if (fsm->fault_flags != FAULT_NONE)
            {
                fsm->current_state = BMS_STATE_FAULT;
                fsm->fault_start_time = fsm->current_time;
                fsm->state_entry_time = fsm->current_time;
            }
            else
            {
                /* Optional: infer charging/discharging state from current sign */
                if (current > 0.05f)      fsm->current_state = BMS_STATE_CHARGING;
                else if (current < -0.05f)fsm->current_state = BMS_STATE_DISCHARGING;
                else                        fsm->current_state = BMS_STATE_NORMAL;
            }
            break;

        case BMS_STATE_FAULT:
            /* In fault: auto-recover when faults clear */
            if (fsm->fault_flags == FAULT_NONE)
            {
                fsm->current_state = BMS_STATE_PROTECTION;
                fsm->protection_count++;
                fsm->state_entry_time = fsm->current_time;
            }
            break;

        case BMS_STATE_PROTECTION:
            /* After protection, go back to NORMAL if still clean */
            if (fsm->fault_flags == FAULT_NONE)
            {
                fsm->current_state = BMS_STATE_NORMAL;
                fsm->state_entry_time = fsm->current_time;
            }
            else
            {
                fsm->current_state = BMS_STATE_FAULT;
                fsm->fault_start_time = fsm->current_time;
                fsm->state_entry_time = fsm->current_time;
            }
            break;

        default:
            fsm->current_state = BMS_STATE_FAULT;
            break;
    }
}

BMS_State_t Safety_GetState(const Safety_FSM *fsm)
{
    if (!fsm) return BMS_STATE_FAULT;
    return fsm->current_state;
}

bool Safety_IsOperationAllowed(const Safety_FSM *fsm)
{
    if (!fsm) return false;
    return (fsm->current_state != BMS_STATE_FAULT);
}

const char* Safety_GetFaultString(uint8_t fault_flags)
{
    if (fault_flags == FAULT_NONE) return "NONE";
    if (fault_flags & FAULT_OVERVOLTAGE)  return "OVERVOLTAGE";
    if (fault_flags & FAULT_UNDERVOLTAGE) return "UNDERVOLTAGE";
    if (fault_flags & FAULT_OVERCURRENT)  return "OVERCURRENT";
    if (fault_flags & FAULT_OVERTEMP)     return "OVERTEMP";
    if (fault_flags & FAULT_UNDERTEMP)    return "UNDERTEMP";
    if (fault_flags & FAULT_SOC_LOW)      return "SOC_LOW";
    if (fault_flags & FAULT_SENSOR)       return "SENSOR";
    if (fault_flags & FAULT_COMMS)        return "COMMS";
    return "UNKNOWN";
}
