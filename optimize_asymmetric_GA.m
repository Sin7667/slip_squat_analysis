%% =========================================================================
%  05_optimize_asymmetric_GA.m
%  Asymmetric 4-parameter SLIP optimisation using Genetic Algorithm + fmincon.
%
%  MODEL:  separate K_R, K_L, L0_R, L0_L for right and left legs
%  OPTIMISES: p = [K_R, K_L, L0_R, L0_L]
%
%  HOW TO USE
%  ----------
%  1. Run 02_curve_fit_2param.m first.
%  2. Set subject_id, trial_key, and mat_file.
%  3. Run.
%
%  OUTPUTS
%  -------
%  <log_file_asym>  – optimisation results
%  Results_<trial>/ – comparison plots and run data .mat
%% =========================================================================

clc; clear; close all;

%% --- USER SETTINGS -------------------------------------------------------
subject_id = 14;
trial_key  = 'E3';
mat_file   = 'Segment_S14_E3_15.507_18.518.mat';
%% -------------------------------------------------------------------------

addpath(fullfile(fileparts(mfilename('fullpath')), 'config'));
addpath(fullfile(fileparts(mfilename('fullpath')), 'functions'));
cfg = get_subject_config(subject_id);

param_file = cfg.param_file_2p;
log_file   = cfg.log_file_asym;

if ~isfile(mat_file),   error('Segment file not found: %s', mat_file);   end
if ~isfile(param_file), error('Parameter table not found: %s', param_file); end

%% --- Load data -----------------------------------------------------------
S   = load(mat_file);
C   = select_struct(S);
Tab = readtable(param_file, 'VariableNamingRule', 'preserve');

%% --- GRF reference for this segment --------------------------------------
row_idx = find(strcmp(Tab.Cut_Filename, mat_file), 1);
if isempty(row_idx)
    error('Segment ''%s'' not in %s.', mat_file, param_file);
end
k_L   = abs(Tab.k_L_Nm(row_idx));   L0_L = abs(Tab.L0_L_m(row_idx));
k_R   = abs(Tab.k_R_Nm(row_idx));   L0_R = abs(Tab.L0_R_m(row_idx));
m_dyn = Tab.Mass_Dyn_kg(row_idx);

fprintf('GRF reference:  k_L=%.1f | L0_L=%.3f | k_R=%.1f | L0_R=%.3f | m=%.1f kg\n', ...
        k_L, L0_L, k_R, L0_R, m_dyn);

%% --- Search bounds -------------------------------------------------------
[lb, ub] = compute_stat_bounds(Tab, trial_key, 'asymmetric');
fprintf('Bounds (%s):  K [%.0f–%.0f]  L0 [%.3f–%.3f]\n', ...
        trial_key, lb(1), ub(1), lb(3), ub(3));

%% --- Human struct --------------------------------------------------------
XR    = C.XFootRight(1);
XL    = C.XFootLeft(1);
x_mid = 0.5 * (XR + XL);
xFoot = 0.5 * abs(XR - XL);

Human.time  = C.time_rel(:);
Human.x_rel = C.COMX(:) - x_mid;
Human.y     = C.COMY(:);
Human.vx    = C.Vx(:);
Human.vy    = C.Vy(:);

mdl.m  = m_dyn;
mdl.g  = 9.81;
mdl.xf = xFoot;

q0      = [Human.x_rel(1), Human.y(1), Human.vx(1), Human.vy(1)];
sim_dur = Human.time(end) - Human.time(1);

%% --- GA: p = [K_R, K_L, L0_R, L0_L] ------------------------------------
rng(42);
obj = @(p) cost_fn_asymmetric(p, Human, mdl, q0, sim_dur);

ga_opts = optimoptions('ga', ...
    'Display',        'iter', ...
    'PopulationSize', 100, ...
    'MaxGenerations', 200, ...
    'UseParallel',    false, ...
    'PlotFcn',        {@gaplotbestf, @gaplotrange}, ...
    'HybridFcn',      @fmincon);

fprintf('\nStarting Genetic Algorithm (asymmetric, 4 parameters) ...\n');
[p_best, f_best] = ga(obj, 4, [], [], [], [], lb, ub, [], ga_opts);

