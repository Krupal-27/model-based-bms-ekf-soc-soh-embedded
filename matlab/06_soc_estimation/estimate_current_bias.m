%% ESTIMATE CURRENT SENSOR BIAS FROM REST PERIODS
% Identifies periods where current should be zero and estimates bias
%
% Inputs:
%   I         - Current vector (A)
%   t         - Time vector (s)
%   threshold - Current threshold to identify rest (A), default = 0.1
%
% Outputs:
%   I_bias    - Estimated current bias (A)
%   rest_mask - Logical mask of rest periods
%   stats     - Statistics structure
%
% File: matlab/06_soc_estimation/estimate_current_bias.m

function [I_bias, rest_mask, stats] = estimate_current_bias(I, t, threshold)
    
    if nargin < 3
        threshold = 0.1;  % 100mA threshold
    end
    
    fprintf('🔧 Estimating current sensor bias...\n');
    
    %% ========== IDENTIFY REST PERIODS ==========
    rest_mask = abs(I) < threshold;
    
    if ~any(rest_mask)
        fprintf('   ⚠️  No rest periods found. Using zero bias.\n');
        I_bias = 0;
        stats = struct();
        return;
    end
    
    %% ========== EXTRACT REST CURRENT VALUES ==========
    I_rest = I(rest_mask);
    t_rest = t(rest_mask);
    
    %% ========== STATISTICAL ANALYSIS ==========
    I_bias = mean(I_rest);
    I_std = std(I_rest);
    I_median = median(I_rest);
    
    % Find longest continuous rest period
    rest_starts = find(diff([0; rest_mask]) == 1);
    rest_ends = find(diff([rest_mask; 0]) == -1);
    
    if ~isempty(rest_starts)
        rest_durations = t(rest_ends) - t(rest_starts);
        [max_duration, max_idx] = max(rest_durations);
        best_rest_start = t(rest_starts(max_idx));
        best_rest_end = t(rest_ends(max_idx));
        I_best_rest = mean(I(rest_starts(max_idx):rest_ends(max_idx)));
    else
        max_duration = 0;
        I_best_rest = I_bias;
    end
    
    %% ========== CREATE STATS STRUCTURE ==========
    stats.I_bias = I_bias;
    stats.I_std = I_std;
    stats.I_median = I_median;
    stats.I_best_rest = I_best_rest;
    stats.n_rest_points = sum(rest_mask);
    stats.rest_fraction = sum(rest_mask) / length(I);
    stats.n_rest_periods = length(rest_starts);
    stats.longest_rest_duration = max_duration;
    stats.method = 'mean of rest periods';
    
    fprintf('   Found %d rest periods (%.1f%% of data)\n', ...
        stats.n_rest_periods, stats.rest_fraction*100);
    fprintf('   Longest rest: %.1f s\n', max_duration);
    fprintf('   Estimated bias: %.3f mA\n', I_bias*1000);
    fprintf('   Standard deviation: %.3f mA\n', I_std*1000);
    
    %% ========== PLOT BIAS ESTIMATION ==========
    figure('Name', 'Current Bias Estimation', 'Position', [100, 100, 1200, 500]);
    
    subplot(1,2,1);
    plot(t/3600, I*1000, 'b-', 'LineWidth', 1); hold on;
    plot(t(rest_mask)/3600, I(rest_mask)*1000, 'r.', 'MarkerSize', 10);
    yline(I_bias*1000, 'g--', 'LineWidth', 2);
    xlabel('Time (hours)'); ylabel('Current (mA)');
    title('Current Profile with Rest Periods');
    legend('All data', 'Rest periods', 'Estimated bias');
    grid on;
    
    subplot(1,2,2);
    histogram(I_rest*1000, 30, 'FaceColor', [0.2, 0.6, 0.8]);
    xlabel('Current during rest (mA)'); ylabel('Frequency');
    title('Rest Current Distribution');
    grid on;
    xline(I_bias*1000, 'r-', 'LineWidth', 2);
    xline(I_bias*1000 + [-I_std, I_std]*1000, 'r--', 'LineWidth', 1);
    
    sgtitle('Current Sensor Bias Estimation', 'FontSize', 14, 'FontWeight', 'bold');
    
end