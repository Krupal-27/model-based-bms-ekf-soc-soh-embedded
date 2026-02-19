
/*
 * test_bms_fixed.c - BMS test with fixed 100-sample vectors
 */

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <math.h>

#include "bms_config.h"
#include "bms_model.h"
#include "safety_fsm.h"
#include "soc_estimator.h"
#include "soh_estimator.h"
#include "test_vectors.h"

int main()
{
    printf("========================================\n");
    printf("BMS TEST WITH 100 SAMPLES\n");
    printf("========================================\n");
    printf("Parameters:\n");
    printf("R0 = %.3f Ohms\n", R0);
    printf("R1 = %.3f Ohms\n", R1);
    printf("C1 = %.1f Farads\n", C1);
    printf("tau = %.1f seconds\n", R1*C1);
    printf("========================================\n");
    
    BMS_State bms;
    EKF_State ekf;
    SOH_State soh;
    
    BMS_Init(&bms);
    EKF_Init(&ekf, 1.0f);
    SOH_Init(&soh, NOMINAL_CAPACITY);
    
    float max_soc_error = 0.0f;
    float max_voltage_error = 0.0f;
    float sum_soc_error = 0.0f;
    float sum_voltage_error = 0.0f;
    int n = NUM_TEST_SAMPLES;
    
    printf("\nStep\tTime\tCurrent\tV_meas\tV_pred\tSOC_est\tSOC_ref\n");
    printf("--------------------------------------------------------\n");
    
    for (int i = 0; i < n; i++) {
        float dt;
        if (i == 0) dt = test_time[0];
        else dt = test_time[i] - test_time[i-1];
        
        float current = test_current[i];
        float v_meas = test_v_meas[i];
        float soc_ref = test_soc_ref[i];
        
        float v_pred = BMS_GetVoltage(&bms, current);
        
        BMS_ECM_Step(&bms, current, dt);
        EKF_Predict(&ekf, current, dt);
        EKF_Update(&ekf, v_meas, current);
        SOH_Update(&soh, current, v_meas, dt);
        
        float soc_error = fabsf(ekf.soc - soc_ref);
        float voltage_error = fabsf(v_pred - v_meas);
        
        if (soc_error > max_soc_error) max_soc_error = soc_error;
        if (voltage_error > max_voltage_error) max_voltage_error = voltage_error;
        
        sum_soc_error += soc_error;
        sum_voltage_error += voltage_error;
        
        if (i % 10 == 0) {
            printf("%d\t%.1f\t%.3f\t%.3f\t%.3f\t%.3f\t%.3f\n",
                   i, test_time[i], current, v_meas, v_pred, ekf.soc, soc_ref);
        }
    }
    
    float avg_soc_error = sum_soc_error / n;
    float avg_voltage_error = sum_voltage_error / n;
    
    printf("\n========== RESULTS ==========\n");
    printf("Max SOC error: %.4f (%.2f%%)\n", max_soc_error, max_soc_error * 100.0f);
    printf("Avg SOC error: %.4f (%.2f%%)\n", avg_soc_error, avg_soc_error * 100.0f);
    printf("Max Voltage error: %.3f mV\n", max_voltage_error * 1000.0f);
    printf("Avg Voltage error: %.3f mV\n", avg_voltage_error * 1000.0f);
    printf("Final SOH: %.1f%%\n", SOH_GetPercentage(&soh));
    
    if (max_soc_error < 0.06f) {
        printf("\n✅ TEST PASSED - BMS is working correctly!\n");
        return 0;
    } else {
        printf("\n❌ TEST FAILED - Errors too high\n");
        return 1;
    }
}
