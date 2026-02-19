%% COST FUNCTION FOR 1-RC ECM PARAMETER FITTING
% Calculates RMSE between measured and simulated voltage
%
% File: matlab/04_parameter_id/cost_ecm_1rc.m

function [J, V_sim] = cost_ecm_1rc(x, data, debug_flag)
    % COST_ECM_1RC RMSE cost function for 1-RC ECM parameter optimization
    
    if nargin < 3
        debug_flag = false;
    end
    
    %% ========== EXTRACT PARAMETERS ==========
    R0 = x(1);
    R1 = x(2);
    C1 = x(3);
    
    % Ensure parameters are positive
    if any(x <= 0)
        J = 1e6;
        if debug_flag
            fprintf('   ⚠️  Negative parameter detected, cost = 1e6\n');
        end
        return;
    end
    
    %% ========== EXTRACT DATA ==========
    % FIXED: Use 'time' instead of 't'
    t = data.time;
    I = data.I;
    V_meas = data.V;
    Q = data.Q;
    
    % Get OCV lookup table
    if isstruct(data.OCV)
        SOC_lookup = data.OCV.SOC;
        OCV_lookup = data.OCV.OCV;
    else
        SOC_lookup = data.OCV(:,1);
        OCV_lookup = data.OCV(:,2);
    end
    
    N = length(t);
    dt = [0; diff(t)];
    
    %% ========== SIMULATE 1-RC ECM ==========
    tau = R1 * C1;
    
    V_sim = zeros(N, 1);
    SOC = zeros(N, 1);
    V1 = zeros(N, 1);
    
    SOC(1) = 1.0;
    V1(1) = 0;
    
    for k = 1:N
        OCV = interp1(SOC_lookup, OCV_lookup, SOC(k), 'linear', 'extrap');
        V_sim(k) = OCV - abs(I(k)) * R0 - V1(k);
        
        if k < N
            dt_k = dt(k+1);
            SOC(k+1) = SOC(k) + I(k) * dt_k / (Q * 3600);
            SOC(k+1) = max(min(SOC(k+1), 1), 0);
            
            alpha = exp(-dt_k / tau);
            V1(k+1) = alpha * V1(k) + R1 * (1 - alpha) * I(k);
        end
    end
    
    %% ========== CALCULATE COST ==========
    error = V_meas - V_sim;
    J = rms(error) * 1000;
    
    if debug_flag
        fprintf('   R0=%.4f, R1=%.4f, C1=%.0f → RMSE = %.1f mV\n', ...
            R0, R1, C1, J);
    end
end