%% DEGRADATION TRENDS ANALYSIS - SOH ESTIMATION
% Computes SOH from capacity fade and resistance growth
% 
% SOH_Q(k) = Q(k) / Q(1)      - Capacity-based SOH
% SOH_R(k) = R0(1) / R0(k)    - Resistance-based SOH
% SOH = wQ * SOH_Q + wR * SOH_R  - Fused SOH
%
% File: matlab/05_degradation/degradation_trends.m

clear; clc; close all;

cd('C:\Users\Krupal Babariya\Desktop\battery-bms-ecm-soc-soh\');
addpath(genpath('matlab'));

fprintf('========================================\n');
fprintf('📊 DEGRADATION TRENDS ANALYSIS\n');
fprintf('========================================\n\n');

%% ========== LOAD DATA ==========
fprintf('📂 Loading degradation data...\n');

% Load parameter degradation data from Phase 6.4
if exist('data/processed/B0005_degradation_trends.mat', 'file')
    load('data/processed/B0005_degradation_trends.mat', 'degradation_data');
    
    cycles = degradation_data.cycles;
    Q = degradation_data.Q;
    R0 = degradation_data.R0;
    R1 = degradation_data.R1;
    C1 = degradation_data.C1;
    rmse = degradation_data.rmse;
    
    fprintf('✅ Loaded degradation data for %d cycles\n', length(cycles));
else
    % If degradation data doesn't exist, create sample data
    fprintf('⚠️  Degradation data not found. Creating sample data...\n');
    
    % Create synthetic degradation trends for demonstration
    cycles = [1, 20, 50, 80, 100, 120, 140, 160, 168]';
    Q = 1.862 * (1 - 0.0015 * (cycles-1));  % Linear fade
    R0 = 0.1767 * (1 + 0.002 * (cycles-1)); % Linear growth
    R1 = 0.2 * ones(size(cycles));
    C1 = 40000 * ones(size(cycles));
    rmse = 180 * ones(size(cycles));
    
    fprintf('✅ Created sample degradation data\n');
end

n_cycles = length(cycles);
fprintf('   Cycle range: %d - %d\n', cycles(1), cycles(end));
fprintf('   Capacity range: %.3f - %.3f Ah\n', Q(1), Q(end));
fprintf('   R0 range: %.4f - %.4f Ω\n\n', R0(1), R0(end));

%% ========== COMPUTE SOH METRICS ==========
fprintf('📊 Computing SOH metrics...\n');

% Capacity-based SOH
SOH_Q = Q / Q(1) * 100;  % Percentage

% Resistance-based SOH (one simple form)
SOH_R = R0(1) ./ R0 * 100;  % Percentage

% Fused SOH (weighted average)
wQ = 0.7;   % Weight for capacity (primary indicator)
wR = 0.3;   % Weight for resistance (secondary indicator)
SOH_fused = wQ * SOH_Q + wR * SOH_R;

fprintf('   SOH_Q range: %.1f - %.1f%%\n', SOH_Q(end), SOH_Q(1));
fprintf('   SOH_R range: %.1f - %.1f%%\n', SOH_R(end), SOH_R(1));
fprintf('   SOH_fused range: %.1f - %.1f%%\n\n', SOH_fused(end), SOH_fused(1));

%% ========== CREATE RESULTS TABLE ==========
results_table = table();
results_table.Cycle = cycles;
results_table.Capacity_Ah = Q;
results_table.R0_mOhm = R0 * 1000;
results_table.R1_mOhm = R1 * 1000;
results_table.SOH_Q_percent = SOH_Q;
results_table.SOH_R_percent = SOH_R;
results_table.SOH_fused_percent = SOH_fused;

disp('📋 Degradation Summary:');
disp(results_table);

%% ========== PLOT DEGRADATION TRENDS ==========
figure('Position', [100, 100, 1600, 1000]);

% Plot 1: Capacity vs Cycle
subplot(2,3,1);
plot(cycles, Q, 'b-o', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'b');
xlabel('Cycle Number'); ylabel('Capacity (Ah)');
title('Capacity Fade');
grid on;
ylim([min(Q)*0.95, max(Q)*1.05]);

% Plot 2: R0 vs Cycle
subplot(2,3,2);
plot(cycles, R0*1000, 'r-s', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'r');
xlabel('Cycle Number'); ylabel('R0 (mΩ)');
title('Resistance Growth');
grid on;

% Plot 3: SOH Metrics Comparison
subplot(2,3,3);
plot(cycles, SOH_Q, 'b-o', 'LineWidth', 2, 'MarkerSize', 6, 'DisplayName', 'SOH_Q (Capacity)'); hold on;
plot(cycles, SOH_R, 'r-s', 'LineWidth', 2, 'MarkerSize', 6, 'DisplayName', 'SOH_R (Resistance)');
plot(cycles, SOH_fused, 'g-^', 'LineWidth', 2, 'MarkerSize', 6, 'DisplayName', 'SOH_Fused');
xlabel('Cycle Number'); ylabel('SOH (%)');
title('State of Health Comparison');
legend('Location', 'best');
grid on;
ylim([50, 105]);
yline(80, 'k--', 'End of Life (80%)', 'LineWidth', 1.5);

% Plot 4: R1 vs Cycle (optional)
subplot(2,3,4);
plot(cycles, R1*1000, 'm-d', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'm');
xlabel('Cycle Number'); ylabel('R1 (mΩ)');
title('Polarization Resistance');
grid on;

% Plot 5: RMSE vs Cycle (fit quality)
subplot(2,3,5);
plot(cycles, rmse, 'k-v', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'k');
xlabel('Cycle Number'); ylabel('RMSE (mV)');
title('Model Fit Quality');
grid on;

% Plot 6: Fused SOH with EOL indicator
subplot(2,3,6);
plot(cycles, SOH_fused, 'g-^', 'LineWidth', 2, 'MarkerSize', 8, 'MarkerFaceColor', 'g'); hold on;
xlabel('Cycle Number'); ylabel('SOH (%)');
title('Fused State of Health');
grid on;
ylim([50, 105]);
yline(80, 'k--', 'End of Life (80%)', 'LineWidth', 1.5);

% Find cycle where SOH crosses 80%
eol_idx = find(SOH_fused <= 80, 1, 'first');
if ~isempty(eol_idx)
    eol_cycle = cycles(eol_idx);
    plot(eol_cycle, 80, 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
    text(eol_cycle, 82, sprintf(' EOL at cycle %d', eol_cycle), 'FontSize', 10);
end

sgtitle('B0005 - Degradation Trends Analysis', 'FontSize', 14, 'FontWeight', 'bold');

%% ========== FIT DEGRADATION MODELS ==========
fprintf('\n📈 Fitting degradation models...\n');

% Normalize cycles to start at 1
x = (1:n_cycles)';

% 1. Linear model for capacity
p_lin_Q = polyfit(x, Q, 1);
Q_lin_fit = polyval(p_lin_Q, x);

% 2. Exponential model for capacity (optional)
% Q = a * exp(b * x) + c
exp_fun = @(b, x) b(1) * exp(b(2) * x) + b(3);
b0 = [Q(1), -0.001, 0];
try
    b_opt = lsqcurvefit(exp_fun, b0, x, Q, [0, -0.1, 0], [2, 0, 2]);
    Q_exp_fit = exp_fun(b_opt, x);
    exp_success = true;
catch
    exp_success = false;
end

% 3. Linear model for R0
p_lin_R0 = polyfit(x, R0, 1);
R0_lin_fit = polyval(p_lin_R0, x);

% 4. Linear model for SOH_fused
p_lin_SOH = polyfit(x, SOH_fused, 1);
SOH_lin_fit = polyval(p_lin_SOH, x);

fprintf('\n📊 Model Parameters:\n');
fprintf('   Capacity Linear: Q = %.4f - %.4f * cycle\n', p_lin_Q(2), -p_lin_Q(1));
fprintf('   Capacity fade rate: %.2f mAh/cycle\n', -p_lin_Q(1)*1000);
fprintf('   R0 Linear: R0 = %.4f + %.4f * cycle (mΩ)\n', p_lin_R0(2)*1000, p_lin_R0(1)*1000);
fprintf('   R0 growth rate: %.2f μΩ/cycle\n', p_lin_R0(1)*1e6);
fprintf('   SOH Linear: SOH = %.2f - %.2f * cycle\n', p_lin_SOH(2), -p_lin_SOH(1));
fprintf('   SOH fade rate: %.2f %% per 100 cycles\n', -p_lin_SOH(1)*100);

if exp_success
    fprintf('   Exponential: Q = %.3f * exp(%.4f * cycle) + %.3f\n', b_opt(1), b_opt(2), b_opt(3));
end

%% ========== PLOT DEGRADATION MODELS ==========
figure('Position', [100, 100, 1400, 600]);

% Capacity with models
subplot(1,3,1);
plot(cycles, Q, 'bo', 'MarkerSize', 8, 'MarkerFaceColor', 'b', 'DisplayName', 'Data'); hold on;
plot(cycles, Q_lin_fit, 'r-', 'LineWidth', 2, 'DisplayName', 'Linear Fit');
if exp_success
    plot(cycles, Q_exp_fit, 'g--', 'LineWidth', 2, 'DisplayName', 'Exponential Fit');
end
xlabel('Cycle Number'); ylabel('Capacity (Ah)');
title('Capacity Fade Models');
legend('Location', 'best');
grid on;

% R0 with linear model
subplot(1,3,2);
plot(cycles, R0*1000, 'bo', 'MarkerSize', 8, 'MarkerFaceColor', 'b', 'DisplayName', 'Data'); hold on;
plot(cycles, R0_lin_fit*1000, 'r-', 'LineWidth', 2, 'DisplayName', 'Linear Fit');
xlabel('Cycle Number'); ylabel('R0 (mΩ)');
title('Resistance Growth Model');
legend('Location', 'best');
grid on;

% SOH with linear model and EOL prediction
subplot(1,3,3);
plot(cycles, SOH_fused, 'bo', 'MarkerSize', 8, 'MarkerFaceColor', 'b', 'DisplayName', 'Data'); hold on;
plot(cycles, SOH_lin_fit, 'r-', 'LineWidth', 2, 'DisplayName', 'Linear Fit');
xlabel('Cycle Number'); ylabel('SOH (%)');
title('SOH Model with EOL Prediction');
legend('Location', 'best');
grid on;
ylim([50, 105]);
yline(80, 'k--', 'End of Life (80%)', 'LineWidth', 1.5);

% Predict EOL from linear model
if p_lin_SOH(1) < 0
    eol_linear = (80 - p_lin_SOH(2)) / p_lin_SOH(1);
    xline(eol_linear, 'g--', sprintf('EOL: cycle %.0f', eol_linear));
end

sgtitle('Degradation Model Fitting', 'FontSize', 14, 'FontWeight', 'bold');

%% ========== PREDICT REMAINING USEFUL LIFE ==========
fprintf('\n🔮 Remaining Useful Life (RUL) Prediction:\n');

% Current cycle
current_cycle = cycles(end);
current_SOH = SOH_fused(end);

% Predict cycles to reach 80% SOH
if p_lin_SOH(1) < 0
    cycles_to_eol = (80 - current_SOH) / p_lin_SOH(1);
    eol_cycle = current_cycle + cycles_to_eol;
    
    fprintf('   Current cycle: %d\n', current_cycle);
    fprintf('   Current SOH: %.1f%%\n', current_SOH);
    fprintf('   Predicted EOL cycle: %.0f\n', eol_cycle);
    fprintf('   Remaining cycles: %.0f\n', cycles_to_eol);
    fprintf('   Estimated remaining capacity: %.3f Ah\n', polyval(p_lin_Q, eol_cycle));
end

%% ========== SAVE RESULTS ==========
degradation_results.cycles = cycles;
degradation_results.Q = Q;
degradation_results.R0 = R0;
degradation_results.R1 = R1;
degradation_results.SOH_Q = SOH_Q;
degradation_results.SOH_R = SOH_R;
degradation_results.SOH_fused = SOH_fused;
degradation_results.weights = struct('wQ', wQ, 'wR', wR);
degradation_results.models.linear_Q = p_lin_Q;
degradation_results.models.linear_R0 = p_lin_R0;
degradation_results.models.linear_SOH = p_lin_SOH;
if exp_success
    degradation_results.models.exponential_Q = b_opt;
end
degradation_results.EOL_prediction.cycle = eol_cycle;
degradation_results.EOL_prediction.rul_cycles = cycles_to_eol;

save('data/processed/B0005_degradation_results.mat', 'degradation_results');
fprintf('\n💾 Saved: data/processed/B0005_degradation_results.mat\n');

%% ========== SUMMARY ==========
fprintf('\n========================================\n');
fprintf('📊 DEGRADATION ANALYSIS SUMMARY\n');
fprintf('========================================\n');
fprintf('   Initial capacity: %.3f Ah\n', Q(1));
fprintf('   Final capacity: %.3f Ah\n', Q(end));
fprintf('   Capacity fade: %.1f%%\n', (1 - Q(end)/Q(1))*100);
fprintf('   Initial R0: %.1f mΩ\n', R0(1)*1000);
fprintf('   Final R0: %.1f mΩ\n', R0(end)*1000);
fprintf('   R0 increase: %.1f%%\n', (R0(end)/R0(1)-1)*100);
fprintf('   Initial SOH: %.1f%%\n', SOH_fused(1));
fprintf('   Final SOH: %.1f%%\n', SOH_fused(end));
fprintf('   Predicted EOL cycle: %.0f\n', eol_cycle);
fprintf('========================================\n');