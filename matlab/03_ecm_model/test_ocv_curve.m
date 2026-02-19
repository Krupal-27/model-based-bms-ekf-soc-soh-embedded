%% TEST OCV CURVE CONSTRUCTION - MAIN SCRIPT
clear; clc; close all;

%% ========== SETUP ==========
cd('C:\Users\Krupal Babariya\Desktop\battery-bms-ecm-soc-soh\');
addpath(genpath('matlab'));

fprintf('========================================\n');
fprintf('🔧 TEST OCV CURVE CONSTRUCTION\n');
fprintf('========================================\n\n');

%% ========== LOAD DATA ==========
fprintf('📂 Loading discharge data...\n');

load('data/processed/cell01_cycles.mat', 'cycles');

% Find first discharge cycle
for i = 1:length(cycles)
    if strcmp(cycles(i).type, 'discharge')
        d = cycles(i);
        fprintf('✅ Found discharge cycle #%d\n', i);
        break;
    end
end

%% ========== TRIM DISCHARGE DATA ==========
current_threshold = 0.1;
start_idx = find(abs(d.I) > current_threshold, 1, 'first');
end_idx = find(abs(d.I) > current_threshold, 1, 'last');

d_trimmed = struct();
d_trimmed.time = d.time(start_idx:end_idx) - d.time(start_idx);
d_trimmed.V = d.V(start_idx:end_idx);
d_trimmed.I = d.I(start_idx:end_idx);
d_trimmed.Q = d.Q;

fprintf('\n📊 Trimmed data:\n');
fprintf('   Points: %d\n', length(d_trimmed.time));
fprintf('   Duration: %.1f s\n', d_trimmed.time(end));
fprintf('   Current: %.3f A\n', mean(abs(d_trimmed.I)));
fprintf('   Capacity: %.3f Ah\n\n', d_trimmed.Q);

%% ========== CREATE MANUAL OCV CURVE ==========
fprintf('🔧 Creating manual OCV curve...\n');

% SOC points (0 to 1 in 5% increments)
SOC_lookup = (0:0.05:1)';

% Manual OCV values for Li-ion (adjust based on your battery)
OCV_lookup = [3.00; 3.20; 3.30; 3.40; 3.50; 3.60; 3.70; 3.80; 
              3.90; 4.00; 4.10; 4.15; 4.18; 4.19; 4.20; 4.20; 
              4.20; 4.20; 4.20; 4.20; 4.20];

fprintf('✅ Manual OCV curve created:\n');
fprintf('   SOC = 0 → OCV = %.3f V\n', OCV_lookup(1));
fprintf('   SOC = 1 → OCV = %.3f V\n\n', OCV_lookup(end));

%% ========== CALCULATE SOC FOR DISCHARGE ==========
dt = mean(diff(d_trimmed.time));
Q = d_trimmed.Q;
dQ = abs(d_trimmed.I) * dt;
Q_removed = cumsum(dQ);
SOC = 1 - Q_removed / (Q * 3600);
SOC = max(min(SOC, 1), 0);

%% ========== PLOT OCV CURVE ==========
figure('Position', [100, 100, 1200, 500]);

subplot(1,2,1);
plot(SOC_lookup, OCV_lookup, 'b-', 'LineWidth', 2);
xlabel('SOC'); ylabel('OCV (V)');
title('Manual OCV-SOC Curve');
grid on; xlim([0,1]); ylim([2.5, 4.5]);

subplot(1,2,2);
plot(d_trimmed.time, d_trimmed.V, 'b-', 'LineWidth', 1.5); hold on;
xlabel('Time (s)'); ylabel('Voltage (V)');
title('Discharge Voltage');
grid on;

sgtitle('OCV Curve Test', 'FontSize', 14, 'FontWeight', 'bold');

%% ========== SAVE OCV DATA ==========
ocv_data = struct();
ocv_data.SOC = SOC_lookup;
ocv_data.OCV = OCV_lookup;
ocv_data.method = 'manual';
ocv_data.battery_id = 'B0005';
ocv_data.date = datestr(now);

save('data/processed/B0005_OCV_manual.mat', 'ocv_data');
fprintf('💾 Saved: data/processed/B0005_OCV_manual.mat\n');