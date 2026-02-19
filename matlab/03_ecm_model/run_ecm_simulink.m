%% RUN 1-RC ECM SIMULINK MODEL
clear; clc; close all;

%% ========== SETUP ==========
cd('C:\Users\Krupal Babariya\Desktop\battery-bms-ecm-soc-soh\');
addpath(genpath('matlab'));

%% ========== LOAD REAL DISCHARGE DATA ==========
load('data/processed/cell01_cycles.mat', 'cycles');

% Find first discharge cycle
for i = 1:length(cycles)
    if strcmp(cycles(i).type, 'discharge')
        discharge = cycles(i);
        break;
    end
end

% Create input current signal for Simulink
t = discharge.time;
I = discharge.I;  % Negative for discharge

% Create time-series object for Simulink
I_sim = [t, I];  % Simulink From Workspace expects [time, data]

%% ========== SET ECM PARAMETERS (FROM YOUR FITTING) ==========
% These should come from your parameter identification
R0 = 0.0234;     % Ohms
R1 = 0.0089;     % Ohms
C1 = 2345;       % Farads
Q_nom = 1.86;    % Ah (initial capacity)

% OCV-SOC lookup table (from your fitting or typical values)
SOC_points = (0:0.05:1)';
OCV_SOC = 3.2 + 1.0 * SOC_points.^0.5;  % Replace with your actual OCV curve

%% ========== RUN SIMULINK ==========
fprintf('🚀 Running Simulink 1-RC ECM model...\n');
sim('simulink/ecm_1rc.slx');

%% ========== PLOT RESULTS ==========
figure('Name', 'Simulink 1-RC ECM Results', 'Position', [100, 100, 1400, 800]);

% Plot 1: Voltage comparison
subplot(2,2,1);
plot(t, discharge.V, 'b-', 'LineWidth', 2, 'DisplayName', 'Measured');
hold on;
plot(V_time, V_sim, 'r--', 'LineWidth', 1.5, 'DisplayName', '1-RC Model');
xlabel('Time (s)');
ylabel('Voltage (V)');
title('Terminal Voltage');
legend('Location', 'best');
grid on;

% Plot 2: Voltage error
subplot(2,2,2);
V_error = discharge.V - V_sim;
plot(V_time, V_error * 1000, 'k-', 'LineWidth', 1);
xlabel('Time (s)');
ylabel('Error (mV)');
title(sprintf('Model Error (RMSE = %.1f mV)', rms(V_error)*1000));
grid on;
yline(0, 'r--');

% Plot 3: SOC
subplot(2,2,3);
plot(SOC_time, SOC_sim, 'g-', 'LineWidth', 2);
xlabel('Time (s)');
ylabel('SOC');
title('State of Charge');
ylim([0, 1]);
grid on;

% Plot 4: Polarization voltage
subplot(2,2,4);
plot(V1_time, V1_sim, 'm-', 'LineWidth', 2);
xlabel('Time (s)');
ylabel('V1 (V)');
title('Polarization Voltage');
grid on;

sgtitle('1-RC ECM Simulink Model Validation', 'FontSize', 14, 'FontWeight', 'bold');

%% ========== SAVE RESULTS ==========
save('data/processed/ecm_simulink_results.mat', 'V_sim', 'SOC_sim', 'V1_sim', 'V_time');
fprintf('✅ Simulink simulation complete!\n');
fprintf('   Voltage RMSE: %.1f mV\n', rms(V_error)*1000);