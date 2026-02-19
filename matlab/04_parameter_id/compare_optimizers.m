%% COMPARE DIFFERENT OPTIMIZATION METHODS
% Tests fmincon, lsqnonlin, patternsearch, etc.

clear; clc; close all;

cd('C:\Users\Krupal Babariya\Desktop\battery-bms-ecm-soc-soh\');
addpath(genpath('matlab'));

%% ========== LOAD DATA ==========
load('data/processed/fitting_cycle.mat', 'fitting_data');
load('data/processed/B0005_OCV_manual.mat', 'ocv_data');
fitting_data.OCV = ocv_data;

%% ========== DEFINE OPTIMIZATION PROBLEM ==========
x0 = [0.15, 0.08, 40000];
lb = [0.01, 0.001, 100];
ub = [0.3, 0.2, 100000];

cost_fun = @(x) cost_ecm_1rc(x, fitting_data);

%% ========== METHOD 1: fmincon (default) ==========
fprintf('\n🔧 Method 1: fmincon (SQP)\n');
options = optimoptions('fmincon', 'Display', 'off', 'Algorithm', 'sqp');
tic;
[x_fmin, fval_fmin] = fmincon(cost_fun, x0, [], [], [], [], lb, ub, [], options);
t_fmin = toc;
fprintf('   Time: %.2f s, RMSE: %.1f mV\n', t_fmin, fval_fmin);

%% ========== METHOD 2: lsqnonlin ==========
fprintf('\n🔧 Method 2: lsqnonlin\n');
cost_lsq = @(x) sqrt(cost_ecm_1rc(x, fitting_data)/1000);  % Convert to proper form
options = optimoptions('lsqnonlin', 'Display', 'off');
tic;
[x_lsq, resnorm] = lsqnonlin(cost_lsq, x0, lb, ub, options);
t_lsq = toc;
fval_lsq = sqrt(resnorm/length(fitting_data.t))*1000;
fprintf('   Time: %.2f s, RMSE: %.1f mV\n', t_lsq, fval_lsq);

%% ========== METHOD 3: patternsearch ==========
fprintf('\n🔧 Method 3: patternsearch\n');
options = optimoptions('patternsearch', 'Display', 'off');
tic;
[x_ps, fval_ps] = patternsearch(cost_fun, x0, [], [], [], [], lb, ub, [], options);
t_ps = toc;
fprintf('   Time: %.2f s, RMSE: %.1f mV\n', t_ps, fval_ps);

%% ========== COMPARE RESULTS ==========
fprintf('\n📊 OPTIMIZER COMPARISON:\n');
fprintf('   %-15s %-10s %-12s %-12s %-12s %-10s\n', ...
    'Method', 'Time(s)', 'R0(Ω)', 'R1(Ω)', 'C1(F)', 'RMSE(mV)');
fprintf('   %-15s %-10.1f %-12.4f %-12.4f %-12.0f %-10.1f\n', ...
    'fmincon', t_fmin, x_fmin(1), x_fmin(2), x_fmin(3), fval_fmin);
fprintf('   %-15s %-10.1f %-12.4f %-12.4f %-12.0f %-10.1f\n', ...
    'lsqnonlin', t_lsq, x_lsq(1), x_lsq(2), x_lsq(3), fval_lsq);
fprintf('   %-15s %-10.1f %-12.4f %-12.4f %-12.0f %-10.1f\n', ...
    'patternsearch', t_ps, x_ps(1), x_ps(2), x_ps(3), fval_ps);