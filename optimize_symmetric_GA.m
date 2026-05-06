%% =========================================================================
%  04_optimize_symmetric_GA.m
%  Symmetric 2-parameter SLIP optimisation using Genetic Algorithm + fmincon.
%
%  MODEL:  K_R = K_L = K,   L0_R = L0_L = L0
%  OPTIMISES: p = [K, L0]
%
%  HOW TO USE
%  ----------
%  1. Run 02_curve_fit_2param.m first to populate the 2-parameter Excel.
%  2. Set subject_id, trial_key, and mat_file below.
%  3. Run.  Results are appended to the symmetric log Excel.
%
%  OUTPUTS
%  -------
%  <log_file_sym>  (Excel) – optimisation results row
%  Results_<trial>/ – plots and a .mat with all time-series data
%% =========================================================================

clc; clear; close all;

%% --- USER SETTINGS -------------------------------------------------------
subject_id = 14;
trial_key  = 'E1';
mat_file   = 'Segment_S14_E1_10.642_14.333.mat';  % segment to optimise
%% -------------------------------------------------------------------------

addpath(fullfile(fileparts(mfilename('fullpath')), 'config'));
addpath(fullfile(fileparts(mfilename('fullpath')), 'functions'));
cfg = get_subject_config(subject_id);

param_file = cfg.param_file_2p;
log_file   = cfg.log_file_sym;

if ~isfile(mat_file),   error('Segment file not found: %s', mat_file);   end
if ~isfile(param_file), error('Parameter table not found: %s', param_file); end

%% --- Load data -----------------------------------------------------------
S   = load(mat_file);
C   = select_struct(S);
Tab = readtable(param_file, 'VariableNamingRule', 'preserve');

%% --- Reference parameters for this segment -------------------------------
row_idx = find(strcmp(Tab.Cut_Filename, mat_file), 1);
if isempty(row_idx)
    error('Segment ''%s'' not found in %s. Run 02_curve_fit_2param.m first.', ...
          mat_file, param_file);
end
K_ref  = abs(Tab.k_L_Nm(row_idx));
L0_ref = abs(Tab.L0_L_m(row_idx));
m_dyn  = Tab.Mass_Dyn_kg(row_idx);
fprintf('Reference (from 2-param fit):  K = %.1f N/m,  L0 = %.3f m,  m = %.1f kg\n', ...
        K_ref, L0_ref, m_dyn);

%% --- Optimisation bounds -------------------------------------------------
[lb, ub] = compute_stat_bounds(Tab, trial_key, 'symmetric');
fprintf('Search bounds (%s):  K [%.0f – %.0f],  L0 [%.3f – %.3f]\n', ...
        trial_key, lb(1), ub(1), lb(2), ub(2));

%% --- Build Human struct --------------------------------------------------
XR     = C.XFootRight(1);
XL     = C.XFootLeft(1);
x_mid  = 0.5 * (XR + XL);
xFoot  = 0.5 * abs(XR - XL);

Human.time  = C.time_rel(:);
Human.x_rel = C.COMX(:) - x_mid;
Human.y     = C.COMY(:);
Human.vx    = C.Vx(:);
Human.vy    = C.Vy(:);

mdl.m  = m_dyn;
mdl.g  = 9.81;
mdl.xf = xFoot;

q0       = [Human.x_rel(1), Human.y(1), 0, Human.vy(1)];
sim_dur  = Human.time(end) - Human.time(1);

%% --- GA optimisation: p = [K, L0] ----------------------------------------
rng(42);
obj = @(p) cost_fn_symmetric(p(1), p(2), Human, mdl, q0, sim_dur);

ga_opts = optimoptions('ga', ...
    'Display',        'iter', ...
    'PopulationSize', 100, ...
    'MaxGenerations', 200, ...
    'UseParallel',    false, ...
    'PlotFcn',        {@gaplotbestf, @gaplotrange}, ...
    'HybridFcn',      @fmincon);

fprintf('\nStarting Genetic Algorithm ...\n');
[p_best, f_best] = ga(obj, 2, [], [], [], [], lb, ub, [], ga_opts);

K_opt  = p_best(1);
L0_opt = p_best(2);

fprintf('\n=== SYMMETRIC GA RESULT ===\n');
fprintf('  K  = %.2f N/m\n', K_opt);
fprintf('  L0 = %.3f m\n',   L0_opt);
fprintf('  Cost (GA) = %.6f\n', f_best);

%% --- Forward simulation: optimised ---------------------------------------
mdl_opt = mdl;  mdl_opt.K = K_opt;  mdl_opt.L0 = L0_opt;

[t_opt, q_opt] = simulate_slip(mdl_opt, q0, sim_dur, 'symmetric');

dt = max(1e-3, median(diff(Human.time)));
t0 = max(t_opt(1),   Human.time(1));
t1 = min(t_opt(end), Human.time(end));
tc = (t0:dt:t1).';

Xo  = interp1(t_opt, q_opt(:,1), tc);  Yo  = interp1(t_opt, q_opt(:,2), tc);
Vxo = interp1(t_opt, q_opt(:,3), tc);  Vyo = interp1(t_opt, q_opt(:,4), tc);
Xr  = interp1(Human.time, Human.x_rel, tc);
Yr  = interp1(Human.time, Human.y,     tc);
Vxr = interp1(Human.time, Human.vx,    tc);
Vyr = interp1(Human.time, Human.vy,    tc);

