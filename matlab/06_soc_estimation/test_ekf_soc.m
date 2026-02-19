%% TEST EKF SOC ESTIMATION
clear; clc; close all;

cd('C:\Users\Krupal Babariya\Desktop\battery-bms-ecm-soc-soh\');
addpath(genpath('matlab'));

fprintf('========================================\n');
fprintf('🔧 TEST EKF SOC ESTIMATION\n');
fprintf('========================================\n\n');

%% ========== LOAD DATA ==========
fprintf('📂 Loading test data...\n');

load('data/processed/cell01_cycles.mat', 'cycles');
load('data/processed/B0005_OCV_manual.mat', 'ocv_data');

% Use a discharge cycle for testing
d = cycles(4);  % First discharge cycle

% Trim to discharge only
current_threshold = 0.1;
start_idx = find(abs(d.I) > current_threshold, 1, 'first');
end_idx = find(abs(d.I) > current_threshold, 1, 'last');

t = d.time(start_idx:end_idx) - d.time(start_idx);
I = d.I(start_idx:end_idx);
V_meas = d.V(start_idx:end_idx);
Q = d.Q;

fprintf('✅ Loaded cycle #4\n');
fprintf('   Points: %d\n', length(t));
fprintf('   Duration: %.1f s\n', t(end));
fprintf('   Current: %.3f A\n', mean(abs(I)));
fprintf('   Capacity: %.3f Ah\n\n', Q);

%% ========== SET ECM PARAMETERS ==========
params.R0 = 0.2112;
params.R1 = 2.0;
params.C1 = 40000;
params.Q_nom = Q;

fprintf('📊 ECM Parameters:\n');
fprintf('   R0 = %.4f Ω\n', params.R0);
fprintf('   R1 = %.4f Ω\n', params.R1);
fprintf('   C1 = %.0f F\n', params.C1);
fprintf('   τ = %.1f s\n\n', params.R1 * params.C1);

%% ========== GENERATE TRUE SOC (COULOMB COUNTING) ==========
fprintf('📊 Generating true SOC reference...\n');
[SOC_true, ~] = soc_coulomb(I, t, Q, 1.0, 0);
fprintf('   True SOC range: %.3f - %.3f\n', SOC_true(1), SOC_true(end));

%% ========== RUN EKF ==========
fprintf('\n🔧 Running EKF SOC estimation...\n');

% EKF parameters
SOC0 = 0.9;  % Start with 10% error to test convergence
P0 = diag([0.1, 0.01]);  % Initial uncertainty
Q = diag([1e-5, 1e-4]);  % Process noise
R = 0.001;  % Measurement noise (1mV variance)

[SOC_est, V1_est, P_history, innovations] = ekf_soc_with_measurements(...
    I, V_meas, t, params, ocv_data, SOC0, P0, Q, R);

%% ========== CALCULATE ERRORS ==========
SOC_error = SOC_est - SOC_true;
rmse = rms(SOC_error) * 100;  % in %
max_error = max(abs(SOC_error)) * 100;
final_error = SOC_error(end) * 100;

fprintf('\n📊 EKF Performance:\n');
fprintf('   RMSE: %.2f%%\n', rmse);
fprintf('   Max error: %.2f%%\n', max_error);
fprintf('   Final error: %.2f%%\n', final_error);

%% ========== PLOT RESULTS ==========
figure('Position', [100, 100, 1600, 1000]);

% Plot 1: SOC comparison
subplot(2,3,1);
plot(t/3600, SOC_true*100, 'b-', 'LineWidth', 2, 'DisplayName', 'True SOC'); hold on;
plot(t/3600, SOC_est*100, 'r--', 'LineWidth', 1.5, 'DisplayName', 'EKF Estimate');
plot(t/3600, ones(size(t))*SOC0*100, 'g:', 'LineWidth', 1, 'DisplayName', 'Initial Guess');
xlabel('Time (hours)'); ylabel('SOC (%)');
title('SOC Estimation Comparison');
legend('Location', 'best');
grid on; ylim([0, 100]);

% Plot 2: SOC error
subplot(2,3,2);
plot(t/3600, SOC_error*100, 'k-', 'LineWidth', 1.5);
xlabel('Time (hours)'); ylabel('SOC Error (%)');
title(sprintf('SOC Error (RMSE = %.2f%%)', rmse));
grid on; yline(0, 'r--');
yline([-5, 5], 'g--', '±5%');

% Plot 3: Innovations (voltage residuals)
subplot(2,3,3);
plot(t/3600, innovations*1000, 'm-', 'LineWidth', 1);
xlabel('Time (hours)'); ylabel('Innovation (mV)');
title('Voltage Innovations');
grid on; yline(0, 'r--');

% Plot 4: Covariance trace
subplot(2,3,4);
cov_trace = squeeze(P_history(1,1,:) + P_history(2,2,:));
plot(t/3600, cov_trace, 'b-', 'LineWidth', 1.5);
xlabel('Time (hours)'); ylabel('Trace(P)');
title('State Covariance');
grid on; set(gca, 'YScale', 'log');

% Plot 5: V1 estimate
subplot(2,3,5);
plot(t/3600, V1_est*1000, 'c-', 'LineWidth', 1.5);
xlabel('Time (hours)'); ylabel('V1 (mV)');
title('Polarization Voltage Estimate');
grid on;

% Plot 6: Final SOC distribution
subplot(2,3,6);
final_SOC = [SOC_true(end), SOC_est(end)] * 100;
bar(final_SOC, 'FaceColor', [0.3, 0.6, 0.8]);
set(gca, 'XTickLabel', {'True', 'EKF'});
ylabel('Final SOC (%)');
title(sprintf('Final SOC (Error = %.2f%%)', final_error));
grid on; ylim([0, 100]);

sgtitle('EKF SOC Estimation Results', 'FontSize', 14, 'FontWeight', 'bold');

%% ========== SAVE RESULTS ==========
results.SOC_true = SOC_true;
results.SOC_est = SOC_est;
results.SOC_error = SOC_error;
results.rmse_percent = rmse;
results.innovations = innovations;
results.params = params;

save('data/processed/ekf_results.mat', 'results');
fprintf('\n💾 Saved: data/processed/ekf_results.mat\n');

%% ========== SUMMARY ==========
fprintf('\n========================================\n');
fprintf('📊 EKF SOC ESTIMATION SUMMARY\n');
fprintf('========================================\n');
fprintf('   Initial SOC error: %.1f%%\n', (SOC0 - SOC_true(1))*100);
fprintf('   Final SOC error: %.2f%%\n', final_error);
fprintf('   RMSE: %.2f%%\n', rmse);
fprintf('   Max error: %.2f%%\n', max_error);
fprintf('   Innovation std: %.2f mV\n', std(innovations)*1000);
fprintf('========================================\n');

if rmse < 2
    fprintf('✅ EXCELLENT! RMSE < 2%%\n');
elseif rmse < 5
    fprintf('✅ GOOD! RMSE < 5%%\n');
else
    fprintf('⚠️  ACCEPTABLE! RMSE < 10%%\n');
end
fprintf('========================================\n');