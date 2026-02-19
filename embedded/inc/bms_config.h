
#ifndef BMS_CONFIG_H
#define BMS_CONFIG_H

/* ============= OPTIMAL PARAMETERS FROM SWEEP ============= */
#define R0               (0.100f)       /* Series resistance (Ohms) */
#define R1               (0.050f)       /* RC resistance (Ohms) */
#define C1               (400.0f)       /* RC capacitance (Farads) */
#define NOMINAL_CAPACITY (1.862f)       /* Nominal capacity (Ah) */

#define DT_CORE          (1.0f)         /* Time step (s) */

/* ============= SOC CLAMPS ============= */
#define SOC_MIN          (0.0f)
#define SOC_MAX          (1.0f)

/* ============= EKF PARAMETERS ============= */
#define EKF_Q_SOC        (1e-3f)        
#define EKF_Q_V1         (1e-2f)        
#define EKF_R_VOLTAGE    (1e-1f)        
#define EKF_P_INIT       (0.1f)         

/* ============= SAFETY LIMITS ============= */
#define VOLTAGE_MIN      (2.7f)
#define VOLTAGE_MAX      (4.2f)
#define CURRENT_MAX      (2.0f)
#define TEMP_MIN         (-10.0f)
#define TEMP_MAX         (45.0f)

/* ============= SOH PARAMETERS ============= */
#define EOL_CAPACITY     (1.328f)
#define SOH_UPDATE_CYCLES (20u)

/* Use absolute current for IR drop */
#define ECM_USE_ABS_CURRENT (1u)

#endif