K_R_opt  = p_best(1);  K_L_opt  = p_best(2);
L0_R_opt = p_best(3);  L0_L_opt = p_best(4);

fprintf('\n=== ASYMMETRIC GA RESULT ===\n');
fprintf('  K_R  = %.2f N/m  |  L0_R = %.3f m\n', K_R_opt,  L0_R_opt);
fprintf('  K_L  = %.2f N/m  |  L0_L = %.3f m\n', K_L_opt,  L0_L_opt);
fprintf('  Cost = %.6f\n', f_best);

%% --- Forward simulation: optimised only ----------------------------------
mdl_opt       = mdl;
mdl_opt.K_R   = K_R_opt;   mdl_opt.L0_R = L0_R_opt;
mdl_opt.K_L   = K_L_opt;   mdl_opt.L0_L = L0_L_opt;

[t_opt, q_opt] = simulate_slip(mdl_opt, q0, sim_dur, 'asymmetric');

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

MSE_y  = mean((Yr - Yo).^2,   'omitnan');
MSE_x  = mean((Xr - Xo).^2,   'omitnan');
MSE_vy = mean((Vyr - Vyo).^2, 'omitnan');
MSE_vx = mean((Vxr - Vxo).^2, 'omitnan');

%% --- Plots ---------------------------------------------------------------
results_dir = fullfile(pwd, ['Results_' trial_key]);
if ~isfolder(results_dir), mkdir(results_dir); end

fig1 = figure('Color', 'w', 'Name', 'Real vs. GA Optimised');
subplot(2,2,1); hold on; grid on;
plot(tc,Yr,'k','LineWidth',1.5); plot(tc,Yo,'r--','LineWidth',1.5);
ylabel('y [m]'); title('COM Y'); xlabel('t [s]');
legend('Measured','GA opt','Location','best');

subplot(2,2,2); hold on; grid on;
plot(tc,Xr,'k','LineWidth',1.5); plot(tc,Xo,'r--','LineWidth',1.5);
ylabel('x_{rel} [m]'); title('COM X'); xlabel('t [s]');

subplot(2,2,3); hold on; grid on;
plot(tc,Vyr,'k','LineWidth',1.4); plot(tc,Vyo,'r--','LineWidth',1.4);
ylabel('v_y [m/s]'); title('Velocity Y'); xlabel('t [s]');

subplot(2,2,4); hold on; grid on;
plot(tc,Vxr,'k','LineWidth',1.4); plot(tc,Vxo,'r--','LineWidth',1.4);
ylabel('v_x [m/s]'); title('Velocity X'); xlabel('t [s]');

sgtitle(sprintf('%s | %s | Asym GA', cfg.subject_tag, trial_key));
exportgraphics(fig1, fullfile(results_dir, ...
    sprintf('Asym_GA_opt_%s_%s.png', cfg.subject_tag, trial_key)), ...
    'BackgroundColor', 'white');

%% --- Log -----------------------------------------------------------------
T_log = table(string(mat_file), datetime('now'), string(trial_key), ...
              string(cfg.subject_tag), string(cfg.gender), ...
              k_R, k_L, L0_R, L0_L, m_dyn, ...
              K_R_opt, K_L_opt, L0_R_opt, L0_L_opt, f_best, ...
              MSE_y, MSE_x, MSE_vy, MSE_vx, ...
    'VariableNames', { ...
        'Cut_Filename','Timestamp','Trial','Subject','Gender', ...
        'k_R_ref','k_L_ref','L0_R_ref','L0_L_ref','Mass_kg', ...
        'K_R_opt','K_L_opt','L0_R_opt','L0_L_opt','Cost_GA', ...
        'MSE_Y','MSE_X','MSE_Vy','MSE_Vx'});
log_to_excel(log_file, T_log);
fprintf('Log updated: %s\n', log_file);

%% =========================================================================
function C = select_struct(S)
if isfield(S,'Segment'),     C = S.Segment;
elseif isfield(S,'Schnitt'), C = S.Schnitt;
else, error('No Segment or Schnitt field.'); end
end
