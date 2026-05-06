%% =========================================================================
%  optimize_8param_GA.m
%  Asymmetric 8-parameter SLIP optimisation using Genetic Algorithm + fmincon.
%
%  MODEL:  separate flexion / extension phase, asymmetric left / right legs
%  8 parameters: p = [KL_flex, KR_flex, L0_L_flex, L0_R_flex,
%                      KL_ext,  KR_ext,  L0_L_ext,  L0_R_ext]
%
%  HOW TO USE
%  ----------
%  1. Run curve_fit_4param.m first (generates <param_file_4p>).
%  2. Set subject_id, trial_key, and mat_file below.
%  3. Run.
%
%  OUTPUTS
%  -------
%  <log_file_8p>   – optimisation results appended to Excel
%  Results_<trial>/ – comparison plot and run data .mat
%% =========================================================================

clc; clear; close all;

%% --- USER SETTINGS -------------------------------------------------------
subject_id = 14;
trial_key  = 'E3';
mat_file   = 'Segment_S14_E3_53.877_56.691.mat';
%% -------------------------------------------------------------------------

addpath(fullfile(fileparts(mfilename('fullpath')), 'config'));
addpath(fullfile(fileparts(mfilename('fullpath')), 'functions'));
cfg = get_subject_config(subject_id);

param_file_4p = cfg.param_file_4p;     % 4-param Excel for bounds & refs
param_file_2p = cfg.param_file_2p;     % 2-param Excel for mass (fallback)
log_file      = [cfg.subject_tag '_Log_8Param.xlsx'];

if ~isfile(mat_file),      error('Segment file not found: %s', mat_file);      end
if ~isfile(param_file_4p), error('4-param table not found: %s', param_file_4p); end

%% --- Load data -----------------------------------------------------------
S    = load(mat_file);
C    = select_struct(S);
Tab4 = readtable(param_file_4p, 'VariableNamingRule', 'preserve');

%% --- Reference parameters for this segment ------------------------------
row_idx = find(strcmp(Tab4.Cut_Filename, mat_file), 1);
if isempty(row_idx)
    error('Segment ''%s'' not found in %s.\nRun curve_fit_4param.m first.', ...
          mat_file, param_file_4p);
end

KL_flex_ref  = abs(Tab4.k_L_Flex(row_idx));
L0_L_flex_ref= abs(Tab4.L0_L_Flex(row_idx));
KL_ext_ref   = abs(Tab4.k_L_Ext(row_idx));
L0_L_ext_ref = abs(Tab4.L0_L_Ext(row_idx));
KR_flex_ref  = abs(Tab4.k_R_Flex(row_idx));
L0_R_flex_ref= abs(Tab4.L0_R_Flex(row_idx));
KR_ext_ref   = abs(Tab4.k_R_Ext(row_idx));
L0_R_ext_ref = abs(Tab4.L0_R_Ext(row_idx));
m_dyn        = Tab4.Mass_Dyn_kg(row_idx);

% Fallback: read mass from 2-param Excel if NaN
if isnan(m_dyn) && isfile(param_file_2p)
    Tab2    = readtable(param_file_2p, 'VariableNamingRule', 'preserve');
    row2    = find(strcmp(Tab2.Cut_Filename, mat_file), 1);
    if ~isempty(row2), m_dyn = Tab2.Mass_Dyn_kg(row2); end
end
if isnan(m_dyn), error('Could not determine body mass for this segment.'); end

fprintf('Reference (4-param fit):\n');
fprintf('  FLEX: KL=%.1f  L0_L=%.3f  |  KR=%.1f  L0_R=%.3f\n', ...
        KL_flex_ref, L0_L_flex_ref, KR_flex_ref, L0_R_flex_ref);
fprintf('  EXT : KL=%.1f  L0_L=%.3f  |  KR=%.1f  L0_R=%.3f\n', ...
        KL_ext_ref, L0_L_ext_ref, KR_ext_ref, L0_R_ext_ref);
fprintf('  Mass = %.1f kg\n', m_dyn);

%% --- Optimisation bounds from 4-param statistics ------------------------
mask = contains(Tab4.Cut_Filename, trial_key);
if ~any(mask)
    error('No rows found for trial ''%s'' in %s.', trial_key, param_file_4p);
end

kL_flex  = abs(Tab4.k_L_Flex(mask));
kR_flex  = abs(Tab4.k_R_Flex(mask));
L0L_flex = abs(Tab4.L0_L_Flex(mask));
L0R_flex = abs(Tab4.L0_R_Flex(mask));
kL_ext   = abs(Tab4.k_L_Ext(mask));
kR_ext   = abs(Tab4.k_R_Ext(mask));
L0L_ext  = abs(Tab4.L0_L_Ext(mask));
L0R_ext  = abs(Tab4.L0_R_Ext(mask));

