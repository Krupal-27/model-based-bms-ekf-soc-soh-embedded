#ifndef SOC_ESTIMATOR_H
#define SOC_ESTIMATOR_H

#include <stdint.h>
#include <stdbool.h>

#include "bms_model.h"

/* EKF State Structure (2x2) for x = [soc; v1] */
typedef struct {
    /* State vector */
    float soc;           /* SOC estimate */
    float v1;            /* RC voltage estimate */

    /* Covariance matrix P (2x2) */
    float p11, p12;
    float p21, p22;

    /* Process noise (diagonal) */
    float q11;           /* for SOC */
    float q22;           /* for V1 */

    /* Measurement noise */
    float r_voltage;

    /* Optional debug */
    float last_v_pred;
    float last_innov;
} EKF_State;

/* Initialize EKF */
void EKF_Init(EKF_State *ekf, float init_soc);

/* Prediction step */
void EKF_Predict(EKF_State *ekf, float current, float dt);

/* Update step using measured terminal voltage */
void EKF_Update(EKF_State *ekf, float v_measured, float current);

/* Get SOC estimate */
float EKF_GetSOC(const EKF_State *ekf);

#endif
