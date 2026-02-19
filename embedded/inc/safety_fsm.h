#ifndef EMBEDDED_SAFETY_FSM_H_
#define EMBEDDED_SAFETY_FSM_H_

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>  /* for size_t */

#ifdef __cplusplus
extern "C" {
#endif

/* Operational states */
typedef enum {
    BMS_STATE_INIT = 0,
    BMS_STATE_NORMAL,
    BMS_STATE_CHARGING,
    BMS_STATE_DISCHARGING,
    BMS_STATE_FAULT,
    BMS_STATE_PROTECTION
} BMS_State_t;

/* Fault flags (bitmask) */
typedef enum {
    FAULT_NONE          = 0x00,
    FAULT_OVERVOLTAGE   = 0x01,
    FAULT_UNDERVOLTAGE  = 0x02,
    FAULT_OVERCURRENT   = 0x04,
    FAULT_OVERTEMP      = 0x08,
    FAULT_UNDERTEMP     = 0x10,
    FAULT_SOC_LOW       = 0x20,
    FAULT_SENSOR        = 0x40,
    FAULT_COMMS         = 0x80
} Fault_Flag_t;

/* Safety FSM */
typedef struct {
    BMS_State_t current_state;
    uint8_t fault_flags;

    uint32_t fault_start_time;
    uint32_t protection_count;

    /* Limits for current state (optional runtime limits) */
    float current_limit;   /* max allowed |current| */

    /* Timing */
    uint32_t state_entry_time;
    uint32_t current_time;
} Safety_FSM;

/* Initialize safety FSM */
void Safety_Init(Safety_FSM *fsm);

/* Run safety checks (call every step) */
void Safety_Check(Safety_FSM *fsm,
                  float voltage,
                  float current,
                  float temperature,
                  float soc);

/* Get current state */
BMS_State_t Safety_GetState(const Safety_FSM *fsm);

/* Human-readable fault string (NOT thread-safe; uses static buffer) */
const char* Safety_GetFaultString(uint8_t fault_flags);

/* Allowed to operate? */
bool Safety_IsOperationAllowed(const Safety_FSM *fsm);

#ifdef __cplusplus
}
#endif

#endif