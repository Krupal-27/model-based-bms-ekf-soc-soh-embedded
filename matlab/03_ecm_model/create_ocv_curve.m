%% CREATE AND SAVE OCV CURVE FOR BATTERY B0005
clear; clc;

%% ========== LOAD BATTERY DATA ==========
load('data/processed/cell01_cycles.mat', 'cycles');

% Find discharge cycles to extract OCV
discharge_cycles = [];
for i = 1:length(cycles)
    if strcmp(cycles(i).type, 'discharge')
        discharge_cycles = [discharge_cycles, i];
    end
end

fprintf('Found %d discharge cycles\n', length(discharge_cycles));

%% ========== METHOD 1: Extract OCV from slow discharge ==========
% Use first discharge cycle at low rate (if available)
cycle_idx = discharge_cycles(1);  % First discharge cycle
discharge = cycles(cycle_idx);

% Get voltage and SOC data
V = discharge.V;
I = discharge.I;
t = discharge.time;

% Calculate SOC using Coulomb counting
dt = [diff(t); 1];  % time steps
Q_nom = 1.86;  % Ah nominal capacity
SOC = zeros(length(t), 1);
SOC(1) = 1;  % Start at 100%

for k = 2:length(t)
    SOC(k) = SOC(k-1) - I(k) * dt(k) / (Q_nom * 3600);
end
SOC = max(min(SOC, 1), 0);

%% ========== METHOD 2: Create smooth OCV curve ==========
% Create smooth OCV-SOC relationship
SOC_points = (0:0.01:1)';  % 101 points from 0% to 100%

% Fit a smooth curve to the data
% This is a typical Li-ion OCV curve shape
OCV_fit = 3.2 + 1.0 * SOC_points.^0.5 + 0.1 * SOC_points.^2;

% Or extract from actual data using interpolation
OCV_from_data = interp1(SOC, V, SOC_points, 'pchip');

%% ========== METHOD 3: Use theoretical curve ==========
% Theoretical OCV for Li-ion (simplified)
OCV_theoretical = 3.0 + 1.2 * SOC_points;

%% ========== PLOT AND COMPARE ==========
figure('Position', [100, 100, 1200, 500]);

subplot(1,2,1);
plot(SOC, V, 'b.', 'MarkerSize', 3, 'DisplayName', 'Measured');
hold on;
plot(SOC_points, OCV_fit, 'r-', 'LineWidth', 2, 'DisplayName', 'Fitted');
plot(SOC_points, OCV_from_data, 'g--', 'LineWidth', 2, 'DisplayName', 'Interpolated');
xlabel('SOC');
ylabel('OCV (V)');
title('OCV vs SOC Relationship');
legend('Location', 'best');
grid on;
xlim([0, 1]);
ylim([2.5, 4.3]);

subplot(1,2,2);
plot(SOC_points, OCV_fit - OCV_from_data, 'k-', 'LineWidth', 1.5);
xlabel('SOC');
ylabel('Difference (V)');
title('Fitted vs Interpolated OCV');
grid on;
xlim([0, 1]);

%% ========== SAVE THE OCV CURVE ==========
OCV_data = struct();
OCV_data.SOC_points = SOC_points;
OCV_data.OCV_values = OCV_fit;  % Choose which one you prefer
OCV_data.battery_id = 'B0005';
OCV_data.source_cycle = cycle_idx;
OCV_data.date_created = datestr(now);

save('data/processed/B0005_OCV_curve.mat', 'OCV_data');
fprintf('\n✅ OCV curve saved to: data/processed/B0005_OCV_curve.mat\n');
fprintf('   SOC points: %d\n', length(SOC_points));
fprintf('   OCV range: %.3fV to %.3fV\n', min(OCV_fit), max(OCV_fit));