% Remove NaN/Inf
kL_flex  = kL_flex(isfinite(kL_flex));   kR_flex  = kR_flex(isfinite(kR_flex));
L0L_flex = L0L_flex(isfinite(L0L_flex)); L0R_flex = L0R_flex(isfinite(L0R_flex));
kL_ext   = kL_ext(isfinite(kL_ext));     kR_ext   = kR_ext(isfinite(kR_ext));
L0L_ext  = L0L_ext(isfinite(L0L_ext));   L0R_ext  = L0R_ext(isfinite(L0R_ext));

if any(strcmp(trial_key, {'E1', 'E2'}))
    % Tight bounds: p10–p90 across both legs
    Kflex_low  = min(prctile(kL_flex,  10), prctile(kR_flex,  10));
    Kflex_high = max(prctile(kL_flex,  90), prctile(kR_flex,  90));
    L0flex_low = min(prctile(L0L_flex, 10), prctile(L0R_flex, 10));
    L0flex_high= max(prctile(L0L_flex, 90), prctile(L0R_flex, 90));

    Kext_low   = min(prctile(kL_ext,   10), prctile(kR_ext,   10));
    Kext_high  = max(prctile(kL_ext,   90), prctile(kR_ext,   90));
    L0ext_low  = min(prctile(L0L_ext,  10), prctile(L0R_ext,  10));
    L0ext_high = max(prctile(L0L_ext,  90), prctile(L0R_ext,  90));
else
    % Wide bounds: data-driven with padding
    padK  = 0.30;   padL0 = 0.05;
    Kflex_low  = (1-padK) * min([kL_flex;  kR_flex]);
    Kflex_high = (1+padK) * max([kL_flex;  kR_flex]);
    L0flex_low = max(0.01, min([L0L_flex; L0R_flex]) - padL0);
    L0flex_high=           max([L0L_flex; L0R_flex]) + padL0;

    Kext_low   = (1-padK) * min([kL_ext;   kR_ext]);
    Kext_high  = (1+padK) * max([kL_ext;   kR_ext]);
    L0ext_low  = max(0.01, min([L0L_ext;  L0R_ext]) - padL0);
    L0ext_high =           max([L0L_ext;  L0R_ext]) + padL0;
end

% Safety floor
if Kflex_low  >= Kflex_high,  Kflex_low  = Kflex_low *0.8; Kflex_high  = Kflex_high *1.2; end
if Kext_low   >= Kext_high,   Kext_low   = Kext_low  *0.8; Kext_high   = Kext_high  *1.2; end
if L0flex_low >= L0flex_high, L0flex_low = L0flex_low*0.9; L0flex_high = L0flex_high*1.1; end
if L0ext_low  >= L0ext_high,  L0ext_low  = L0ext_low *0.9; L0ext_high  = L0ext_high *1.1; end

% p = [KL_flex, KR_flex, L0_L_flex, L0_R_flex, KL_ext, KR_ext, L0_L_ext, L0_R_ext]
lb = [Kflex_low;  Kflex_low;  L0flex_low;  L0flex_low;  Kext_low;  Kext_low;  L0ext_low;  L0ext_low];
ub = [Kflex_high; Kflex_high; L0flex_high; L0flex_high; Kext_high; Kext_high; L0ext_high; L0ext_high];

fprintf('\nBounds (%s):\n', trial_key);
fprintf('  FLEX: K [%.1f – %.1f]  L0 [%.3f – %.3f]\n', Kflex_low, Kflex_high, L0flex_low, L0flex_high);
fprintf('  EXT : K [%.1f – %.1f]  L0 [%.3f – %.3f]\n', Kext_low,  Kext_high,  L0ext_low,  L0ext_high);

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

%% --- Phase switch: deepest point = flexion/extension boundary -----------
[~, idx_switch] = min(Human.y);
t_switch = Human.time(idx_switch);
t0_sim   = Human.time(1);
t_final  = Human.time(end);
sim_dur  = t_final - t0_sim;

fprintf('\nPhase switch (deepest point): t = %.4f s  (index %d / %d)\n', ...
        t_switch, idx_switch, numel(Human.time));
if idx_switch == numel(Human.time)
    warning('Deepest point is the last sample – segment contains only flexion!');
end

