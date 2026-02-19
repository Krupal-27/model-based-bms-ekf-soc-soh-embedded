%% ONLINE SOH ESTIMATION
% Estimates State of Health using two methods:
%   1. Capacity-based SOH from discharge integrals (every cycle)
%   2. Resistance-based SOH from pulse detection (every N cycles)
%   3. Fused SOH with smoothing
%
% File: matlab/07_soh_estimation/soh_online.m

function [SOH_history, stats] = soh_online(cycles, ocv_data, params0, options)
    % SOH_ONLINE Estimate SOH from cycling data
    %
    % Inputs:
    %   cycles    - Cell array of cycle structures (from cell01_cycles.mat)
    %   ocv_data  - OCV lookup table structure
    %   params0   - Initial ECM parameters (from fresh battery)
    %   options   - Structure with fields:
    %       .R_fit_interval  - Cycles between R0 re-fitting (default: 10)
    %       .smooth_window   - Moving average window (default: 3)
    %       .plot_results    - Boolean to show plots (default: true)
    %
    % Outputs:
    %   SOH_history - Structure with fields:
    %       .cycle_numbers - Cycle indices
    %       .Q            - Capacity estimates (Ah)
    %       .SOH_Q        - Capacity-based SOH (%)
    %       .R0           - Resistance estimates (Ω)
    %       .SOH_R        - Resistance-based SOH (%)
    %       .SOH_fused    - Fused SOH (%)
    %       .SOH_smoothed - Smoothed fused SOH
    %   stats - Statistics structure
    
    fprintf('========================================\n');
    fprintf('🔋 ONLINE SOH ESTIMATION\n');
    fprintf('========================================\n\n');
    
    %% ========== PARSE INPUTS ==========
    if nargin < 4
        options = struct();
    end
    
    % Default options
    if ~isfield(options, 'R_fit_interval')
        options.R_fit_interval = 10;  % Re-fit R0 every 10 cycles
    end
    if ~isfield(options, 'smooth_window')
        options.smooth_window = 3;     % Moving average window
    end
    if ~isfield(options, 'plot_results')
        options.plot_results = true;
    end
    if ~isfield(options, 'min_points')
        options.min_points = 100;      % Min points for valid discharge
    end
    
    fprintf('📊 Options:\n');
    fprintf('   R0 re-fit interval: %d cycles\n', options.R_fit_interval);
    fprintf('   Smoothing window: %d\n', options.smooth_window);
    fprintf('   Min points for discharge: %d\n\n', options.min_points);
    
    %% ========== FIND ALL DISCHARGE CYCLES ==========
    fprintf('🔍 Scanning for discharge cycles...\n');
    
    discharge_indices = [];
    for i = 1:length(cycles)
        if strcmp(cycles(i).type, 'discharge')
            % Check if it has enough points
            if length(cycles(i).time) > options.min_points
                discharge_indices = [discharge_indices, i];
            end
        end
    end
    
    n_cycles = length(discharge_indices);
    fprintf('✅ Found %d valid discharge cycles\n\n', n_cycles);
    
    if n_cycles == 0
        error('No valid discharge cycles found');
    end
    
    %% ========== INITIALIZE STORAGE ==========
    cycle_numbers = discharge_indices;
    Q_est = zeros(n_cycles, 1);
    R0_est = zeros(n_cycles, 1);
    R0_est(:) = NaN;  % Initialize with NaN (will fill when fitted)
    SOH_Q = zeros(n_cycles, 1);
    SOH_R = zeros(n_cycles, 1);
    SOH_fused = zeros(n_cycles, 1);
    
    % Initial parameters
    R0_fresh = params0.R0;
    Q_fresh = params0.Q_nom;
    
    %% ========== PROCESS EACH CYCLE ==========
    fprintf('🔄 Processing %d cycles...\n', n_cycles);
    
    for k = 1:n_cycles
        cycle_idx = cycle_numbers(k);
        d = cycles(cycle_idx);
        
        % Progress indicator
        if mod(k, 10) == 0 || k == 1 || k == n_cycles
            fprintf('   Cycle %3d/%d (index %d)...\n', k, n_cycles, cycle_idx);
        end
        
        %% ========== CAPACITY ESTIMATION (EVERY CYCLE) ==========
        % Find actual discharge portion
        current_threshold = 0.1;
        start_idx = find(abs(d.I) > current_threshold, 1, 'first');
        end_idx = find(abs(d.I) > current_threshold, 1, 'last');
        
        if ~isempty(start_idx) && ~isempty(end_idx) && (end_idx - start_idx > 100)
            t_disc = d.time(start_idx:end_idx) - d.time(start_idx);
            I_disc = d.I(start_idx:end_idx);
            
            % Coulomb counting for capacity
            dt = mean(diff(t_disc));
            Q_est(k) = sum(abs(I_disc)) * dt / 3600;  % Ah
        else
            % If no valid discharge, use previous estimate
            if k > 1
                Q_est(k) = Q_est(k-1);
            else
                Q_est(k) = Q_fresh;
            end
        end
        
        % Capacity-based SOH
        SOH_Q(k) = Q_est(k) / Q_fresh * 100;
        
       %% ========== RESISTANCE ESTIMATION - USE STEADY-STATE CURRENT ==========
