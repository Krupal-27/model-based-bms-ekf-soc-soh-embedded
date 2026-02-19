%% FIT 1-RC ECM PARAMETERS
% Identifies R0, R1, C1 from discharge data
%
% File: matlab/03_ecm_model/fit_1rc_model.m

function [R0, R1, C1, rmse] = fit_1RC_model(discharge_data, ocv_data)
    % FIT_1RC_MODEL Estimate 1-RC parameters
    
    %% ========== EXTRACT DATA ==========
    t = discharge_data.time;
    V = discharge_data.V;
    I = discharge_data.I;
    Q = discharge_data.Q;
    
    dt = mean(diff(t));
    
    %% ========== CALCULATE SOC ==========
    dQ = abs(I) * dt;
    Q_removed = cumsum(dQ);
    SOC = 1 - Q_removed / (Q * 3600);
    SOC = max(min(SOC, 1), 0);
    
    %% ========== ESTIMATE R0 ==========
    % R0 = (OCV - V) / I at start
    OCV_start = interp1(ocv_data.SOC, ocv_data.OCV, SOC(1), 'linear', 'extrap');
    R0 = (OCV_start - V(1)) / abs(I(1));
    R0 = max(R0, 0.01);
    R0 = min(R0, 0.3);
    
    %% ========== ESTIMATE R1 FROM MID-POINT ==========
    mid_idx = floor(length(t)/2);
    OCV_mid = interp1(ocv_data.SOC, ocv_data.OCV, SOC(mid_idx), 'linear', 'extrap');
    R1 = (OCV_mid - V(mid_idx) - abs(I(mid_idx))*R0) / abs(I(mid_idx));
    R1 = max(R1, 0.005);
    R1 = min(R1, 0.2);
    
    %% ========== FIND BEST C1 ==========
    C1_vals = [1000, 2000, 5000, 10000, 20000, 50000, 100000];
    best_rmse = inf;
    best_C1 = C1_vals(1);
    
    for C1 = C1_vals
        tau = R1 * C1;
        alpha = exp(-dt / tau);
        
        V1 = 0;
        V_sim = zeros(size(t));
        
        for k = 1:length(t)
            OCV_val = interp1(ocv_data.SOC, ocv_data.OCV, SOC(k), 'linear', 'extrap');
            V_sim(k) = OCV_val - abs(I(k)) * R0 - V1;
            V1 = alpha * V1 + R1 * (1 - alpha) * I(k);
        end
        
        rmse_val = rms(V - V_sim) * 1000;
        
        if rmse_val < best_rmse
            best_rmse = rmse_val;
            best_C1 = C1;
        end
    end
    
    C1 = best_C1;
    rmse = best_rmse;
    
    fprintf('✅ 1-RC parameters: R0=%.4f, R1=%.4f, C1=%d, RMSE=%.1f mV\n', ...
        R0, R1, C1, rmse);
end