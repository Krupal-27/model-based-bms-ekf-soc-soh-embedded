%% SELECT BEST CYCLE FOR PARAMETER FITTING
% We want a cycle with rich dynamics (not perfectly constant current)
% The NASA dataset has discharge cycles with constant current - not ideal!
% But we'll use the first discharge cycle anyway

clear; clc; close all;

cd('C:\Users\Krupal Babariya\Desktop\battery-bms-ecm-soc-soh\');
addpath(genpath('matlab'));

fprintf('========================================\n');
fprintf('🔍 SELECTING FITTING CYCLE\n');
fprintf('========================================\n\n');

%% ========== LOAD ALL CYCLES ==========
load('data/processed/cell01_cycles.mat', 'cycles');

% Find all discharge cycles
discharge_indices = [];
for i = 1:length(cycles)
    if strcmp(cycles(i).type, 'discharge')
        discharge_indices = [discharge_indices, i];
    end
end

fprintf('📊 Found %d discharge cycles\n\n', length(discharge_indices));

%% ========== ANALYZE EACH DISCHARGE CYCLE ==========
fprintf('📊 Analyzing discharge cycles:\n');
fprintf('   %-5s %-10s %-12s %-12s %-12s\n', ...
    'Idx', 'Cycle#', 'Duration(s)', 'I_mean(A)', 'I_std(A)');

best_cycle = [];
best_dynamics = -inf;

for idx = 1:min(10, length(discharge_indices))
    cycle_num = discharge_indices(idx);
    d = cycles(cycle_num);
    
    % Trim to actual discharge
    current_threshold = 0.1;
    start_idx = find(abs(d.I) > current_threshold, 1, 'first');
    end_idx = find(abs(d.I) > current_threshold, 1, 'last');
    
    I_seg = d.I(start_idx:end_idx);
    t_seg = d.time(start_idx:end_idx) - d.time(start_idx);
    
    duration = t_seg(end);
    I_mean = mean(abs(I_seg));
    I_std = std(I_seg);
    
    % Measure of dynamics (how much current varies)
    dynamics = I_std / I_mean;  % Higher = more variation
    
    fprintf('   %3d   %6d   %10.1f   %10.3f   %10.3f  %s\n', ...
        idx, cycle_num, duration, I_mean, I_std, ...
        repmat('*', 1, round(dynamics*20)));
    
    if dynamics > best_dynamics
        best_dynamics = dynamics;
        best_cycle = cycle_num;
    end
end

fprintf('\n✅ Best cycle for fitting: Cycle #%d\n', best_cycle);
fprintf('   (Highest current variation: %.3f)\n\n', best_dynamics);

%% ========== PLOT THE SELECTED CYCLE ==========
d = cycles(best_cycle);

% Trim
start_idx = find(abs(d.I) > 0.1, 1, 'first');
end_idx = find(abs(d.I) > 0.1, 1, 'last');
t_fit = d.time(start_idx:end_idx) - d.time(start_idx);
V_fit = d.V(start_idx:end_idx);
I_fit = d.I(start_idx:end_idx);

figure('Position', [100, 100, 1200, 500]);

subplot(1,2,1);
plot(t_fit, V_fit, 'b-', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('Voltage (V)');
title(sprintf('Cycle #%d - Voltage', best_cycle));
grid on;

subplot(1,2,2);
plot(t_fit, I_fit, 'r-', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('Current (A)');
title(sprintf('Cycle #%d - Current', best_cycle));
grid on;

sgtitle('Selected Cycle for Parameter Fitting', 'FontSize', 14);

%% ========== SAVE FITTING DATA ==========
fitting_data.time = t_fit;
fitting_data.V = V_fit;
fitting_data.I = I_fit;
fitting_data.Q = d.Q;
fitting_data.cycle_num = best_cycle;

save('data/processed/fitting_cycle.mat', 'fitting_data');
fprintf('💾 Saved fitting data to data/processed/fitting_cycle.mat\n');