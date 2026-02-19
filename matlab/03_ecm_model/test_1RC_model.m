%% TEST 1-RC MODEL WITH FINAL PARAMETERS - FIXED PATH VERSION
clear; clc; close all;

%% ========== SETUP PATHS PROPERLY ==========
% Get the current script location
script_dir = fileparts(mfilename('fullpath'));
fprintf('📁 Script directory: %s\n', script_dir);

% Go up to project root (from matlab/03_ecm_model to project root)
project_root = fileparts(fileparts(script_dir));
fprintf('📁 Project root: %s\n', project_root);

% Change to project root
cd(project_root);
fprintf('📁 Changed to: %s\n', pwd);

% Add all matlab folders to path
addpath(genpath(fullfile(project_root, 'matlab')));

fprintf('========================================\n');
fprintf('🔧 TEST 1-RC MODEL\n');
fprintf('========================================\n\n');

%% ========== LOAD DATA ==========
fprintf('📂 Loading data...\n');

% Define file path explicitly
data_file = fullfile(project_root, 'data', 'processed', 'cell01_cycles.mat');
fprintf('   Looking for: %s\n', data_file);

% Check if file exists
if ~exist(data_file, 'file')
    error('❌ File not found at: %s\nPlease run segmentation script first.', data_file);
end

% Load the data
load(data_file, 'cycles');
fprintf('✅ File loaded successfully\n');

% Find first discharge cycle
discharge_idx = [];
for i = 1:length(cycles)
    if strcmp(cycles(i).type, 'discharge')
        d = cycles(i);
        discharge_idx = i;
        fprintf('✅ Found discharge cycle #%d\n', i);
        break;
    end
end

if isempty(discharge_idx)
    error('❌ No discharge cycle found in the data');
end

%% ========== LOAD OR CREATE OCV CURVE ==========
ocv_file = fullfile(project_root, 'data', 'processed', 'B0005_OCV_manual.mat');

if exist(ocv_file, 'file')
    % Load existing OCV curve
    load(ocv_file, 'ocv_data');
    fprintf('✅ Loaded manual OCV curve from %s\n', ocv_file);
else
    % Create and save OCV curve if not exists
    fprintf('📝 Creating new OCV curve...\n');
    
    % Create manual OCV lookup table
    SOC_lookup = (0:0.05:1)';
    OCV_lookup = [3.00; 3.20; 3.30; 3.40; 3.50; 3.60; 3.70; 3.80; 
                  3.90; 4.00; 4.10; 4.15; 4.18; 4.19; 4.20; 4.20; 
                  4.20; 4.20; 4.20; 4.20; 4.20];
    
    % Store in structure
    ocv_data = struct();
    ocv_data.SOC = SOC_lookup;
    ocv_data.OCV = OCV_lookup;
    ocv_data.battery_id = 'B0005';
    ocv_data.date_created = datestr(now);
    ocv_data.description = 'Manual OCV curve for Li-ion battery';
    
    % Save for future use
    save(ocv_file, 'ocv_data');
    fprintf('✅ Created and saved OCV curve to %s\n', ocv_file);
end

% Display OCV info
fprintf('   OCV points: %d\n', length(ocv_data.SOC));
fprintf('   OCV range: %.2fV to %.2fV\n', min(ocv_data.OCV), max(ocv_data.OCV));

%% ========== TRIM DISCHARGE DATA ==========
fprintf('\n📊 Trimming discharge data...\n');

current_threshold = 0.1;
start_idx = find(abs(d.I) > current_threshold, 1, 'first');
end_idx = find(abs(d.I) > current_threshold, 1, 'last');

d_trimmed = struct();
d_trimmed.time = d.time(start_idx:end_idx) - d.time(start_idx);
d_trimmed.V = d.V(start_idx:end_idx);
d_trimmed.I = d.I(start_idx:end_idx);
d_trimmed.Q = d.Q;

dt = mean(diff(d_trimmed.time));
fprintf('   Points: %d\n', length(d_trimmed.time));
fprintf('   Duration: %.1f s\n', d_trimmed.time(end));
fprintf('   Current: %.3f A\n', mean(abs(d_trimmed.I)));
fprintf('   Capacity: %.3f Ah\n\n', d_trimmed.Q);

%% ========== CALCULATE SOC ==========
Q = d_trimmed.Q;
dQ = abs(d_trimmed.I) * dt;
Q_removed = cumsum(dQ);
SOC = 1 - Q_removed / (Q * 3600);
SOC = max(min(SOC, 1), 0);

%% ========== FINAL 1-RC PARAMETERS ==========
fprintf('🔧 Using optimized 1-RC parameters:\n');

R0 = 0.1767;      % Series resistance (Ω)
R1 = 0.0990;      % Polarization resistance (Ω)
C1 = 50000;       % Polarization capacitance (F)
tau = R1 * C1;    % Time constant (s)

fprintf('   R0 = %.4f Ω\n', R0);
fprintf('   R1 = %.4f Ω\n', R1);
fprintf('   C1 = %d F\n', C1);
fprintf('   τ = %.1f s\n\n', tau);

%% ========== SIMULATE 1-RC MODEL ==========
fprintf('🔧 Simulating 1-RC model...\n');

alpha = exp(-dt / tau);
V1 = 0;
V_sim = zeros(size(d_trimmed.time));
V1_hist = zeros(size(d_trimmed.time));

for k = 1:length(d_trimmed.time)
    % Get OCV from lookup table
    OCV_val = interp1(ocv_data.SOC, ocv_data.OCV, SOC(k), 'linear', 'extrap');
    
    % Terminal voltage: V = OCV - I*R0 - V1
    V_sim(k) = OCV_val - abs(d_trimmed.I(k)) * R0 - V1;
    V1_hist(k) = V1;
    
    % Update RC state
    V1 = alpha * V1 + R1 * (1 - alpha) * d_trimmed.I(k);
