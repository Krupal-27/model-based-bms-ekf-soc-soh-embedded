%% BATCH FIT 1-RC ECM PARAMETERS FOR ALL DISCHARGE CYCLES
% Tracks how R0, R1, C1 change with aging
%
% File: matlab/03_ecm_model/batch_fit_1RC.m

clear; clc; close all;

%% ========== SETUP ==========
cd('C:\Users\Krupal Babariya\Desktop\battery-bms-ecm-soc-soh\');
addpath(genpath('matlab'));

fprintf('========================================\n');
fprintf('🔧 BATCH 1-RC ECM PARAMETER IDENTIFICATION\n');
fprintf('========================================\n\n');

%% ========== LOAD DISCHARGE CURVES ==========
if exist('data/processed/B0005_discharge_curves.mat', 'file')
    load('data/processed/B0005_discharge_curves.mat', 'discharge_data');
    fprintf('✅ Loaded %d discharge curves for B0005\n\n', length(discharge_data));
else
    error('❌ Please run extract_discharge_curves.m first');
end

%% ========== FIT MODEL TO EACH DISCHARGE CYCLE ==========
n_cycles = length(discharge_data);
R0_history = zeros(n_cycles, 1);
R1_history = zeros(n_cycles, 1);
C1_history = zeros(n_cycles, 1);
tau_history = zeros(n_cycles, 1);
rmse_history = zeros(n_cycles, 1);
cycle_numbers = (1:n_cycles)';

fprintf('🔄 Fitting 1-RC model to %d discharge cycles...\n\n', n_cycles);

for i = 1:n_cycles
    fprintf('   Cycle %3d/%3d: ', i, n_cycles);
    
    try
        % Fit model (disable plots for batch processing)
        params = fit_1RC_model(discharge_data(i), false);
        
        % Store parameters
        R0_history(i) = params.R0;
        R1_history(i) = params.R1;
        C1_history(i) = params.C1;
        tau_history(i) = params.tau;
        rmse_history(i) = params.fit_metrics.rmse;
        
        fprintf('R0=%.4f, R1=%.4f, C1=%.1f, RMSE=%.4f\n', ...
            params.R0, params.R1, params.C1, params.fit_metrics.rmse);
        
    catch ME
        fprintf('❌ Failed: %s\n', ME.message);
        R0_history(i) = NaN;
        R1_history(i) = NaN;
        C1_history(i) = NaN;
        tau_history(i) = NaN;
        rmse_history(i) = NaN;
    end
end

%% ========== SAVE PARAMETER EVOLUTION ==========
ecm_history = table();
ecm_history.cycle = cycle_numbers;
ecm_history.R0_Ohm = R0_history;
ecm_history.R1_Ohm = R1_history;
ecm_history.C1_F = C1_history;
ecm_history.tau_s = tau_history;
ecm_history.RMSE_V = rmse_history;

save('data/processed/B0005_1RC_evolution.mat', 'ecm_history');
fprintf('\n💾 Saved: data/processed/B0005_1RC_evolution.mat\n');

%% ========== PLOT PARAMETER EVOLUTION ==========
figure('Name', '1-RC ECM Parameter Evolution', 'Position', [100, 100, 1400, 900]);

% Plot 1: R0 vs Cycle
subplot(2,3,1);
plot(ecm_history.cycle, ecm_history.R0_Ohm * 1000, 'b-o', ...
    'LineWidth', 1.5, 'MarkerSize', 4);
xlabel('Cycle Number');
ylabel('R0 (mΩ)');
title('Series Resistance');
grid on;

% Plot 2: R1 vs Cycle
subplot(2,3,2);
plot(ecm_history.cycle, ecm_history.R1_Ohm * 1000, 'r-s', ...
    'LineWidth', 1.5, 'MarkerSize', 4);
xlabel('Cycle Number');
ylabel('R1 (mΩ)');
title('Polarization Resistance');
grid on;

% Plot 3: C1 vs Cycle
subplot(2,3,3);
plot(ecm_history.cycle, ecm_history.C1_F, 'g-^', ...
    'LineWidth', 1.5, 'MarkerSize', 4);
xlabel('Cycle Number');
ylabel('C1 (F)');
title('Polarization Capacitance');
grid on;

% Plot 4: Time Constant vs Cycle
subplot(2,3,4);
plot(ecm_history.cycle, ecm_history.tau_s, 'm-d', ...
    'LineWidth', 1.5, 'MarkerSize', 4);
xlabel('Cycle Number');
ylabel('τ (s)');
title('Time Constant R1*C1');
grid on;

% Plot 5: RMSE vs Cycle (model quality)
subplot(2,3,5);
plot(ecm_history.cycle, ecm_history.RMSE_V * 1000, 'k-v', ...
    'LineWidth', 1.5, 'MarkerSize', 4);
xlabel('Cycle Number');
ylabel('RMSE (mV)');
title('Model Fit Quality');
grid on;
ylim([0, max(ecm_history.RMSE_V*1000)*1.1]);

% Plot 6: Capacity vs Cycle (for reference)
subplot(2,3,6);
load('data/processed/cell01_capacity.mat', 'capacity_data');
plot(capacity_data.cycle_idx, capacity_data.capacity_Ah, 'c-o', ...
    'LineWidth', 1.5, 'MarkerSize', 4);
xlabel('Cycle Number');
ylabel('Capacity (Ah)');
title('Capacity Fade');
grid on;

sgtitle('B0005 - 1-RC ECM Parameter Evolution with Aging', ...
    'FontSize', 14, 'FontWeight', 'bold');

%% ========== SUMMARY ==========
fprintf('\n========================================\n');
fprintf('🎉 BATCH ECM FITTING COMPLETE!\n');
fprintf('========================================\n');
fprintf('   📊 Processed: %d cycles\n', n_cycles);
fprintf('   📈 R0 range: %.1f - %.1f mΩ\n', ...
    min(R0_history)*1000, max(R0_history)*1000);
fprintf('   📈 R1 range: %.1f - %.1f mΩ\n', ...
    min(R1_history)*1000, max(R1_history)*1000);
fprintf('   📈 C1 range: %.1f - %.1f F\n', ...
    min(C1_history), max(C1_history));
fprintf('   ✅ Avg RMSE: %.1f mV\n', mean(rmse_history)*1000);
fprintf('========================================\n');