%% SIMPLIFIED REAL-TIME SOH MONITOR
% For embedded/real-time implementation
%
% File: matlab/07_soh_estimation/soh_monitor_simple.m

function SOH = soh_monitor_simple(I, V, t, Q_fresh, R0_fresh, ocv_data)
    % SOH_MONITOR_SIMPLE Single-cycle SOH update
    %
    % Inputs:
    %   I, V, t   - Current, voltage, time for one discharge cycle
    %   Q_fresh   - Fresh battery capacity (Ah)
    %   R0_fresh  - Fresh battery resistance (Ω)
    %   ocv_data  - OCV lookup table
    %
    % Output:
    %   SOH       - Structure with current SOH estimates
    
    %% ========== CAPACITY ESTIMATION ==========
    % Find discharge portion
    current_threshold = 0.1;
    start_idx = find(abs(I) > current_threshold, 1, 'first');
    end_idx = find(abs(I) > current_threshold, 1, 'last');
    
    if isempty(start_idx) || isempty(end_idx)
        SOH.Q = NaN;
        SOH.SOH_Q = NaN;
    else
        t_disc = t(start_idx:end_idx) - t(start_idx);
        I_disc = I(start_idx:end_idx);
        
        % Coulomb counting
        dt = mean(diff(t_disc));
        Q_est = sum(abs(I_disc)) * dt / 3600;
        SOH_Q = Q_est / Q_fresh * 100;
        
        SOH.Q = Q_est;
        SOH.SOH_Q = SOH_Q;
    end
    
    %% ========== RESISTANCE ESTIMATION ==========
    % Use initial voltage drop
    if ~isempty(start_idx) && (end_idx - start_idx > 10)
        % Assume fully charged at start
        SOC_start = 1.0;
        OCV_start = interp1(ocv_data.SOC, ocv_data.OCV, SOC_start, 'linear', 'extrap');
        
        % Use first few points for robust estimate
        pulse_points = min(5, length(I) - start_idx + 1);
        R0_est = mean((OCV_start - V(start_idx:start_idx+pulse_points-1)) ./ ...
                       abs(I(start_idx:start_idx+pulse_points-1)));
        
        SOH_R = R0_fresh / R0_est * 100;
        
        SOH.R0 = R0_est;
        SOH.SOH_R = SOH_R;
    else
        SOH.R0 = NaN;
        SOH.SOH_R = NaN;
    end
    
    %% ========== FUSE SOH ==========
    if ~isnan(SOH.SOH_Q) && ~isnan(SOH.SOH_R)
        SOH.SOH_fused = 0.7 * SOH.SOH_Q + 0.3 * SOH.SOH_R;
    elseif ~isnan(SOH.SOH_Q)
        SOH.SOH_fused = SOH.SOH_Q;
    elseif ~isnan(SOH.SOH_R)
        SOH.SOH_fused = SOH.SOH_R;
    else
        SOH.SOH_fused = NaN;
    end
    
    SOH.timestamp = datestr(now);
    
end