if mod(k, options.R_fit_interval) == 1 || k == 1 || k == n_cycles
    try
        if ~isempty(start_idx) && ~isempty(end_idx)
            % Find where current stabilizes (after ramp-up)
            steady_idx = start_idx + 100;  % Skip first 100 points
            
            if steady_idx < end_idx
                I_steady = abs(d.I(steady_idx));
                V_steady = d.V(steady_idx);
                
                % OCV just before discharge starts
                pre_start = max(1, start_idx - 10);
                if pre_start < start_idx
                    OCV_start = mean(d.V(pre_start:start_idx-1));
                else
                    OCV_start = d.V(start_idx);
                end
                
                % Calculate R0 using steady-state point
                R0_est(k) = (OCV_start - V_steady) / I_steady;
                
                % Ensure reasonable bounds
                R0_est(k) = max(min(R0_est(k), 0.5), 0.01);
                
                fprintf('   Steady I = %.3f A, V = %.3f V, R0 = %.1f mΩ\n', ...
                    I_steady, V_steady, R0_est(k)*1000);
            else
                if k > 1
                    R0_est(k) = R0_est(k-1);
                end
            end
        end
    catch ME
        fprintf('   ⚠️  R0 estimation failed: %s\n', ME.message);
        if k > 1 && ~isnan(R0_est(k-1))
            R0_est(k) = R0_est(k-1);
        end
    end
else
    if k > 1
        R0_est(k) = R0_est(k-1);
    end
