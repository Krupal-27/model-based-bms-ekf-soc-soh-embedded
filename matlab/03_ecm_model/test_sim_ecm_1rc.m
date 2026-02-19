%% TEST 1-RC ECM SIMULATOR
clear; clc; close all;

cd('C:\Users\Krupal Babariya\Desktop\battery-bms-ecm-soc-soh\');
addpath(genpath('matlab'));

fprintf('========================================\n');
fprintf('🔧 TEST 1-RC ECM SIMULATOR\n');
fprintf('========================================\n\n');

%% ========== LOAD VALIDATION DATA ==========
fprintf('📂 Loading validation data...\n');

% Load a real discharge cycle
load('data/processed/cell01_cycles.mat', 'cycles');
for i = 1:length(cycles)
    if strcmp(cycles(i).type, 'discharge')
        d = cycles(i);
        fprintf('✅ Found discharge cycle #%d\n', i);
        break;
    end
end

% Trim to discharge only
current_threshold = 0.1;
start_idx = find(abs(d.I) > current_threshold, 1, 'first');
end_idx = find(abs(d.I) > current_threshold, 1, 'last');

I_test = d.I(start_idx:end_idx);
t_test = d.time(start_idx:end_idx) - d.time(start_idx);
V_measured = d.V(start_idx:end_idx);

fprintf('   Test data: %d points, %.1f s\n', length(t_test), t_test(end));
fprintf('   Current: %.3f A\n\n', mean(abs(I_test)));

%% ========== LOAD FINAL PARAMETERS ==========
fprintf('📂 Loading final 1-RC parameters...\n');

if exist('data/processed/B0005_1RC_FINAL.mat', 'file')
    load('data/processed/B0005_1RC_FINAL.mat', 'final_params');
    
    % Create params structure for simulator
    params.R0 = final_params.R0;
    params.R1 = final_params.R1;
    params.C1 = final_params.C1;
    params.Q_nom = final_params.Q_nom;
    params.OCV_SOC = [final_params.OCV_SOC, final_params.OCV];
    
    fprintf('✅ Parameters loaded:\n');
    fprintf('   R0 = %.4f Ω\n', params.R0);
    fprintf('   R1 = %.4f Ω\n', params.R1);
    fprintf('   C1 = %d F\n', params.C1);
    fprintf('   Q_nom = %.3f Ah\n\n', params.Q_nom);
else
    error('❌ Final parameters not found. Run save command first.');
end

%% ========== RUN SIMULATOR ==========
fprintf('🚀 Running 1-RC simulator...\n');
[V_sim, SOC, V1, debug] = sim_ecm_1rc(I_test, t_test, params, 1.0);

%% ========== CALCULATE ERROR ==========
error = (V_measured - V_sim) * 1000;  % mV
rmse = rms(error);
mae = mean(abs(error));
max_error = max(abs(error));

fprintf('\n📊 Simulation Results:\n');
fprintf('   RMSE = %.1f mV\n', rmse);
fprintf('   MAE = %.1f mV\n', mae);
fprintf('   Max error = %.1f mV\n', max_error);

%% ========== PLOT RESULTS ==========
figure('Position', [100, 100, 1600, 900]);

% Plot 1: Voltage comparison
subplot(2,3,1);
plot(t_test, V_measured, 'b-', 'LineWidth', 2); hold on;
plot(t_test, V_sim, 'r--', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('Voltage (V)');
title(sprintf('Voltage Comparison (RMSE = %.1f mV)', rmse));
legend('Measured', 'Simulated', 'Location', 'best');
grid on;

% Plot 2: Error
subplot(2,3,2);
plot(t_test, error, 'k-', 'LineWidth', 1);
xlabel('Time (s)'); ylabel('Error (mV)');
title('Model Error');
grid on; yline(0, 'r--');
yline([-50, 50], 'g--', '±50mV');

% Plot 3: SOC
subplot(2,3,3);
plot(t_test, SOC, 'g-', 'LineWidth', 2);
xlabel('Time (s)'); ylabel('SOC');
title('State of Charge');
grid on; ylim([0,1]);

% Plot 4: Polarization voltage
subplot(2,3,4);
plot(t_test, V1*1000, 'm-', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('V1 (mV)');
title('Polarization Voltage');
grid on;

% Plot 5: Current profile
subplot(2,3,5);
plot(t_test, I_test, 'c-', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('Current (A)');
title('Current Profile');
grid on;

% Plot 6: OCV used
subplot(2,3,6);
plot(params.OCV_SOC(:,1), params.OCV_SOC(:,2), 'b-', 'LineWidth', 2);
xlabel('SOC'); ylabel('OCV (V)');
title('OCV-SOC Curve');
grid on; xlim([0,1]); ylim([2.5,4.5]);

sgtitle('1-RC ECM Simulator Validation', 'FontSize', 14, 'FontWeight', 'bold');

%% ========== COMPARE WITH COULOMB COUNTING ==========
fprintf('\n📊 SOC Comparison:\n');
fprintf('   Initial SOC: %.3f\n', SOC(1));
fprintf('   Final SOC: %.3f\n', SOC(end));
fprintf('   SOC change: %.3f (%.1f%%)\n', SOC(1)-SOC(end), (SOC(1)-SOC(end))*100);

% Theoretical SOC from capacity
Q_removed = sum(abs(I_test) * mean(diff(t_test))) / 3600;
SOC_theoretical = 1 - Q_removed / params.Q_nom;
fprintf('   Theoretical final SOC: %.3f\n', SOC_theoretical);
fprintf('   Difference: %.3f\n\n', abs(SOC(end) - SOC_theoretical));

%% ========== SAVE SIMULATOR RESULTS ==========
results.V_sim = V_sim;
results.SOC = SOC;
results.V1 = V1;
results.error_mV = error;
results.rmse_mV = rmse;
results.params = params;

save('data/processed/B0005_simulator_results.mat', 'results');
fprintf('💾 Saved: data/processed/B0005_simulator_results.mat\n');

%% ========== SUMMARY ==========
fprintf('\n========================================\n');
fprintf('📊 FINAL SUMMARY\n');
fprintf('========================================\n');
fprintf('   1-RC Simulator Performance:\n');
fprintf('   RMSE = %.1f mV\n', rmse);
fprintf('   MAE = %.1f mV\n', mae);
fprintf('   Max error = %.1f mV\n', max_error);
fprintf('========================================\n');

if rmse < 100
    fprintf('✅ EXCELLENT! RMSE < 100 mV\n');
elseif rmse < 200
    fprintf('⚠️  GOOD! RMSE < 200 mV\n');
else
    fprintf('❌ NEEDS IMPROVEMENT! RMSE > 200 mV\n');
end
fprintf('========================================\n');