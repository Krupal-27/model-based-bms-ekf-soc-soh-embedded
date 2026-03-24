%% VALIDATE_SIMULINK_ECM.m – CLEAN FINAL VERSION
% 1-RC ECM Validation: MATLAB vs Simulink vs Measured Data
clear; clc; close all;

% =========================================================================
% 1. SETUP AND DATA LOADING
% =========================================================================
cd('C:\Users\Krupal Babariya\Desktop\battery-bms-ecm-soc-soh\');
addpath(genpath('matlab'));

fprintf('========================================\n');
fprintf('Simulink ECM – FINAL VALIDATION\n');
fprintf('========================================\n\n');

load('data/processed/cell01_cycles.mat', 'cycles');
load('data/processed/B0005_OCV_manual.mat', 'ocv_data');

d = cycles(4);
thr = 0.1;
iStart = find(abs(d.I) > thr, 1, 'first');
iEnd   = find(abs(d.I) > thr, 1, 'last');

t       = d.time(iStart:iEnd) - d.time(iStart);
I       = d.I(iStart:iEnd);
V_meas  = d.V(iStart:iEnd);
Q       = d.Q;

fprintf('Loaded cycle #4\n');
fprintf('   Points : %d\n', length(t));
fprintf('   Time   : %.1f s\n', t(end));
fprintf('   Current: %.3f A (mean |I|)\n', mean(abs(I)));
fprintf('   Capacity: %.3f Ah\n\n', Q);

if mean(abs(I)) < 1.0
    fprintf('Current too low! Scaling from %.3fA to 2.0A\n', mean(abs(I)));
    scale_factor = 2.0 / mean(abs(I));
    I = I * scale_factor;
    fprintf('   New mean |I|: %.3f A\n', mean(abs(I)));
end

I_sim = timeseries(I, t);

% =========================================================================
% 2. ECM PARAMETERS (OPTIMIZED VALUES)
% =========================================================================
params.R0   = 0.2112;
params.R1   = 2.0;
params.C1   = 40000;
params.Q_nom = Q;

dt = mean(diff(t));
tau = params.R1 * params.C1;
alpha = exp(-dt / tau);
beta  = params.R1 * (1 - alpha);

fprintf('ECM Parameters\n');
fprintf('   R0 = %.4f Ohm\n', params.R0);
fprintf('   R1 = %.4f Ohm\n', params.R1);
fprintf('   C1 = %.0f F\n', params.C1);
fprintf('   tau  = %.1f s\n', tau);
fprintf('   dt = %.3f s\n\n', dt);

% =========================================================================
% 3. MATLAB SIMULATION (GROUND TRUTH)
% =========================================================================
fprintf('Running MATLAB ECM ...\n');
N = length(t);
V_matlab = zeros(N,1);
SOC      = zeros(N,1);
V1       = zeros(N,1);

SOC(1) = 1.0;
V1(1)  = 0.0;

for k = 1:N-1
    OCV = interp1(ocv_data.SOC, ocv_data.OCV, SOC(k), 'linear', 'extrap');
    
    V_matlab(k) = OCV - abs(I(k))*params.R0 - V1(k);
    
    SOC(k+1) = SOC(k) + I(k) * dt / (params.Q_nom * 3600);
    SOC(k+1) = max(min(SOC(k+1),1),0);
    
    V1(k+1) = alpha * V1(k) + beta * I(k);
end

OCV_end = interp1(ocv_data.SOC, ocv_data.OCV, SOC(end), 'linear', 'extrap');
V_matlab(end) = OCV_end - abs(I(end))*params.R0 - V1(end);

fprintf('MATLAB simulation complete\n\n');

% =========================================================================
% 4. SIMULINK SIMULATION
% =========================================================================
fprintf('Running Simulink model ...\n');

I_negative = -abs(I);
I_sim = timeseries(I_negative, t);

R0 = params.R0; R1 = params.R1; C1 = params.C1;
Q_nom = params.Q_nom; dt_sim = dt;
alpha_sim = alpha; beta_sim = beta;
SOC_brkpts = ocv_data.SOC; OCV_table = ocv_data.OCV;
SOC_init = 1.0; V1_init = 0.0;

vars = {'I_sim','R0','R1','C1','Q_nom','dt_sim','alpha_sim','beta_sim',...
        'SOC_brkpts','OCV_table','SOC_init','V1_init'};
for i = 1:length(vars)
    assignin('base', vars{i}, eval(vars{i}));
end

out = sim('ecm_1rc');

required = {'V_sim','tout','SOC_sim','V1_sim','IR0_sim'};
names = out.who;
for i = 1:length(required)
    if ~any(strcmp(names, required{i}))
        error("'%s' missing. Check To Workspace blocks.", required{i});
    end
end

V_simulink = out.V_sim;
t_simulink = out.tout;
SOC_sim = out.SOC_sim;
V1_sim = out.V1_sim;
IR0_sim = out.IR0_sim;

fprintf('Simulink finished\n');
fprintf('   Simulink points: %d\n\n', length(V_simulink));

% =========================================================================
% 5. DATA ALIGNMENT AND ERROR CALCULATION
% =========================================================================
V_sim_interp = interp1(t_simulink, V_simulink, t, 'linear', 'extrap');
V1_sim_interp = interp1(t_simulink, V1_sim, t, 'linear', 'extrap');
SOC_sim_interp = interp1(t_simulink, SOC_sim, t, 'linear', 'extrap');
IR0_sim_interp = interp1(t_simulink, IR0_sim, t, 'linear', 'extrap');

e_matlab = (V_meas - V_matlab) * 1000;
e_sim    = (V_meas - V_sim_interp) * 1000;
e_sim_vs_mat = (V_matlab - V_sim_interp) * 1000;

RMSE_matlab = rms(e_matlab);
RMSE_sim    = rms(e_sim);
RMSE_sim_vs_mat = rms(e_sim_vs_mat);

fprintf('RMSE Comparison\n');
fprintf('   MATLAB vs Measured : %.2f mV\n', RMSE_matlab);
fprintf('   Simulink vs Measured: %.2f mV\n', RMSE_sim);
fprintf('   Simulink vs MATLAB  : %.2f mV\n\n', RMSE_sim_vs_mat);

% =========================================================================
% 6. DETAILED COMPARISONS
% =========================================================================
fprintf('DETAILED COMPARISON:\n');
mid = floor(length(t)/2);

fprintf('   At middle (step %d):\n', mid);
fprintf('      Measured : %.4f V\n', V_meas(mid));
fprintf('      MATLAB   : %.4f V\n', V_matlab(mid));
fprintf('      Simulink : %.4f V\n', V_sim_interp(mid));
fprintf('      Error (Simulink vs MATLAB): %.2f mV\n', ...
    (V_matlab(mid) - V_sim_interp(mid))*1000);

fprintf('   At end (step %d):\n', length(t));
fprintf('      Measured : %.4f V\n', V_meas(end));
fprintf('      MATLAB   : %.4f V\n', V_matlab(end));
fprintf('      Simulink : %.4f V\n', V_sim_interp(end));
fprintf('      Error (Simulink vs MATLAB): %.2f mV\n\n', ...
    (V_matlab(end) - V_sim_interp(end))*1000);

fprintf('SOC Comparison:\n');
fprintf('   MATLAB final SOC: %.4f\n', SOC(end));
fprintf('   Simulink final SOC: %.4f\n', SOC_sim_interp(end));
fprintf('   SOC change: %.4f\n\n', SOC(1) - SOC(end));

fprintf('V1 Comparison:\n');
V1_error = (V1 - V1_sim_interp) * 1000;
V1_rmse = rms(V1_error);
fprintf('   V1 RMSE: %.2f mV\n', V1_rmse);
fprintf('   At middle: MATLAB=%.6f V, Simulink=%.6f V, Diff=%.2f mV\n', ...
    V1(mid), V1_sim_interp(mid), V1_error(mid));
fprintf('   At end   : MATLAB=%.6f V, Simulink=%.6f V, Diff=%.2f mV\n\n', ...
    V1(end), V1_sim_interp(end), V1_error(end));

IR0_expected = abs(I(mid)) * params.R0;
fprintf('IR0 Comparison at middle:\n');
fprintf('   Expected IR0: %.6f V\n', IR0_expected);
fprintf('   Simulink IR0: %.6f V\n', IR0_sim_interp(mid));
fprintf('   Difference  : %.2f mV\n\n', (IR0_expected - IR0_sim_interp(mid))*1000);

% =========================================================================
% 7. PLOTTING
% =========================================================================
figure('Position', [100 100 1400 900]);

subplot(2,3,1);
plot(t, V_meas, 'b-', 'LineWidth', 2); hold on;
plot(t, V_matlab, 'r--', 'LineWidth', 1.5);
plot(t, V_sim_interp, 'g-.', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('Voltage (V)');
title('Terminal Voltage'); legend('Measured','MATLAB','Simulink'); grid on;

subplot(2,3,2);
plot(t, e_matlab, 'r-', 'LineWidth', 1);
xlabel('Time (s)'); ylabel('Error (mV)');
title(sprintf('MATLAB Error (RMSE = %.2f mV)', RMSE_matlab));
grid on; yline(0,'k--');

subplot(2,3,3);
plot(t, e_sim, 'g-', 'LineWidth', 1);
xlabel('Time (s)'); ylabel('Error (mV)');
title(sprintf('Simulink Error (RMSE = %.2f mV)', RMSE_sim));
grid on; yline(0,'k--');

subplot(2,3,4);
plot(t, e_sim_vs_mat, 'b-', 'LineWidth', 1);
xlabel('Time (s)'); ylabel('Error (mV)');
title(sprintf('Simulink vs MATLAB (RMSE = %.2f mV)', RMSE_sim_vs_mat));
grid on; yline(0,'k--');

subplot(2,3,5);
plot(t, I, 'k-', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('Current (A)');
title('Discharge Current'); grid on;

subplot(2,3,6);
histogram(e_sim_vs_mat, 50, 'FaceColor', [0.2 0.6 0.8]);
xlabel('Error (mV)'); ylabel('Frequency');
title('Error Distribution'); grid on;

sgtitle('Simulink 1-RC ECM – Validation Results', 'FontSize', 14, 'FontWeight','bold');

figure('Name', 'V1 Comparison', 'Position', [100 100 800 600]);

subplot(2,1,1);
plot(t, V1, 'b-', 'LineWidth', 1.5); hold on;
plot(t, V1_sim_interp, 'r--', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('V1 (V)');
title(sprintf('V1: MATLAB vs Simulink (RMSE = %.2f mV)', V1_rmse));
legend('MATLAB', 'Simulink', 'Location', 'best');
grid on;

subplot(2,1,2);
plot(t, V1_error, 'k-', 'LineWidth', 1);
xlabel('Time (s)'); ylabel('V1 Error (mV)');
title('V1 Error');
grid on; yline(0, 'r--');

% =========================================================================
% 8. SAVE RESULTS
% =========================================================================
results.t = t;
results.V_meas = V_meas;
results.V_matlab = V_matlab;
results.V_simulink = V_sim_interp;
results.SOC = SOC;
results.SOC_sim = SOC_sim_interp;
results.V1 = V1;
results.V1_sim = V1_sim_interp;
results.e_matlab = e_matlab;
results.e_sim = e_sim;
results.e_sim_vs_mat = e_sim_vs_mat;
results.RMSE_matlab = RMSE_matlab;
results.RMSE_sim = RMSE_sim;
results.RMSE_sim_vs_mat = RMSE_sim_vs_mat;
results.params = params;

save('data/processed/simulink_final_validation.mat', '-struct', 'results');
fprintf('\nResults saved to data/processed/simulink_final_validation.mat\n');

% =========================================================================
% 9. FINAL SUMMARY
% =========================================================================
fprintf('\n========================================\n');
fprintf('VALIDATION SUMMARY\n');
fprintf('========================================\n');
fprintf('   MATLAB vs Measured : %.2f mV\n', RMSE_matlab);
fprintf('   Simulink vs Measured: %.2f mV\n', RMSE_sim);
fprintf('   Simulink vs MATLAB  : %.2f mV\n', RMSE_sim_vs_mat);
fprintf('   V1 RMSE             : %.2f mV\n', V1_rmse);
fprintf('========================================\n');

if RMSE_sim_vs_mat < 1
    fprintf('EXCELLENT – Simulink matches MATLAB perfectly!\n');
elseif RMSE_sim_vs_mat < 5
    fprintf('GOOD – Simulink matches MATLAB well.\n');
else
    fprintf('Simulink differs from MATLAB – check your model.\n');
end
fprintf('========================================\n');

fprintf('\nMATLAB OCV at key points:\n');
SOC_check = [1.0, 0.75, 0.5, 0.25, 0];
for i = 1:length(SOC_check)
    OCV_val = interp1(SOC_brkpts, OCV_table, SOC_check(i), 'linear', 'extrap');
    fprintf('   SOC=%.2f to OCV=%.4f V\n', SOC_check(i), OCV_val);
end

fprintf('\nDEBUG - Voltage Breakdown at Middle:\n');
k = 1674;
fprintf('   I = %.4f A\n', I(k));
fprintf('   IR0 = %.4f V\n', abs(I(k))*params.R0);
fprintf('   V1 = %.4f V\n', V1(k));
fprintf('   V_matlab = %.4f V\n', V_matlab(k));
fprintf('   Implied OCV = V_matlab + IR0 + V1 = %.4f V\n', ...
    V_matlab(k) + abs(I(k))*params.R0 + V1(k));
fprintf('   OCV from table = %.4f V\n', ...
    interp1(ocv_data.SOC, ocv_data.OCV, SOC(k), 'linear', 'extrap'));
fprintf('   Difference = %.4f V (%.1f mV)\n', ...
    (V_matlab(k) + abs(I(k))*params.R0 + V1(k)) - ...
    interp1(ocv_data.SOC, ocv_data.OCV, SOC(k), 'linear', 'extrap'), ...
    ((V_matlab(k) + abs(I(k))*params.R0 + V1(k)) - ...
    interp1(ocv_data.SOC, ocv_data.OCV, SOC(k), 'linear', 'extrap'))*1000);
