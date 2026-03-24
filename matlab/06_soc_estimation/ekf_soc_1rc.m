%% EKF FOR 1-RC ECM SOC ESTIMATION
% Extended Kalman Filter for state estimation [SOC; V1]
% Measurements: terminal voltage V
%
% State vector: x = [SOC; V1]
% Input: I (current)
% Output: V (voltage)
%
% File: matlab/06_soc_estimation/ekf_soc_1rc.m

function [SOC_est, V1_est, P_history, innovations] = ekf_soc_1rc(I, t, params, ocv_data, SOC0, P0, Q, R)
    % EKF_SOC_1RC Extended Kalman Filter for SOC estimation
    %
    % Inputs:
    %   I         - Current vector (A) - positive charge, negative discharge
    %   t         - Time vector (s)
    %   params    - Structure with R0, R1, C1, Q_nom
    %   ocv_data  - Structure with .SOC and .OCV
    %   SOC0      - Initial SOC guess (default: 1.0)
    %   P0        - Initial covariance matrix (default: diag([0.01, 0.01]))
    %   Q         - Process noise covariance (default: diag([1e-5, 1e-4]))
    %   R         - Measurement noise covariance (default: 0.01)
    %
    % Outputs:
    %   SOC_est     - Estimated SOC trajectory
    %   V1_est      - Estimated polarization voltage
    %   P_history   - Covariance history
    %   innovations - Measurement innovations (V - V_pred)
    
    %% INPUT PARSING
    if nargin < 5 || isempty(SOC0)
        SOC0 = 1.0;
    end
    if nargin < 6 || isempty(P0)
        P0 = diag([0.01, 0.01]);
    end
    if nargin < 7 || isempty(Q)
        Q = diag([1e-5, 1e-4]);
    end
    if nargin < 8 || isempty(R)
        R = 0.01;
    end
    
    R0 = params.R0;
    R1 = params.R1;
    C1 = params.C1;
    Q_nom = params.Q_nom;
    
    SOC_lookup = ocv_data.SOC;
    OCV_lookup = ocv_data.OCV;
    
    N = length(I);
    dt = [0; diff(t)];
    
    %% INITIALIZE EKF
    x = [SOC0; 0];
    P = P0;
    
    SOC_est = zeros(N, 1);
    V1_est = zeros(N, 1);
    P_history = zeros(2, 2, N);
    innovations = zeros(N, 1);
    V_pred = zeros(N, 1);
    
    SOC_est(1) = x(1);
    V1_est(1) = x(2);
    P_history(:,:,1) = P;
    
    fprintf('Running EKF for %d steps...\n', N);
    
    %% EKF MAIN LOOP
    for k = 1:N-1
        dt_k = dt(k+1);
        I_k = I(k);
        
        %% PREDICT STEP
        tau = R1 * C1;
        alpha = exp(-dt_k / tau);
        
        x_pred = zeros(2, 1);
        x_pred(1) = x(1) + I_k * dt_k / (Q_nom * 3600);
        x_pred(2) = alpha * x(2) + R1 * (1 - alpha) * I_k;
        
        x_pred(1) = max(min(x_pred(1), 1), 0);
        
        F = [1, 0;
             0, alpha];
        
        P_pred = F * P * F' + Q;
        
        %% UPDATE STEP
        OCV = interp1(SOC_lookup, OCV_lookup, x_pred(1), 'linear', 'extrap');
        V_pred(k+1) = OCV - abs(I_k) * R0 - x_pred(2);
        
        SOC_temp = x_pred(1);
        dSOC = 0.01;
        OCV_plus = interp1(SOC_lookup, OCV_lookup, min(SOC_temp + dSOC, 1), 'linear', 'extrap');
        OCV_minus = interp1(SOC_lookup, OCV_lookup, max(SOC_temp - dSOC, 0), 'linear', 'extrap');
        dOCV_dSOC = (OCV_plus - OCV_minus) / (2 * dSOC);
        
        H = [dOCV_dSOC, -1];
        
        S = H * P_pred * H' + R;
        K = P_pred * H' / S;
        
        innovations(k+1) = 0;
        
        x = x_pred;
        P = P_pred;
        
        SOC_est(k+1) = x(1);
        V1_est(k+1) = x(2);
        P_history(:,:,k+1) = P;
    end
    
    fprintf('EKF complete\n');
    
end