%% --- Error metrics -------------------------------------------------------
MSE_y  = mean((Yr  - Yo ).^2, 'omitnan');
MSE_x  = mean((Xr  - Xo ).^2, 'omitnan');
MSE_vy = mean((Vyr - Vyo).^2, 'omitnan');
MSE_vx = mean((Vxr - Vxo).^2, 'omitnan');
RMSE_y = sqrt(MSE_y);
RMSE_x = sqrt(MSE_x);

%% --- Results folder & plots ----------------------------------------------
results_dir = fullfile(pwd, ['Results_' trial_key]);
if ~isfolder(results_dir), mkdir(results_dir); end

fig = figure('Color', 'w', 'Name', sprintf('%s Sym GA – %s', cfg.subject_tag, trial_key));
subplot(2,2,1); hold on; grid on;
plot(tc, Yr, 'b', 'LineWidth', 1.5);
plot(tc, Yo, 'r--', 'LineWidth', 1.5);
ylabel('y [m]');  title('COM Y');  xlabel('t [s]');
legend('Measured', 'GA opt', 'Location', 'best');

subplot(2,2,2); hold on; grid on;
plot(tc, Xr, 'b', 'LineWidth', 1.5);
plot(tc, Xo, 'r--', 'LineWidth', 1.5);
ylabel('x_{rel} [m]');  title('COM X');  xlabel('t [s]');

subplot(2,2,3); hold on; grid on;
plot(tc, Vyr, 'b', 'LineWidth', 1.5);
plot(tc, Vyo, 'r--', 'LineWidth', 1.5);
ylabel('v_y [m/s]');  title('Velocity Y');  xlabel('t [s]');

subplot(2,2,4); hold on; grid on;
plot(tc, Vxr, 'b', 'LineWidth', 1.5);
plot(tc, Vxo, 'r--', 'LineWidth', 1.5);
ylabel('v_x [m/s]');  title('Velocity X');  xlabel('t [s]');

sgtitle(sprintf('%s | %s | K=%.0f N/m | L0=%.3f m', ...
        cfg.subject_tag, trial_key, K_opt, L0_opt));

plot_path = fullfile(results_dir, sprintf('Sym_GA_%s_%s.png', cfg.subject_tag, trial_key));
exportgraphics(fig, plot_path, 'BackgroundColor', 'white');
fprintf('Plot saved: %s\n', plot_path);

%% --- Save run data -------------------------------------------------------
[~, base_name] = fileparts(mat_file);
run_data = struct('subject', cfg.subject_tag, 'trial', trial_key, ...
                  'mat_file', mat_file, 'K_opt', K_opt, 'L0_opt', L0_opt, ...
                  'K_ref', K_ref, 'L0_ref', L0_ref, ...
                  't_opt', t_opt, 'q_opt', q_opt, 't_common', tc, ...
                  'Xr', Xr, 'Yr', Yr, 'Vxr', Vxr, 'Vyr', Vyr, ...
                  'Xo', Xo, 'Yo', Yo, 'Vxo', Vxo, 'Vyo', Vyo);
save(fullfile(results_dir, ['RunData_Sym_' base_name '.mat']), '-struct', 'run_data');

%% --- Log to Excel --------------------------------------------------------
T_log = table(string(mat_file), datetime('now'), string(trial_key), ...
              string(cfg.subject_tag), string(cfg.gender), ...
              K_ref, L0_ref, m_dyn, ...
              K_opt, L0_opt, f_best, ...
              MSE_y, MSE_x, MSE_vy, MSE_vx, RMSE_y, RMSE_x, ...
              lb(1), ub(1), lb(2), ub(2), ...
    'VariableNames', { ...
        'Cut_Filename', 'Timestamp', 'Trial', 'Subject', 'Gender', ...
        'K_ref_Nm', 'L0_ref_m', 'Mass_kg', ...
        'K_opt_Nm', 'L0_opt_m', 'Cost_GA', ...
        'MSE_Y', 'MSE_X', 'MSE_Vy', 'MSE_Vx', 'RMSE_Y', 'RMSE_X', ...
        'K_lb', 'K_ub', 'L0_lb', 'L0_ub'});

log_to_excel(log_file, T_log);
fprintf('Log updated: %s\n', log_file);

%% --- Console summary -----------------------------------------------------
fprintf('\n========================================\n');
fprintf('  SYMMETRIC GA – %s %s\n', cfg.subject_tag, trial_key);
fprintf('========================================\n');
fprintf('  Reference:   K = %.1f N/m | L0 = %.3f m\n', K_ref, L0_ref);
fprintf('  Optimised:   K = %.2f N/m | L0 = %.3f m\n', K_opt, L0_opt);
fprintf('  RMSE_Y = %.4f m | RMSE_X = %.4f m\n', RMSE_y, RMSE_x);
fprintf('  Output dir:  %s\n', results_dir);
fprintf('========================================\n\n');

%% =========================================================================
function C = select_struct(S)
if isfield(S, 'Segment'),       C = S.Segment;
elseif isfield(S, 'Schnitt'),   C = S.Schnitt;
else,  error('No Segment or Schnitt field in loaded file.');
end
end
