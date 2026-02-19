%% EXAMPLE: USING THE 1-RC ECM SIMULATOR
clear; clc; close all;

cd('C:\Users\Krupal Babariya\Desktop\battery-bms-ecm-soc-soh\');
addpath(genpath('matlab'));

%% ========== LOAD PARAMETERS ==========
load('data/processed/B0005_1RC_FINAL.mat', 'final_params');

% Create params structure
params.R0 = final_params.R0;
params.R1 = final_params.R1;
params.C1 = final_params.C1;
params.Q_nom = final_params.Q_nom;
params.OCV_SOC = [final_params.OCV_SOC, final_params.OCV];

%% ========== CREATE A TEST CURRENT PROFILE ==========
% Simple constant current discharge
t = (0:1:3000)';  % 3000 seconds at 1s sampling
I = -2.0 * ones(size(t));  % Constant 2A discharge

fprintf('🔧 Testing with constant 2A discharge...\n');

%% ========== RUN SIMULATOR ==========
[V_sim, SOC, V1] = sim_ecm_1rc(I, t, params, 1.0);

%% ========== PLOT RESULTS ==========
figure('Position', [100, 100, 1200, 800]);

subplot(2,2,1);
plot(t/60, V_sim, 'b-', 'LineWidth', 1.5);
xlabel('Time (minutes)'); ylabel('Voltage (V)');
title('Terminal Voltage');
grid on;

subplot(2,2,2);
plot(t/60, SOC, 'r-', 'LineWidth', 1.5);
xlabel('Time (minutes)'); ylabel('SOC');
title('State of Charge');
grid on; ylim([0,1]);

subplot(2,2,3);
plot(t/60, V1*1000, 'm-', 'LineWidth', 1.5);
xlabel('Time (minutes)'); ylabel('V1 (mV)');
title('Polarization Voltage');
grid on;

subplot(2,2,4);
plot(SOC, V_sim, 'g-', 'LineWidth', 1.5);
xlabel('SOC'); ylabel('Voltage (V)');
title('Voltage vs SOC');
grid on; xlim([0,1]);

sgtitle('1-RC ECM - Constant Current Discharge', 'FontSize', 14, 'FontWeight', 'bold');

fprintf('✅ Simulation complete!\n');
fprintf('   Final voltage: %.3f V\n', V_sim(end));
fprintf('   Final SOC: %.3f\n', SOC(end));