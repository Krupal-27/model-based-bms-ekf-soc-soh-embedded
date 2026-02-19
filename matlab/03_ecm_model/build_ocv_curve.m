%% BUILD OCV-SOC CURVE - FIXED VERSION
% Creates OCV lookup table from discharge data
%
% File: matlab/03_ecm_model/build_ocv_curve_fixed.m

function [SOC_lookup, OCV_lookup] = build_ocv_curve(discharge_data, R0, R1, C1, plot_results)
    % BUILD_OCV_CURVE_FIXED Create OCV-SOC lookup table
    
    if nargin < 5
        plot_results = true;
    end
    
    fprintf('🔧 Building OCV-SOC curve...\n');
    
    %% ========== EXTRACT DATA ==========
    t = discharge_data.time;
    V = discharge_data.V;
    I = discharge_data.I;
    
    fprintf('   Terminal voltage range: %.3f - %.3f V\n', min(V), max(V));
    
    %% ========== CALCULATE SOC ==========
    Q = discharge_data.Q;
    dt = mean(diff(t));
    dQ = abs(I) * dt;
    Q_removed = cumsum(dQ);
    SOC = 1 - Q_removed / (Q * 3600);
    SOC = max(min(SOC, 1), 0);
    
    %% ========== SIMULATE RC NETWORK ==========
    tau = R1 * C1;
    alpha = exp(-dt / tau);
    V1 = 0;
    OCV_corrected = zeros(size(t));
    
    for k = 1:length(t)
        OCV_corrected(k) = V(k) + abs(I(k)) * R0 + V1;
        V1 = alpha * V1 + R1 * (1 - alpha) * I(k);
    end
    
    fprintf('   Corrected OCV range: %.3f - %.3f V\n', min(OCV_corrected), max(OCV_corrected));
    
    %% ========== CREATE LOOKUP TABLE ==========
    % Sort by SOC (ascending)
    [SOC_sorted, sort_idx] = sort(SOC, 'ascend');
    OCV_sorted = OCV_corrected(sort_idx);
    
    % Remove duplicates
    [SOC_sorted, unique_idx] = unique(SOC_sorted, 'stable');
    OCV_sorted = OCV_sorted(unique_idx);
    
    % Smooth
    window = min(21, floor(length(OCV_sorted)/10));
    if window > 3
        OCV_smooth = smoothdata(OCV_sorted, 'movmean', window);
    else
        OCV_smooth = OCV_sorted;
    end
    
    % Interpolate to uniform grid
    SOC_lookup = (0:0.01:1)';
    OCV_lookup = interp1(SOC_sorted, OCV_smooth, SOC_lookup, 'pchip', 'extrap');
    
    % Ensure reasonable bounds
    OCV_lookup = max(OCV_lookup, 2.8);
    OCV_lookup = min(OCV_lookup, 4.3);
    
    fprintf('   Final OCV range: %.3f - %.3f V\n', min(OCV_lookup), max(OCV_lookup));
    
    %% ========== PLOT ==========
    if plot_results
        figure('Name', 'OCV Construction', 'Position', [100, 100, 1200, 400]);
        
        subplot(1,2,1);
        plot(t, V, 'b-', 'LineWidth', 1); hold on;
        plot(t, OCV_corrected, 'r-', 'LineWidth', 1.5);
        xlabel('Time (s)'); ylabel('Voltage (V)');
        title('Terminal vs OCV');
        legend('Terminal', 'OCV');
        grid on;
        
        subplot(1,2,2);
        plot(SOC, OCV_corrected, 'k.', 'MarkerSize', 2); hold on;
        plot(SOC_lookup, OCV_lookup, 'r-', 'LineWidth', 2);
        xlabel('SOC'); ylabel('OCV (V)');
        title('OCV-SOC Curve');
        grid on; xlim([0,1]); ylim([2.5,4.5]);
        
        sgtitle('OCV Curve Construction', 'FontSize', 14);
    end
end