end

%% ========== CALCULATE ERROR ==========
error = (d_trimmed.V - V_sim) * 1000;  % mV
rmse = rms(error);
mae = mean(abs(error));
max_error = max(abs(error));

fprintf('\n✅ Simulation complete:\n');
fprintf('   RMSE = %.1f mV\n', rmse);
fprintf('   MAE = %.1f mV\n', mae);
fprintf('   Max error = %.1f mV\n', max_error);

%% ========== PLOT RESULTS ==========
figure('Position', [100, 100, 1400, 900]);

% Plot 1: Voltage comparison
subplot(2,3,1);
plot(d_trimmed.time, d_trimmed.V, 'b-', 'LineWidth', 2); hold on;
plot(d_trimmed.time, V_sim, 'r--', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('Voltage (V)');
title(sprintf('1-RC Model (RMSE = %.1f mV)', rmse));
legend('Measured', '1-RC Model', 'Location', 'best');
grid on;

% Plot 2: Error
subplot(2,3,2);
plot(d_trimmed.time, error, 'k-', 'LineWidth', 1);
xlabel('Time (s)'); ylabel('Error (mV)');
title('Model Error');
grid on; yline(0, 'r--');
yline([-50, 50], 'g--', '±50mV');

% Plot 3: Polarization voltage
subplot(2,3,3);
plot(d_trimmed.time, V1_hist*1000, 'm-', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('V1 (mV)');
title('Polarization Voltage');
grid on;

% Plot 4: Voltage vs SOC
subplot(2,3,4);
plot(SOC, d_trimmed.V, 'b.', 'MarkerSize', 2); hold on;
plot(SOC, V_sim, 'r.', 'MarkerSize', 2);
xlabel('SOC'); ylabel('Voltage (V)');
title('Voltage vs SOC');
legend('Measured', '1-RC', 'Location', 'best');
grid on; xlim([0,1]);

% Plot 5: OCV curve
subplot(2,3,5);
plot(ocv_data.SOC, ocv_data.OCV, 'g-', 'LineWidth', 2);
xlabel('SOC'); ylabel('OCV (V)');
title('OCV-SOC Curve');
grid on; xlim([0,1]); ylim([2.5,4.5]);

% Plot 6: Parameters
subplot(2,3,6);
axis off;
text(0.1, 0.9, '1-RC PARAMETERS', 'FontSize', 12, 'FontWeight', 'bold');
text(0.1, 0.75, sprintf('R0 = %.4f Ω', R0), 'FontSize', 11);
text(0.1, 0.6, sprintf('R1 = %.4f Ω', R1), 'FontSize', 11);
text(0.1, 0.45, sprintf('C1 = %d F', C1), 'FontSize', 11);
text(0.1, 0.3, sprintf('τ = %.1f s', tau), 'FontSize', 11);
text(0.1, 0.15, sprintf('RMSE = %.1f mV', rmse), 'FontSize', 11);

sgtitle('Final 1-RC ECM Validation', 'FontSize', 14, 'FontWeight', 'bold');

%% ========== SAVE RESULTS ==========
results = struct();
results.R0 = R0;
results.R1 = R1;
results.C1 = C1;
results.tau = tau;
results.rmse_mV = rmse;
results.mae_mV = mae;
results.max_error_mV = max_error;
results.ocv_file = ocv_file;
results.date = datestr(now);
results.data_file = data_file;

results_file = fullfile(project_root, 'data', 'processed', 'B0005_1RC_results.mat');
save(results_file, 'results');
fprintf('\n💾 Saved: %s\n', results_file);

%% ========== SAVE UPDATED OCV CURVE WITH METADATA ==========
% Add usage metadata to OCV file
ocv_data.last_used = datestr(now);
ocv_data.used_in_test = '1-RC Model Validation';
save(ocv_file, 'ocv_data');
fprintf('✅ Updated OCV file with usage metadata\n');

%% ========== SUMMARY ==========
fprintf('\n========================================\n');
fprintf('📊 FINAL SUMMARY\n');
fprintf('========================================\n');
fprintf('   1-RC Model Performance:\n');
fprintf('   RMSE = %.1f mV\n', rmse);
fprintf('   MAE = %.1f mV\n', mae);
fprintf('   Max error = %.1f mV\n', max_error);
fprintf('========================================\n');

if rmse < 100
    fprintf('✅ EXCELLENT! RMSE < 100 mV\n');
elseif rmse < 200
    fprintf('⚠️  ACCEPTABLE! RMSE < 200 mV\n');
else
    fprintf('❌ NEEDS IMPROVEMENT! RMSE > 200 mV\n');
end
fprintf('========================================\n');

%% ========== VERIFICATION ==========
fprintf('\n🔍 Verification:\n');
fprintf('   Current directory: %s\n', pwd);
fprintf('   Data file: %s\n', data_file);
fprintf('   OCV file: %s\n', ocv_file);

if exist(data_file, 'file')
    fprintf('   ✅ Data file exists\n');
end
if exist(ocv_file, 'file')
    fprintf('   ✅ OCV file exists\n');
    load(ocv_file, 'ocv_data');
    fprintf('   📊 OCV contains %d points\n', length(ocv_data.SOC));
    fprintf('   📅 Created: %s\n', ocv_data.date_created);
    if isfield(ocv_data, 'last_used')
        fprintf('   📅 Last used: %s\n', ocv_data.last_used);
    end
end
fprintf('========================================\n');