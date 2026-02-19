#include "soc_estimator.h"
#include "bms_config.h"
#include <math.h>

static float clampf(float x, float lo, float hi)
{
    if (x < lo) return lo;
    if (x > hi) return hi;
    return x;
}

static float ocv_from_soc(float soc)
{
    soc = clampf(soc, SOC_MIN, SOC_MAX);
    return 3.2f + 1.0f * soc;
}

void EKF_Init(EKF_State *ekf, float init_soc)
{
    if (ekf == NULL) return;

    ekf->soc = clampf(init_soc, SOC_MIN, SOC_MAX);
    ekf->v1  = 0.0f;

    /* Covariance - smaller = trust initial state more */
    ekf->p11 = 0.01f;    ekf->p12 = 0.0f;
    ekf->p21 = 0.0f;    ekf->p22 = 0.01f;

    /* Noise - these values are critical for EKF performance */
    ekf->q11 = 1e-4f;    /* SOC process noise - small = trust model */
    ekf->q22 = 1e-3f;    /* V1 process noise - small = trust model */
    ekf->r_voltage = 1e-2f; /* Measurement noise - larger = trust measurements less */
    
    ekf->last_v_pred = 0.0f;
    ekf->last_innov = 0.0f;
}

void EKF_Predict(EKF_State *ekf, float current, float dt)
{
    if (ekf == NULL || dt <= 0.0f) return;

    const float i_eff = fabsf(current);

    /* RC dynamics */
    const float tau = R1 * C1;
    float alpha = 0.0f;
    if (tau > 1e-9f) alpha = expf(-dt / tau);

    /* State prediction */
    const float denom = (NOMINAL_CAPACITY * 3600.0f);
    if (denom > 1e-12f) {
        ekf->soc += (current * dt) / denom;
        ekf->soc = clampf(ekf->soc, SOC_MIN, SOC_MAX);
    }

    ekf->v1 = ekf->v1 * alpha + (i_eff * R1) * (1.0f - alpha);

    /* A = [[1,0],[0,alpha]] */
    const float A00 = 1.0f, A01 = 0.0f;
    const float A10 = 0.0f, A11 = alpha;

    /* P = A P A' + Q */
    const float P00 = ekf->p11, P01 = ekf->p12;
    const float P10 = ekf->p21, P11 = ekf->p22;

    /* A*P */
    const float AP00 = A00*P00 + A01*P10;
    const float AP01 = A00*P01 + A01*P11;
    const float AP10 = A10*P00 + A11*P10;
    const float AP11 = A10*P01 + A11*P11;

    /* (A*P)*A' + Q */
    ekf->p11 = AP00*A00 + AP01*A01 + ekf->q11;
    ekf->p12 = AP00*A10 + AP01*A11;
    ekf->p21 = AP10*A00 + AP11*A01;
    ekf->p22 = AP10*A10 + AP11*A11 + ekf->q22;
}

void EKF_Update(EKF_State *ekf, float v_measured, float current)
{
    if (ekf == NULL) return;

    const float i_abs = fabsf(current);

    /* Measurement model: V = OCV(soc) - v1 - abs(I)*R0 */
    const float ocv = ocv_from_soc(ekf->soc);
    const float v_pred = ocv - ekf->v1 - i_abs * R0;
    const float y = v_measured - v_pred;
    
    ekf->last_v_pred = v_pred;
    ekf->last_innov = y;

    /* H = [dOCV/dSOC, -1] */
    const float h1 = 1.0f;
    const float h2 = -1.0f;

    /* S = H P H' + R */
    float S = h1*(ekf->p11*h1 + ekf->p12*h2) + h2*(ekf->p21*h1 + ekf->p22*h2) + ekf->r_voltage;
    if (S < 1e-12f) S = 1e-12f;

    /* K = P H' / S */
    const float k1 = (ekf->p11*h1 + ekf->p12*h2) / S;
    const float k2 = (ekf->p21*h1 + ekf->p22*h2) / S;

    /* State update */
    ekf->soc += k1 * y;
    ekf->v1  += k2 * y;
    ekf->soc = clampf(ekf->soc, SOC_MIN, SOC_MAX);

    /* Covariance update: P = (I - K H) P */
    const float p11 = ekf->p11, p12 = ekf->p12;
    const float p21 = ekf->p21, p22 = ekf->p22;

    ekf->p11 = (1.0f - k1*h1)*p11 + (-k1*h2)*p21;
    ekf->p12 = (1.0f - k1*h1)*p12 + (-k1*h2)*p22;
    ekf->p21 = (-k2*h1)*p11 + (1.0f - k2*h2)*p21;
    ekf->p22 = (-k2*h1)*p12 + (1.0f - k2*h2)*p22;
}

float EKF_GetSOC(const EKF_State *ekf)
{
    return (ekf != NULL) ? ekf->soc : 0.0f;
}