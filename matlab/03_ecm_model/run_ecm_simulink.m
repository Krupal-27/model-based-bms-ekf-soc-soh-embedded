%% RUN 1-RC ECM SIMULINK MODEL
clear; clc; close all;

%% SETUP
cd('C:\Users\Krupal Babariya\Desktop\battery-bms-ecm-soc-soh\');
addpath(genpath('matlab'));

%% LOAD REAL DISCHARGE DATA
load('data/processed/cell01_cycles.mat', 'cycles');

for i = 1:length(cycles)
    if strcmp(cycles(i).type, 'discharge')
        discharge = cycles(i);
        break;
    end
end

t = discharge.time;
I = discharge.I;

I_sim = [t, I];

%% SET ECM PARAMETERS (FROM YOUR FITTING)
R0 = 0.0234;
R1 = 0.0089;
C1 = 2345;
Q_nom = 1.86;

SOC_points = (0:0.05:1)';
OCV_SOC = 3.2 + 1.0 * SOC_points.^0.5;

%% RUN SIMULINK
fprintf('Running Simulink 1-RC ECM model...\n');
sim('simulink/ecm_1rc.slx');

%% PLOT RESULTS
figure('Name', 'Simulink 1-RC ECM Results', 'Position', [100, 100, 1400, 800]);

subplot(2,2,1);
plot(t, discharge.V, 'b-', 'LineWidth', 2, 'DisplayName', 'Measured');
hold on;
plot(V_time, V_sim, 'r--', 'LineWidth', 1.5, 'DisplayName', '1-RC Model');
xlabel('Time (s)');
ylabel('Voltage (V)');
title('Terminal Voltage');
legend('Location', 'best');
grid on;

subplot(2,2,2);
V_error = discharge.V - V_sim;
plot(V_time, V_error * 1000, 'k-', 'LineWidth', 1);
xlabel('Time (s)');
ylabel('Error (mV)');
title(sprintf('Model Error (RMSE = %.1f mV)', rms(V_error)*1000));
grid on;
yline(0, 'r--');

subplot(2,2,3);
plot(SOC_time, SOC_sim, 'g-', 'LineWidth', 2);
xlabel('Time (s)');
ylabel('SOC');
title('State of Charge');
ylim([0, 1]);
grid on;

subplot(2,2,4);
plot(V1_time, V1_sim, 'm-', 'LineWidth', 2);
xlabel('Time (s)');
ylabel('V1 (V)');
title('Polarization Voltage');
grid on;

sgtitle('1-RC ECM Simulink Model Validation', 'FontSize', 14, 'FontWeight', 'bold');

%% SAVE RESULTS
save('data/processed/ecm_simulink_results.mat', 'V_sim', 'SOC_sim', 'V1_sim', 'V_time');
fprintf('Simulink simulation complete!\n');
fprintf('   Voltage RMSE: %.1f mV\n', rms(V_error)*1000);
