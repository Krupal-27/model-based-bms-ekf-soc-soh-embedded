%% FIT 1-RC ECM PARAMETERS USING OPTIMIZATION
% Finds optimal R0, R1, C1 that minimize voltage error
%
% File: matlab/04_parameter_id/fit_ecm_parameters.m

clear; clc; close all;

cd('C:\Users\Krupal Babariya\Desktop\battery-bms-ecm-soc-soh\');
addpath(genpath('matlab'));

fprintf('========================================\n');
fprintf('🔧 1-RC ECM PARAMETER FITTING\n');
fprintf('========================================\n\n');

%% ========== LOAD FITTING DATA ==========
if exist('data/processed/fitting_cycle.mat', 'file')
    load('data/processed/fitting_cycle.mat', 'fitting_data');
    fprintf('✅ Loaded fitting cycle #%d\n', fitting_data.cycle_num);
else
    % Create fitting data from first discharge
    fprintf('📂 Creating fitting data from cycle #4...\n');
    load('data/processed/cell01_cycles.mat', 'cycles');
    
    % Use cycle 4 (first discharge)
    d = cycles(4);
    
    % Trim
    start_idx = find(abs(d.I) > 0.1, 1, 'first');
    end_idx = find(abs(d.I) > 0.1, 1, 'last');
    
    fitting_data.time = d.time(start_idx:end_idx) - d.time(start_idx);
    fitting_data.V = d.V(start_idx:end_idx);
    fitting_data.I = d.I(start_idx:end_idx);
    fitting_data.Q = d.Q;
    fitting_data.cycle_num = 4;
end

fprintf('   Points: %d\n', length(fitting_data.time));
fprintf('   Duration: %.1f s\n', fitting_data.time(end));
fprintf('   Current: %.3f A\n', mean(abs(fitting_data.I)));
fprintf('   Capacity: %.3f Ah\n\n', fitting_data.Q);

%% ========== LOAD OCV CURVE ==========
load('data/processed/B0005_OCV_manual.mat', 'ocv_data');
fitting_data.OCV = ocv_data;
fprintf('✅ Loaded OCV curve\n\n');

%% ========== SET OPTIMIZATION PARAMETERS ==========
% Initial guess (from your previous results)
x0 = [0.15, 0.08, 40000];  % [R0, R1, C1]

% Parameter bounds
lb = [0.01, 0.001, 100];     % Lower bounds
ub = [0.3, 0.2, 100000];      % Upper bounds

fprintf('📊 Optimization settings:\n');
fprintf('   Initial guess: R0=%.3f, R1=%.3f, C1=%.0f\n', x0(1), x0(2), x0(3));
fprintf('   Bounds: R0=[%.2f,%.2f], R1=[%.3f,%.3f], C1=[%.0f,%.0f]\n\n', ...
    lb(1), ub(1), lb(2), ub(2), lb(3), ub(3));

%% ========== RUN OPTIMIZATION ==========
fprintf('🔧 Running optimization (this may take a few minutes)...\n');

% Optimization options
options = optimoptions('fmincon', ...
    'Display', 'iter-detailed', ...
    'Algorithm', 'sqp', ...
    'MaxIterations', 100, ...
    'MaxFunctionEvaluations', 1000, ...
    'OptimalityTolerance', 1e-4, ...
    'StepTolerance', 1e-4, ...
    'PlotFcn', 'optimplotfval');

% Cost function handle
cost_fun = @(x) cost_ecm_1rc(x, fitting_data);

% Run optimization
tic;
[x_opt, fval, exitflag, output] = fmincon(cost_fun, x0, [], [], [], [], ...
    lb, ub, [], options);
opt_time = toc;

%% ========== EXTRACT OPTIMAL PARAMETERS ==========
R0_opt = x_opt(1);
R1_opt = x_opt(2);
C1_opt = x_opt(3);
tau_opt = R1_opt * C1_opt;

fprintf('\n✅ Optimization complete in %.1f seconds\n', opt_time);
fprintf('   Exit flag: %d\n', exitflag);
fprintf('   Function evaluations: %d\n', output.funcCount);
fprintf('\n');

%% ========== COMPARE WITH YOUR PREVIOUS PARAMETERS ==========
fprintf('📊 PARAMETER COMPARISON:\n');
fprintf('   %-12s %-15s %-15s %-15s\n', 'Parameter', 'Previous', 'Optimized', 'Change');
fprintf('   %-12s %-15.4f %-15.4f %-15.1f%%\n', 'R0 (Ω)', 0.1767, R0_opt, (R0_opt/0.1767-1)*100);
fprintf('   %-12s %-15.4f %-15.4f %-15.1f%%\n', 'R1 (Ω)', 0.0990, R1_opt, (R1_opt/0.0990-1)*100);
fprintf('   %-12s %-15.0f %-15.0f %-15.1f%%\n', 'C1 (F)', 50000, C1_opt, (C1_opt/50000-1)*100);
fprintf('   %-12s %-15.1f %-15.1f %-15.1f%%\n', 'τ (s)', 4950, tau_opt, (tau_opt/4950-1)*100);

%% ========== EVALUATE FINAL COST ==========
[final_cost, V_sim] = cost_ecm_1rc(x_opt, fitting_data, true);
fprintf('\n📊 Final RMSE: %.1f mV\n', final_cost);

%% ========== PLOT RESULTS ==========
figure('Position', [100, 100, 1400, 900]);

% Voltage comparison
subplot(2,3,1);
plot(fitting_data.time, fitting_data.V, 'b-', 'LineWidth', 2); hold on;
plot(fitting_data.time, V_sim, 'r--', 'LineWidth', 1.5);
xlabel('Time (s)'); ylabel('Voltage (V)');
title(sprintf('Voltage Fit (RMSE = %.1f mV)', final_cost));
legend('Measured', 'Fitted', 'Location', 'best');
grid on;

% Error
subplot(2,3,2);
error = (fitting_data.V - V_sim) * 1000;
plot(fitting_data.time, error, 'k-', 'LineWidth', 1);
xlabel('Time (s)'); ylabel('Error (mV)');
title('Fitting Error');
grid on; yline(0, 'r--');

% Error histogram
subplot(2,3,3);
histogram(error, 50, 'FaceColor', [0.2, 0.6, 0.8]);
xlabel('Error (mV)'); ylabel('Frequency');
title('Error Distribution');
grid on;

% Parameter convergence (if history was saved)
subplot(2,3,4);
axis off;
text(0.1, 0.9, 'OPTIMIZED PARAMETERS', 'FontSize', 12, 'FontWeight', 'bold');
text(0.1, 0.7, sprintf('R0 = %.4f Ω', R0_opt), 'FontSize', 11);
text(0.1, 0.55, sprintf('R1 = %.4f Ω', R1_opt), 'FontSize', 11);
text(0.1, 0.4, sprintf('C1 = %.0f F', C1_opt), 'FontSize', 11);
text(0.1, 0.25, sprintf('τ = %.1f s', tau_opt), 'FontSize', 11);
text(0.1, 0.1, sprintf('RMSE = %.1f mV', final_cost), 'FontSize', 11);

% Cost function landscape (simplified)
subplot(2,3,5);
R0_range = linspace(lb(1), ub(1), 20);
cost_R0 = zeros(size(R0_range));
for i = 1:length(R0_range)
    cost_R0(i) = cost_ecm_1rc([R0_range(i), R1_opt, C1_opt], fitting_data, false);
end
plot(R0_range, cost_R0, 'b-', 'LineWidth', 1.5); hold on;
plot(R0_opt, final_cost, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
xlabel('R0 (Ω)'); ylabel('RMSE (mV)');
title('Cost vs R0');
grid on;

subplot(2,3,6);
R1_range = linspace(lb(2), ub(2), 20);
cost_R1 = zeros(size(R1_range));
for i = 1:length(R1_range)
    cost_R1(i) = cost_ecm_1rc([R0_opt, R1_range(i), C1_opt], fitting_data, false);
end
plot(R1_range, cost_R1, 'g-', 'LineWidth', 1.5); hold on;
plot(R1_opt, final_cost, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
xlabel('R1 (Ω)'); ylabel('RMSE (mV)');
title('Cost vs R1');
grid on;

sgtitle('1-RC ECM Parameter Fitting Results', 'FontSize', 14, 'FontWeight', 'bold');

%% ========== SAVE OPTIMIZED PARAMETERS ==========
opt_params.R0 = R0_opt;
opt_params.R1 = R1_opt;
opt_params.C1 = C1_opt;
opt_params.tau = tau_opt;
opt_params.rmse_mV = final_cost;
opt_params.cycle_used = fitting_data.cycle_num;
opt_params.exitflag = exitflag;
opt_params.optimization_time = opt_time;
opt_params.date = datestr(now);

save('data/processed/B0005_params_optimized.mat', 'opt_params');
fprintf('\n💾 Saved: data/processed/B0005_params_optimized.mat\n');

%% ========== VALIDATE ON DIFFERENT CYCLE ==========
fprintf('\n🔧 Validating on different cycle...\n');

% Use cycle 5 for validation
d_val = cycles(5);
start_idx = find(abs(d_val.I) > 0.1, 1, 'first');
end_idx = find(abs(d_val.I) > 0.1, 1, 'last');
t_val = d_val.time(start_idx:end_idx) - d_val.time(start_idx);
V_val = d_val.V(start_idx:end_idx);
I_val = d_val.I(start_idx:end_idx);

% Create validation data structure
val_data.t = t_val;
val_data.I = I_val;
val_data.V = V_val;
val_data.Q = d_val.Q;
val_data.OCV = ocv_data;

% Simulate with optimized parameters
[val_cost, V_val_sim] = cost_ecm_1rc([R0_opt, R1_opt, C1_opt], val_data, true);
fprintf('   Validation RMSE: %.1f mV\n', val_cost);

%% ========== FINAL SUMMARY ==========
fprintf('\n========================================\n');
fprintf('📊 FINAL SUMMARY\n');
fprintf('========================================\n');
fprintf('   Optimal Parameters:\n');
fprintf('   R0 = %.4f Ω\n', R0_opt);
fprintf('   R1 = %.4f Ω\n', R1_opt);
fprintf('   C1 = %.0f F\n', C1_opt);
fprintf('   τ = %.1f s\n', tau_opt);
fprintf('   Fitting RMSE: %.1f mV\n', final_cost);
fprintf('   Validation RMSE: %.1f mV\n', val_cost);
fprintf('========================================\n');