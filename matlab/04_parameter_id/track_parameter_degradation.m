%% TRACK 1-RC ECM PARAMETERS OVER MULTIPLE CYCLES
% Fits parameters for selected cycles and tracks degradation
%
% File: matlab/04_parameter_id/track_parameter_degradation.m

clear; clc; close all;

cd('C:\Users\Krupal Babariya\Desktop\battery-bms-ecm-soc-soh\');
addpath(genpath('matlab'));

fprintf('========================================\n');
fprintf('📊 PARAMETER DEGRADATION TRACKING\n');
fprintf('========================================\n\n');

%% ========== LOAD DATA ==========
fprintf('📂 Loading data...\n');

load('data/processed/cell01_cycles.mat', 'cycles');
load('data/processed/B0005_OCV_manual.mat', 'ocv_data');

% Find all discharge cycles
discharge_indices = [];
for i = 1:length(cycles)
    if strcmp(cycles(i).type, 'discharge')
        discharge_indices = [discharge_indices, i];
    end
end

fprintf('✅ Found %d discharge cycles\n\n', length(discharge_indices));

%% ========== SELECT CYCLES TO FIT ==========
% Choose cycles to analyze (early, middle, late life)
cycle_selection = [1, 20, 50, 80, 100, 120, 140, 160, 168];
% Make sure we don't exceed available cycles
cycle_selection = cycle_selection(cycle_selection <= length(discharge_indices));

fprintf('📊 Fitting %d selected cycles:\n', length(cycle_selection));
fprintf('   ');
fprintf('%d ', discharge_indices(cycle_selection));
fprintf('\n\n');

%% ========== INITIALIZE STORAGE ==========
n_cycles = length(cycle_selection);
R0_history = zeros(n_cycles, 1);
R1_history = zeros(n_cycles, 1);
C1_history = zeros(n_cycles, 1);
tau_history = zeros(n_cycles, 1);
rmse_history = zeros(n_cycles, 1);
Q_history = zeros(n_cycles, 1);
cycle_numbers = discharge_indices(cycle_selection)';

%% ========== FIT EACH SELECTED CYCLE ==========
fprintf('🔧 Fitting parameters for each cycle...\n');

for k = 1:n_cycles
    cycle_idx = cycle_numbers(k);
    d = cycles(cycle_idx);
    
    fprintf('\n🔄 Cycle %d (index %d):\n', k, cycle_idx);
    
    % Trim to discharge only
    current_threshold = 0.1;
    start_idx = find(abs(d.I) > current_threshold, 1, 'first');
    end_idx = find(abs(d.I) > current_threshold, 1, 'last');
    
    if isempty(start_idx) || isempty(end_idx)
        fprintf('   ⚠️  No valid discharge data, skipping\n');
        continue;
    end
    
    % Create cycle_data structure with proper numeric arrays
    cycle_data = struct();
    cycle_data.time = double(d.time(start_idx:end_idx) - d.time(start_idx));
    cycle_data.I = double(d.I(start_idx:end_idx));
    cycle_data.V = double(d.V(start_idx:end_idx));
    cycle_data.Q = double(d.Q);
    
    fprintf('   Points: %d, Duration: %.1f s, I = %.3f A\n', ...
        length(cycle_data.time), cycle_data.time(end), mean(abs(cycle_data.I)));
    
    % Use previous cycle's parameters as initial guess (except first)
    if k == 1
        x0 = [0.15, 0.08, 40000];  % Default initial guess
    else
        x0 = [R0_history(k-1), R1_history(k-1), C1_history(k-1)];
    end
    
    % Fit parameters
    [x_opt, fval] = fit_ecm_1rc(cycle_data, ocv_data, x0);
    
    % Store results
    R0_history(k) = x_opt(1);
    R1_history(k) = x_opt(2);
    C1_history(k) = x_opt(3);
    tau_history(k) = x_opt(2) * x_opt(3);
    rmse_history(k) = fval;
    Q_history(k) = cycle_data.Q;
    
    fprintf('   ✅ R0=%.4f, R1=%.4f, C1=%.0f, Q=%.3f Ah, RMSE=%.1f mV\n', ...
        x_opt(1), x_opt(2), x_opt(3), cycle_data.Q, fval);
end

%% ========== PLOT DEGRADATION TRENDS ==========
figure('Position', [100, 100, 1600, 1000]);

% Plot 1: R0 vs Cycle
subplot(2,3,1);
plot(1:n_cycles, R0_history*1000, 'b-o', 'LineWidth', 2, 'MarkerSize', 6);
xlabel('Cycle Number'); ylabel('R0 (mΩ)');
title('Series Resistance Growth');
grid on;
set(gca, 'XTick', 1:n_cycles, 'XTickLabel', cycle_numbers);

% Plot 2: R1 vs Cycle
subplot(2,3,2);
plot(1:n_cycles, R1_history*1000, 'r-s', 'LineWidth', 2, 'MarkerSize', 6);
xlabel('Cycle Number'); ylabel('R1 (mΩ)');
title('Polarization Resistance Growth');
grid on;
set(gca, 'XTick', 1:n_cycles, 'XTickLabel', cycle_numbers);

% Plot 3: C1 vs Cycle
subplot(2,3,3);
plot(1:n_cycles, C1_history/1000, 'g-^', 'LineWidth', 2, 'MarkerSize', 6);
xlabel('Cycle Number'); ylabel('C1 (kF)');
title('Polarization Capacitance');
grid on;
set(gca, 'XTick', 1:n_cycles, 'XTickLabel', cycle_numbers);

% Plot 4: Time Constant vs Cycle
subplot(2,3,4);
plot(1:n_cycles, tau_history, 'm-d', 'LineWidth', 2, 'MarkerSize', 6);
xlabel('Cycle Number'); ylabel('τ (s)');
title('Time Constant (R1×C1)');
grid on;
set(gca, 'XTick', 1:n_cycles, 'XTickLabel', cycle_numbers);

% Plot 5: Capacity vs Cycle
subplot(2,3,5);
plot(1:n_cycles, Q_history, 'c-o', 'LineWidth', 2, 'MarkerSize', 6);
xlabel('Cycle Number'); ylabel('Capacity (Ah)');
title('Capacity Fade');
grid on;
set(gca, 'XTick', 1:n_cycles, 'XTickLabel', cycle_numbers);

% Plot 6: Fit Quality
subplot(2,3,6);
plot(1:n_cycles, rmse_history, 'k-v', 'LineWidth', 2, 'MarkerSize', 6);
xlabel('Cycle Number'); ylabel('RMSE (mV)');
title('Model Fit Quality');
grid on;
set(gca, 'XTick', 1:n_cycles, 'XTickLabel', cycle_numbers);

sgtitle('B0005 - Parameter Degradation Over Cycles', 'FontSize', 14, 'FontWeight', 'bold');

%% ========== CREATE SUMMARY TABLE ==========
results_table = table();
results_table.Cycle = cycle_numbers;
results_table.R0_mOhm = R0_history * 1000;
results_table.R1_mOhm = R1_history * 1000;
results_table.C1_kF = C1_history / 1000;
results_table.tau_s = tau_history;
results_table.Capacity_Ah = Q_history;
results_table.RMSE_mV = rmse_history;

disp(results_table);

%% ========== SAVE RESULTS ==========
degradation_data.cycles = cycle_numbers;
degradation_data.R0 = R0_history;
degradation_data.R1 = R1_history;
degradation_data.C1 = C1_history;
degradation_data.tau = tau_history;
degradation_data.Q = Q_history;
degradation_data.rmse = rmse_history;
degradation_data.cycle_indices = cycle_numbers;

save('data/processed/B0005_degradation_trends.mat', 'degradation_data');
fprintf('\n💾 Saved: data/processed/B0005_degradation_trends.mat\n');

%% ========== FIT DEGRADATION MODELS ==========
fprintf('\n📈 Degradation Trend Analysis:\n');

% R0 growth (typically linear)
p_R0 = polyfit(1:n_cycles, R0_history, 1);
fprintf('   R0 growth: %.2f μΩ/cycle\n', p_R0(1)*1000);

% Capacity fade (typically linear)
p_Q = polyfit(1:n_cycles, Q_history, 1);
fprintf('   Capacity fade: %.3f mAh/cycle\n', -p_Q(1)*1000);
fprintf('   Initial capacity: %.3f Ah\n', Q_history(1));
fprintf('   Final capacity: %.3f Ah\n', Q_history(end));
fprintf('   Total fade: %.1f%%\n', (1 - Q_history(end)/Q_history(1))*100);