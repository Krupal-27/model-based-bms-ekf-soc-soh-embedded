%% EKF SOC ESTIMATION WITH MEASUREMENT UPDATE
% Full EKF implementation using actual voltage measurements
%
% File: matlab/06_soc_estimation/ekf_soc_with_measurements.m

function [SOC_est, V1_est, P_history, innovations] = ekf_soc_with_measurements(I, V_meas, t, params, ocv_data, SOC0, P0, Q, R)
    % EKF_SOC_WITH_MEASUREMENTS Full EKF with voltage measurement update
    
    %% ========== INPUT PARSING ==========
    if nargin < 6 || isempty(SOC0)
        SOC0 = 1.0;
    end
    if nargin < 7 || isempty(P0)
        P0 = diag([0.01, 0.01]);
    end
    if nargin < 8 || isempty(Q)
        Q = diag([1e-5, 1e-4]);
    end
    if nargin < 9 || isempty(R)
        R = 0.01;
    end
    
    % Extract parameters
    R0 = params.R0;
    R1 = params.R1;
    C1 = params.C1;
    Q_nom = params.Q_nom;
    
    % OCV lookup
    SOC_lookup = ocv_data.SOC;
    OCV_lookup = ocv_data.OCV;
    
    % Time vector
    N = length(I);
    dt = [0; diff(t)];
    
    %% ========== INITIALIZE EKF ==========
    x = [SOC0; 0];          % State vector [SOC; V1]
    P = P0;                 % State covariance
    
    % Storage
    SOC_est = zeros(N, 1);
    V1_est = zeros(N, 1);
    P_history = zeros(2, 2, N);
    innovations = zeros(N, 1);
    V_pred = zeros(N, 1);
    
    SOC_est(1) = x(1);
    V1_est(1) = x(2);
    P_history(:,:,1) = P;
    
    fprintf('🔧 Running EKF with measurement update for %d steps...\n', N);
    
    %% ========== EKF MAIN LOOP ==========
    for k = 1:N-1
        % Current time step
        dt_k = dt(k+1);
        I_k = I(k);
        
        %% ========== PREDICT STEP ==========
        tau = R1 * C1;
        alpha = exp(-dt_k / tau);
        
        % Predicted state
        x_pred = zeros(2, 1);
        x_pred(1) = x(1) + I_k * dt_k / (Q_nom * 3600);
        x_pred(2) = alpha * x(2) + R1 * (1 - alpha) * I_k;
        
        % Saturate SOC
        x_pred(1) = max(min(x_pred(1), 1), 0);
        
        % Jacobian F
        F = [1, 0;
             0, alpha];
        
        % Predicted covariance
        P_pred = F * P * F' + Q;
        
        %% ========== PREDICT MEASUREMENT ==========
        OCV = interp1(SOC_lookup, OCV_lookup, x_pred(1), 'linear', 'extrap');
        V_pred(k+1) = OCV - abs(I_k) * R0 - x_pred(2);
        
        %% ========== UPDATE STEP WITH MEASUREMENT ==========
        % Jacobian H
        SOC_temp = x_pred(1);
        dSOC = 0.01;
        OCV_plus = interp1(SOC_lookup, OCV_lookup, min(SOC_temp + dSOC, 1), 'linear', 'extrap');
        OCV_minus = interp1(SOC_lookup, OCV_lookup, max(SOC_temp - dSOC, 0), 'linear', 'extrap');
        dOCV_dSOC = (OCV_plus - OCV_minus) / (2 * dSOC);
        
        H = [dOCV_dSOC, -1];
        
        % Innovation covariance
        S = H * P_pred * H' + R;
        
        % Kalman gain
        K = P_pred * H' / S;
        
        % Innovation (measurement residual)
        innov = V_meas(k+1) - V_pred(k+1);
        innovations(k+1) = innov;
        
        % State update
        x = x_pred + K * innov;
        
        % Saturate SOC after update
        x(1) = max(min(x(1), 1), 0);
        
        % Covariance update (Joseph form for numerical stability)
        I_KH = eye(2) - K * H;
        P = I_KH * P_pred * I_KH' + K * R * K';
        
        % Store results
        SOC_est(k+1) = x(1);
        V1_est(k+1) = x(2);
        P_history(:,:,k+1) = P;
    end
    
    fprintf('✅ EKF complete\n');
    fprintf('   Final SOC estimate: %.3f\n', SOC_est(end));
    fprintf('   Final covariance trace: %.2e\n', trace(P));
    
end