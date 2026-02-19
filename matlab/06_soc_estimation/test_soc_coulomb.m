%% TEST COULOMB COUNTING SOC ESTIMATION
clear; clc; close all;

cd('C:\Users\Krupal Babariya\Desktop\battery-bms-ecm-soc-soh\');
addpath(genpath('matlab'));

fprintf('========================================\n');
fprintf('🔋 TEST COULOMB COUNTING SOC\n');
fprintf('========================================\n\n');

%% ========== LOAD TEST DATA ==========
fprintf('📂 Loading discharge cycle...\n');

load('data/processed/cell01_cycles.mat', 'cycles');

% Find a discharge cycle
for i = 1:length(cycles)
    if strcmp(cycles(i).type, 'discharge')
        d = cycles(i);
        fprintf('✅ Using cycle #%d for testing\n', i);
        break;
    end
end

% Use full cycle (including rest)
t = d.time;
I = d.I;
Q_nom = d.Q;

fprintf('   Points: %d\n', length(t));
fprintf('   Duration: %.1f s\n', t(end));
fprintf('   Q_nom: %.3f Ah\n\n', Q_nom);

%% ========== TEST 1: IDEAL COULOMB COUNTING ==========
fprintf('📊 TEST 1: Ideal Coulomb Counting (no bias)\n');

[SOC_ideal, Q_removed, info_ideal] = soc_coulomb(I, t, Q_nom, 1.0, 0);

fprintf('\n');

%% ========== TEST 2: WITH BIAS ERROR ==========
fprintf('📊 TEST 2: With +10mA bias error\n');

I_bias = 0.01;  % 10mA positive bias
[SOC_bias, ~, info_bias] = soc_coulomb(I, t, Q_nom, 1.0, I_bias);

fprintf('\n');

%% ========== TEST 3: WITH BIAS CORRECTION ==========
fprintf('📊 TEST 3: With bias correction\n');

% Estimate bias from rest periods (where I should be 0)
rest_mask = abs(I) < 0.1;
if any(rest_mask)
    estimated_bias = mean(I(rest_mask));
    fprintf('   Estimated bias from rest: %.3f mA\n', estimated_bias*1000);
else
    estimated_bias = 0;
    fprintf('   No rest periods found, using 0 bias\n');
end

[SOC_corrected, ~, info_corrected] = soc_coulomb(I, t, Q_nom, 1.0, estimated_bias);

%% ========== PLOT COMPARISON ==========
figure('Position', [100, 100, 1400, 900]);

% Plot 1: Current profile
subplot(2,3,1);
plot(t/3600, I, 'b-', 'LineWidth', 1);
xlabel('Time (hours)'); ylabel('Current (A)');
title('Current Profile');
grid on;

% Plot 2: SOC comparison
subplot(2,3,2);
plot(t/3600, SOC_ideal, 'g-', 'LineWidth', 2, 'DisplayName', 'Ideal'); hold on;
plot(t/3600, SOC_bias, 'r--', 'LineWidth', 1.5, 'DisplayName', '+10mA Bias');
plot(t/3600, SOC_corrected, 'b-.', 'LineWidth', 1.5, 'DisplayName', 'Corrected');
xlabel('Time (hours)'); ylabel('SOC');
title('SOC Estimation Comparison');
legend('Location', 'best');
grid on; ylim([0, 1.1]);

% Plot 3: SOC error due to bias
subplot(2,3,3);
error_bias = SOC_bias - SOC_ideal;
error_corrected = SOC_corrected - SOC_ideal;
plot(t/3600, error_bias*100, 'r-', 'LineWidth', 1.5, 'DisplayName', '+10mA Bias');
hold on;
plot(t/3600, error_corrected*100, 'b-', 'LineWidth', 1.5, 'DisplayName', 'Corrected');
xlabel('Time (hours)'); ylabel('SOC Error (%)');
title('Cumulative Error');
legend('Location', 'best');
grid on;

% Plot 4: Cumulative charge removed
subplot(2,3,4);
plot(t/3600, Q_removed, 'k-', 'LineWidth', 1.5);
xlabel('Time (hours)'); ylabel('Charge Removed (Ah)');
title('Coulomb Counting');
grid on;

% Plot 5: Bias impact over time
subplot(2,3,5);
bias_impact = I_bias * t(end) / 3600;  % Ah drift per hour
fprintf('\n📊 Bias Impact Analysis:\n');
fprintf('   Bias current: %.1f mA\n', I_bias*1000);
fprintf('   Test duration: %.1f hours\n', t(end)/3600);
fprintf('   Theoretical drift: %.3f Ah (%.1f%% SOC)\n', ...
    bias_impact, bias_impact/Q_nom*100);

% Create bar chart of final SOC values
subplot(2,3,6);
final_SOC = [SOC_ideal(end), SOC_bias(end), SOC_corrected(end)] * 100;
bar(final_SOC, 'FaceColor', [0.3, 0.6, 0.8]);
set(gca, 'XTickLabel', {'Ideal', '+10mA Bias', 'Corrected'});
ylabel('Final SOC (%)');
title('Final SOC Comparison');
grid on;
ylim([0, 100]);

sgtitle('Coulomb Counting SOC Estimation', 'FontSize', 14, 'FontWeight', 'bold');

%% ========== SUMMARY ==========
fprintf('\n========================================\n');
fprintf('📊 COULOMB COUNTING SUMMARY\n');
fprintf('========================================\n');
fprintf('   Ideal final SOC: %.1f%%\n', SOC_ideal(end)*100);
fprintf('   Biased final SOC: %.1f%%\n', SOC_bias(end)*100);
fprintf('   Corrected final SOC: %.1f%%\n', SOC_corrected(end)*100);
fprintf('   Bias correction improved accuracy by %.1f%%\n', ...
    (abs(SOC_bias(end)-SOC_ideal(end)) - abs(SOC_corrected(end)-SOC_ideal(end)))*100);
fprintf('========================================\n');

%% ========== SAVE RESULTS ==========
save('data/processed/soc_coulomb_results.mat', 'SOC_ideal', 'SOC_bias', 'SOC_corrected');
fprintf('\n💾 Saved: data/processed/soc_coulomb_results.mat\n');