%% --- Base model struct ---------------------------------------------------
mdl.m  = m_dyn;
mdl.g  = 9.81;
mdl.xf = xFoot;

q0 = [Human.x_rel(1); Human.y(1); Human.vx(1); Human.vy(1)];

%% --- GA optimisation: 8 parameters --------------------------------------
rng(42);
obj = @(p) cost_fn_8param(p, Human, mdl, q0, t0_sim, t_switch, t_final);

ga_opts = optimoptions('ga', ...
    'Display',        'iter', ...
    'PopulationSize', 100, ...
    'MaxGenerations', 200, ...
    'UseParallel',    false, ...
    'PlotFcn',        {@gaplotbestf, @gaplotrange}, ...
    'HybridFcn',      @fmincon);

fprintf('\nStarting GA (8 parameters, 2-phase asymmetric) ...\n');
[p_best, f_best] = ga(obj, 8, [], [], [], [], lb, ub, [], ga_opts);

KL_flex_opt  = p_best(1);  KR_flex_opt  = p_best(2);
L0_L_flex_opt= p_best(3);  L0_R_flex_opt= p_best(4);
KL_ext_opt   = p_best(5);  KR_ext_opt   = p_best(6);
L0_L_ext_opt = p_best(7);  L0_R_ext_opt = p_best(8);

fprintf('\n=== 8-PARAM GA RESULT ===\n');
fprintf('  FLEX: KL=%.2f  KR=%.2f  L0_L=%.3f  L0_R=%.3f\n', ...
        KL_flex_opt, KR_flex_opt, L0_L_flex_opt, L0_R_flex_opt);
fprintf('  EXT : KL=%.2f  KR=%.2f  L0_L=%.3f  L0_R=%.3f\n', ...
        KL_ext_opt, KR_ext_opt, L0_L_ext_opt, L0_R_ext_opt);
fprintf('  Cost = %.6f\n', f_best);

%% --- Forward simulation with optimised parameters -----------------------
mdl_opt             = mdl;
mdl_opt.KL_flex     = KL_flex_opt;   mdl_opt.KR_flex    = KR_flex_opt;
mdl_opt.L0_L_flex   = L0_L_flex_opt; mdl_opt.L0_R_flex  = L0_R_flex_opt;
mdl_opt.KL_ext      = KL_ext_opt;    mdl_opt.KR_ext     = KR_ext_opt;
mdl_opt.L0_L_ext    = L0_L_ext_opt;  mdl_opt.L0_R_ext   = L0_R_ext_opt;

[t_opt, q_opt] = simulate_8param(mdl_opt, q0, t0_sim, t_switch, t_final);

% Common time grid
dt = max(1e-3, median(diff(Human.time)));
t0c= max(t_opt(1),   Human.time(1));
t1c= min(t_opt(end), Human.time(end));
tc = (t0c:dt:t1c).';

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

%% --- Plot: Measured vs Optimised ----------------------------------------
results_dir = fullfile(pwd, ['Results_' trial_key]);
if ~isfolder(results_dir), mkdir(results_dir); end

fig = figure('Color', 'w', 'Name', sprintf('%s %s – 8-Param GA', cfg.subject_tag, trial_key));

% Mark the flex/ext switch time
t_sw_rel = t_switch - t0_sim;   % relative to segment start

subplot(2,2,1); hold on; grid on;
plot(tc, Yr, 'b',   'LineWidth', 1.5);
plot(tc, Yo, 'r--', 'LineWidth', 1.5);
xline(t_sw_rel, ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 1, 'Label', 'switch');
ylabel('y [m]');  title('COM Y');  xlabel('t [s]');
legend('Measured', 'GA opt', 'Location', 'best');

subplot(2,2,2); hold on; grid on;
plot(tc, Xr, 'b',   'LineWidth', 1.5);
plot(tc, Xo, 'r--', 'LineWidth', 1.5);
xline(t_sw_rel, ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 1);
ylabel('x_{rel} [m]');  title('COM X');  xlabel('t [s]');

subplot(2,2,3); hold on; grid on;
plot(tc, Vyr, 'b',   'LineWidth', 1.5);
plot(tc, Vyo, 'r--', 'LineWidth', 1.5);
xline(t_sw_rel, ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 1);
ylabel('v_y [m/s]');  title('Velocity Y');  xlabel('t [s]');

subplot(2,2,4); hold on; grid on;
plot(tc, Vxr, 'b',   'LineWidth', 1.5);
plot(tc, Vxo, 'r--', 'LineWidth', 1.5);
xline(t_sw_rel, ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 1);
ylabel('v_x [m/s]');  title('Velocity X');  xlabel('t [s]');