end
       

      % Resistance-based SOH (R0 increases with age)
        if ~isnan(R0_est(k)) && R0_est(k) > 0
            SOH_R(k) = R0_fresh / R0_est(k) * 100;
        else
            if k > 1
                SOH_R(k) = SOH_R(k-1);
            else
                SOH_R(k) = 100;
            end
        end
    end
    
    %% ========== FUSE SOH ESTIMATES ==========
    fprintf('\n🔄 Fusing SOH estimates...\n');
    
    % Weights (capacity is primary, resistance is secondary)
    wQ = 0.7;
    wR = 0.3;
    
    SOH_fused = wQ * SOH_Q + wR * SOH_R;
    
    % Apply moving average smoothing
    if options.smooth_window > 1
        SOH_smoothed = movmean(SOH_fused, options.smooth_window);
    else
        SOH_smoothed = SOH_fused;
    end
    
    %% ========== CREATE OUTPUT STRUCTURE ==========
    SOH_history = struct();
    SOH_history.cycle_numbers = cycle_numbers;
    SOH_history.Q = Q_est;
    SOH_history.SOH_Q = SOH_Q;
    SOH_history.R0 = R0_est;
    SOH_history.SOH_R = SOH_R;
    SOH_history.SOH_fused = SOH_fused;
    SOH_history.SOH_smoothed = SOH_smoothed;
    SOH_history.weights = struct('wQ', wQ, 'wR', wR);
    
    %% ========== CALCULATE STATISTICS ==========
    stats = struct();
    stats.n_cycles = n_cycles;
    stats.Q_initial = Q_est(1);
    stats.Q_final = Q_est(end);
    stats.Q_fade_percent = (1 - Q_est(end)/Q_est(1)) * 100;
    stats.Q_fade_rate = (Q_est(1) - Q_est(end)) / n_cycles * 1000;  % mAh/cycle
    
    % R0 statistics
    valid_R0 = R0_est(~isnan(R0_est));
    if ~isempty(valid_R0)
        stats.R0_initial = valid_R0(1);
        stats.R0_final = valid_R0(end);
        stats.R0_increase_percent = (valid_R0(end)/valid_R0(1) - 1) * 100;
        stats.R0_growth_rate = (valid_R0(end) - valid_R0(1)) / length(valid_R0) * 1000;  % mΩ/cycle
    else
        stats.R0_initial = NaN;
        stats.R0_final = NaN;
        stats.R0_increase_percent = NaN;
        stats.R0_growth_rate = NaN;
    end
    
    % SOH statistics
    stats.SOH_initial = SOH_smoothed(1);
    stats.SOH_final = SOH_smoothed(end);
    stats.SOH_fade_percent = 100 - SOH_smoothed(end);
    stats.SOH_fade_rate = (SOH_smoothed(1) - SOH_smoothed(end)) / n_cycles;  % %/cycle
    
    %% ========== PRINT SUMMARY ==========
    fprintf('\n📊 SOH Estimation Summary:\n');
    fprintf('   Capacity fade: %.1f%% (%.1f mAh/cycle)\n', ...
        stats.Q_fade_percent, stats.Q_fade_rate);
    if ~isnan(stats.R0_initial)
        fprintf('   R0 increase: %.1f%% (%.1f μΩ/cycle)\n', ...
            stats.R0_increase_percent, stats.R0_growth_rate*1000);
    end
    fprintf('   SOH final: %.1f%%\n', stats.SOH_final);
    fprintf('   SOH fade rate: %.3f%%/cycle\n', stats.SOH_fade_rate);
    
    %% ========== PLOT RESULTS ==========
    if options.plot_results
        figure('Position', [100, 100, 1600, 1000]);
        
        % Plot 1: Capacity estimates
        subplot(2,3,1);
        plot(cycle_numbers, Q_est, 'bo-', 'LineWidth', 1.5, 'MarkerSize', 4);
        xlabel('Cycle Number'); ylabel('Capacity (Ah)');
        title(sprintf('Capacity Fade (%.1f mAh/cycle)', stats.Q_fade_rate));
        grid on;
        
        % Plot 2: R0 estimates
        subplot(2,3,2);
        plot(cycle_numbers, R0_est*1000, 'rs-', 'LineWidth', 1.5, 'MarkerSize', 4);
        xlabel('Cycle Number'); ylabel('R0 (mΩ)');
        title(sprintf('Resistance Growth (%.1f μΩ/cycle)', stats.R0_growth_rate*1000));
        grid on;
        
        % Plot 3: SOH components
        subplot(2,3,3);
        plot(cycle_numbers, SOH_Q, 'b-', 'LineWidth', 1, 'DisplayName', 'SOH_Q (Capacity)'); hold on;
        plot(cycle_numbers, SOH_R, 'r-', 'LineWidth', 1, 'DisplayName', 'SOH_R (Resistance)');
        plot(cycle_numbers, SOH_fused, 'g-', 'LineWidth', 1.5, 'DisplayName', 'SOH_Fused');
        xlabel('Cycle Number'); ylabel('SOH (%)');
        title('SOH Components');
        legend('Location', 'best');
        grid on; ylim([50, 105]);
        yline(80, 'k--', 'EOL', 'LineWidth', 1.5);
        
        % Plot 4: Smoothed SOH
        subplot(2,3,4);
        plot(cycle_numbers, SOH_fused, 'g.', 'MarkerSize', 6, 'DisplayName', 'Raw'); hold on;
        plot(cycle_numbers, SOH_smoothed, 'b-', 'LineWidth', 2, 'DisplayName', 'Smoothed');
        xlabel('Cycle Number'); ylabel('SOH (%)');
        title(sprintf('Smoothed SOH (window = %d)', options.smooth_window));
        legend('Location', 'best');
        grid on; ylim([50, 105]);
        yline(80, 'k--', 'EOL', 'LineWidth', 1.5);
        
        % Plot 5: Fade rate
        subplot(2,3,5);
        fade_rate = -diff(SOH_smoothed);
        plot(cycle_numbers(2:end), fade_rate, 'm-', 'LineWidth', 1);
        xlabel('Cycle Number'); ylabel('Fade Rate (%/cycle)');
        title('SOH Fade Rate');
        grid on;
        
        % Plot 6: EOL prediction
        subplot(2,3,6);
        plot(cycle_numbers, SOH_smoothed, 'b-', 'LineWidth', 2); hold on;
        xlabel('Cycle Number'); ylabel('SOH (%)');
        title('EOL Prediction');
        grid on; ylim([50, 105]);
        yline(80, 'k--', 'EOL (80%)', 'LineWidth', 1.5);
        
        % Find where SOH crosses 80%
        eol_idx = find(SOH_smoothed <= 80, 1, 'first');
        if ~isempty(eol_idx)
            eol_cycle = cycle_numbers(eol_idx);
            plot(eol_cycle, 80, 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
            text(eol_cycle, 82, sprintf(' EOL at cycle %d', eol_cycle), 'FontSize', 10);
        end
        
        sgtitle('Online SOH Estimation Results', 'FontSize', 14, 'FontWeight', 'bold');
    end
    
    fprintf('\n✅ Online SOH estimation complete\n');
end