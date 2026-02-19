%% FIT 1-RC ECM PARAMETERS FOR A SINGLE CYCLE WITH BOUNDS
% Uses fmincon with bounds to ensure physically realistic parameters
%
% File: matlab/04_parameter_id/fit_ecm_1rc.m

function [x_opt, fval, V_sim, exitflag] = fit_ecm_1rc(cycle_data, ocv_data, x0)
    % FIT_ECM_1RC Optimize 1-RC parameters for a single cycle with bounds
    
    fprintf('🔧 Fitting 1-RC ECM for cycle...\n');
    
    %% ========== VALIDATE INPUT DATA ==========
    if ~isstruct(cycle_data)
        error('cycle_data must be a structure');
    end
    
    % Ensure time is a numeric vector
    if isnumeric(cycle_data.time)
        t = cycle_data.time(:);  % Make column vector
    else
        error('cycle_data.time must be numeric');
    end
    
    if isnumeric(cycle_data.I)
        I = cycle_data.I(:);
    else
        error('cycle_data.I must be numeric');
    end
    
    if isnumeric(cycle_data.V)
        V = cycle_data.V(:);
    else
        error('cycle_data.V must be numeric');
    end
    
    if length(t) ~= length(I) || length(t) ~= length(V)
        error('time, I, and V must have same length');
    end
    
    fprintf('   Data points: %d\n', length(t));
    fprintf('   Duration: %.1f s\n', t(end));
    fprintf('   Current: %.3f A\n', mean(abs(I)));
    
    %% ========== SET DEFAULT INITIAL GUESS ==========
    if nargin < 3 || isempty(x0)
        x0 = [0.15, 0.08, 40000];  % [R0, R1, C1]
    end
    
    %% ========== SET REALISTIC BOUNDS ==========
    % Physical bounds for Li-ion batteries
    lb = [0.01, 0.001, 100];        % Lower bounds
    ub = [0.5, 2.0, 100000];         % R1 upper bound increased to 2.0 Ω
    fprintf('\n📊 Parameter bounds:\n');
    fprintf('   R0: [%.3f, %.3f] Ω\n', lb(1), ub(1));
    fprintf('   R1: [%.3f, %.3f] Ω\n', lb(2), ub(2));
    fprintf('   C1: [%.0f, %.0f] F\n', lb(3), ub(3));
    
    %% ========== PREPARE DATA FOR COST FUNCTION ==========
    data.time = t;
    data.I = I;
    data.V = V;
    data.Q = cycle_data.Q;
    data.OCV = ocv_data;
    
    %% ========== SET OPTIMIZATION OPTIONS ==========
    options = optimoptions('fmincon', ...
        'Display', 'iter', ...
        'Algorithm', 'sqp', ...
        'MaxIterations', 200, ...
        'MaxFunctionEvaluations', 1000, ...
        'OptimalityTolerance', 1e-4, ...
        'StepTolerance', 1e-4);
    
    %% ========== RUN OPTIMIZATION WITH BOUNDS ==========
    fprintf('\n🚀 Running fmincon optimization with bounds...\n');
    tic;
    
    [x_opt, fval, exitflag, output] = fmincon(@(x) cost_ecm_1rc(x, data), ...
        x0, [], [], [], [], lb, ub, [], options);
    
    opt_time = toc;
    
    %% ========== CALCULATE FINAL SIMULATION ==========
    [~, V_sim] = cost_ecm_1rc(x_opt, data);
    
    %% ========== DISPLAY RESULTS ==========
    fprintf('\n✅ Optimization complete in %.1f seconds\n', opt_time);
    fprintf('   Function evaluations: %d\n', output.funcCount);
    fprintf('   Exit flag: %d\n', exitflag);
    fprintf('\n📊 Optimal Parameters:\n');
    fprintf('   R0 = %.4f Ω\n', x_opt(1));
    fprintf('   R1 = %.4f Ω\n', x_opt(2));
    fprintf('   C1 = %.0f F\n', x_opt(3));
    fprintf('   τ = %.1f s\n', x_opt(2) * x_opt(3));
    fprintf('   RMSE = %.1f mV\n', fval);
    
    %% ========== PLOT RESULTS ==========
    figure('Position', [100, 100, 1200, 600]);
    
    % Voltage comparison
    subplot(1,2,1);
    plot(t, V, 'b-', 'LineWidth', 1.5); hold on;
    plot(t, V_sim, 'r--', 'LineWidth', 1.5);
    xlabel('Time (s)'); ylabel('Voltage (V)');
    title(sprintf('Voltage Fit (RMSE = %.1f mV)', fval));
    legend('Measured', 'Fitted', 'Location', 'best');
    grid on;
    
    % Error
    subplot(1,2,2);
    error = (V - V_sim) * 1000;
    plot(t, error, 'k-', 'LineWidth', 1);
    xlabel('Time (s)'); ylabel('Error (mV)');
    title('Fitting Error');
    grid on; yline(0, 'r--');
    
    sgtitle('1-RC ECM Parameter Fitting Results', 'FontSize', 14, 'FontWeight', 'bold');
    
end