sgtitle(sprintf('%s | %s | 8-Param GA | RMSE_Y=%.4f m', ...
        cfg.subject_tag, trial_key, RMSE_y));

plot_path = fullfile(results_dir, ...
    sprintf('8Param_GA_%s_%s.png', cfg.subject_tag, trial_key));
exportgraphics(fig, plot_path, 'BackgroundColor', 'white');
fprintf('Plot saved: %s\n', plot_path);

%% --- Save run data -------------------------------------------------------
[~, base_name] = fileparts(mat_file);
run_data = struct( ...
    'subject', cfg.subject_tag, 'trial', trial_key, 'mat_file', mat_file, ...
    'KL_flex_opt', KL_flex_opt, 'KR_flex_opt', KR_flex_opt, ...
    'L0_L_flex_opt', L0_L_flex_opt, 'L0_R_flex_opt', L0_R_flex_opt, ...
    'KL_ext_opt',  KL_ext_opt,  'KR_ext_opt',  KR_ext_opt, ...
    'L0_L_ext_opt',  L0_L_ext_opt,  'L0_R_ext_opt',  L0_R_ext_opt, ...
    't_switch', t_switch, 't_opt', t_opt, 'q_opt', q_opt, ...
    't_common', tc, 'Xr', Xr, 'Yr', Yr, 'Vxr', Vxr, 'Vyr', Vyr, ...
    'Xo', Xo, 'Yo', Yo, 'Vxo', Vxo, 'Vyo', Vyo);
save(fullfile(results_dir, ['RunData_8P_' base_name '.mat']), '-struct', 'run_data');

%% --- Log to Excel --------------------------------------------------------
T_log = table( ...
    string(mat_file), datetime('now'), string(trial_key), ...
    string(cfg.subject_tag), string(cfg.gender), m_dyn, ...
    KL_flex_opt, KR_flex_opt, L0_L_flex_opt, L0_R_flex_opt, ...
    KL_ext_opt,  KR_ext_opt,  L0_L_ext_opt,  L0_R_ext_opt, ...
    f_best, t_switch, ...
    MSE_y, MSE_x, MSE_vy, MSE_vx, RMSE_y, RMSE_x, ...
    Kflex_low, Kflex_high, L0flex_low, L0flex_high, ...
    Kext_low,  Kext_high,  L0ext_low,  L0ext_high, ...
    'VariableNames', { ...
        'Cut_Filename', 'Timestamp', 'Trial', 'Subject', 'Gender', 'Mass_kg', ...
        'KL_flex_opt', 'KR_flex_opt', 'L0_L_flex_opt', 'L0_R_flex_opt', ...
        'KL_ext_opt',  'KR_ext_opt',  'L0_L_ext_opt',  'L0_R_ext_opt', ...
        'Cost_GA', 't_switch', ...
        'MSE_Y', 'MSE_X', 'MSE_Vy', 'MSE_Vx', 'RMSE_Y', 'RMSE_X', ...
        'Kflex_lb', 'Kflex_ub', 'L0flex_lb', 'L0flex_ub', ...
        'Kext_lb',  'Kext_ub',  'L0ext_lb',  'L0ext_ub'});

log_to_excel(log_file, T_log);
fprintf('Log updated: %s\n', log_file);

%% --- Console summary -----------------------------------------------------
fprintf('\n========================================\n');
fprintf('  8-PARAM GA – %s %s\n', cfg.subject_tag, trial_key);
fprintf('========================================\n');
fprintf('  FLEX:  KL=%.2f  KR=%.2f  L0_L=%.3f  L0_R=%.3f\n', ...
        KL_flex_opt, KR_flex_opt, L0_L_flex_opt, L0_R_flex_opt);
fprintf('  EXT :  KL=%.2f  KR=%.2f  L0_L=%.3f  L0_R=%.3f\n', ...
        KL_ext_opt, KR_ext_opt, L0_L_ext_opt, L0_R_ext_opt);
fprintf('  Cost = %.6f\n', f_best);
fprintf('  RMSE_Y = %.4f m | RMSE_X = %.4f m\n', RMSE_y, RMSE_x);
fprintf('  Switch: %.4f s | Output: %s\n', t_switch, results_dir);
fprintf('========================================\n\n');

%% =========================================================================
function C = select_struct(S)
if isfield(S, 'Segment'),       C = S.Segment;
elseif isfield(S, 'Schnitt'),   C = S.Schnitt;
else,  error('No Segment or Schnitt field in loaded file.');
end
end
