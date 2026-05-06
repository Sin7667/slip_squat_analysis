%% =========================================================================
%  simulate_forward.m
%  Forward simulation and visual validation of fitted SLIP parameters.
%
%  Supported model types
%  ---------------------
%  'symmetric'  – K, L0 same for both legs (2 parameters)
%  'asymmetric' – K_R/L, L0_R/L independent  (4 parameters)
%  '8param'     – flex/ext phases × left/right legs (8 parameters)
%
%  HOW TO USE
%  ----------
%  1. Set subject_id, trial_key, mat_file, and model_type.
%  2. Either set use_log = true (reads latest result from log file)
%     or fill in the manual parameter fields for your chosen model_type.
%  3. Set run_animation = true to open the animation window.
%  4. Run.
%% =========================================================================

clc; clear; close all;

%% --- USER SETTINGS -------------------------------------------------------
subject_id = 14;
trial_key  = 'E1';
mat_file   = 'Segment_S14_E1_10.642_14.333.mat';
model_type = 'symmetric';   % 'symmetric' | 'asymmetric' | '8param'

% === Parameter source =====================================================
use_log = false;   % true  → read latest result from optimisation log
                   % false → use manual parameters below

% --- Manual parameters (used when use_log = false) ------------------------
% symmetric  → K_manual (scalar), L0_manual (scalar)
K_manual  = 128;    % N/m
L0_manual = 3.1;    % m

% asymmetric → K_manual = [K_R, K_L], L0_manual = [L0_R, L0_L]
% K_manual  = [200, 180];
% L0_manual = [1.2, 1.25];

% 8param     → flex_manual and ext_manual each [KL, KR, L0_L, L0_R]
flex_manual = [100, 100, 1.2, 1.2];   % [KL_flex, KR_flex, L0_L_flex, L0_R_flex]
ext_manual  = [200, 200, 1.0, 1.0];   % [KL_ext,  KR_ext,  L0_L_ext,  L0_R_ext]

% === Animation ============================================================
run_animation = true;    % open animation window
show_forces   = true;    % draw spring force arrows in animation
save_mp4      = false;
save_gif      = false;
%% -------------------------------------------------------------------------

addpath(fullfile(fileparts(mfilename('fullpath')), 'config'));
addpath(fullfile(fileparts(mfilename('fullpath')), 'functions'));
cfg = get_subject_config(subject_id);

if ~isfile(mat_file), error('Segment file not found: %s', mat_file); end
S = load(mat_file);
C = select_struct(S);

%% --- Load parameters from optimisation log (optional) -------------------
if use_log
    switch model_type
        case 'symmetric'
            log_file = cfg.log_file_sym;
        case 'asymmetric'
            log_file = cfg.log_file_asym;
        case '8param'
            log_file = [cfg.subject_tag '_Log_8Param.xlsx'];
        otherwise
            error('Unknown model_type: %s', model_type);
    end

    if ~isfile(log_file)
        error('Log file not found: %s\nRun the optimiser first.', log_file);
    end
    T = readtable(log_file, 'VariableNamingRule', 'preserve');
    row_idx = find(strcmp(T.Cut_Filename, mat_file), 1, 'last');
    if isempty(row_idx)
        error('Segment not found in log file: %s', log_file);
    end

    switch model_type
        case 'symmetric'
            K_manual  = T.K_opt_Nm(row_idx);
            L0_manual = T.L0_opt_m(row_idx);
        case 'asymmetric'
            K_manual  = [T.K_R_opt(row_idx), T.K_L_opt(row_idx)];
            L0_manual = [T.L0_R_opt(row_idx), T.L0_L_opt(row_idx)];
        case '8param'
            flex_manual = [T.KL_flex_opt(row_idx), T.KR_flex_opt(row_idx), ...
                           T.L0_L_flex_opt(row_idx), T.L0_R_flex_opt(row_idx)];
            ext_manual  = [T.KL_ext_opt(row_idx),  T.KR_ext_opt(row_idx), ...
                           T.L0_L_ext_opt(row_idx), T.L0_R_ext_opt(row_idx)];
    end
    fprintf('Parameters loaded from log: %s  (row %d)\n', log_file, row_idx);
end

%% --- Human struct --------------------------------------------------------
XR    = C.XFootRight(1);  XL    = C.XFootLeft(1);
x_mid = 0.5*(XR+XL);      xFoot = 0.5*abs(XR-XL);

Human.time  = C.time_rel(:);
Human.x_rel = C.COMX(:) - x_mid;
Human.y     = C.COMY(:);
Human.vx    = C.Vx(:);
Human.vy    = C.Vy(:);

%% --- Body mass -----------------------------------------------------------
mdl.g  = 9.81;
mdl.xf = xFoot;

param_file = cfg.param_file_2p;
if isfile(param_file)
    Tab = readtable(param_file, 'VariableNamingRule', 'preserve');
    row = find(strcmp(Tab.Cut_Filename, mat_file), 1);
    if ~isempty(row) && isfinite(Tab.Mass_Dyn_kg(row))
        mdl.m = Tab.Mass_Dyn_kg(row);
    else
        mdl.m = 70;
        warning('Mass not found in parameter table – using default 70 kg.');
    end
else
    mdl.m = 70;
    warning('Parameter file not found – using default 70 kg.');
end

%% --- Build model struct & run simulation ---------------------------------
q0      = [Human.x_rel(1), Human.y(1), Human.vx(1), Human.vy(1)];
sim_dur = Human.time(end) - Human.time(1);
t0_sim  = Human.time(1);
t_final = Human.time(end);
t_switch = NaN;   % only used for 8param

switch model_type

    case 'symmetric'
        mdl.K  = K_manual(1);
        mdl.L0 = L0_manual(1);
        fprintf('Symmetric:  K=%.2f N/m  L0=%.3f m\n', mdl.K, mdl.L0);
        [t_sim, q_sim] = simulate_slip(mdl, q0, sim_dur, 'symmetric');

    case 'asymmetric'
        mdl.K_R  = K_manual(1);    mdl.L0_R = L0_manual(1);
        mdl.K_L  = K_manual(end);  mdl.L0_L = L0_manual(end);
        fprintf('Asymmetric:  K_R=%.2f  K_L=%.2f  L0_R=%.3f  L0_L=%.3f\n', ...
                mdl.K_R, mdl.K_L, mdl.L0_R, mdl.L0_L);
        [t_sim, q_sim] = simulate_slip(mdl, q0, sim_dur, 'asymmetric');

    case '8param'
        mdl.KL_flex   = flex_manual(1);  mdl.KR_flex   = flex_manual(2);
        mdl.L0_L_flex = flex_manual(3);  mdl.L0_R_flex = flex_manual(4);
        mdl.KL_ext    = ext_manual(1);   mdl.KR_ext    = ext_manual(2);
        mdl.L0_L_ext  = ext_manual(3);   mdl.L0_R_ext  = ext_manual(4);

        % Phase switch: deepest measured point
        [~, idx_sw] = min(Human.y);
        t_switch = Human.time(idx_sw);
        fprintf('8-Param (2-phase):\n');
        fprintf('  FLEX: KL=%.2f  KR=%.2f  L0_L=%.3f  L0_R=%.3f\n', ...
                mdl.KL_flex, mdl.KR_flex, mdl.L0_L_flex, mdl.L0_R_flex);
        fprintf('  EXT : KL=%.2f  KR=%.2f  L0_L=%.3f  L0_R=%.3f\n', ...
                mdl.KL_ext, mdl.KR_ext, mdl.L0_L_ext, mdl.L0_R_ext);
        fprintf('  Switch: %.4f s (index %d)\n', t_switch, idx_sw);
        [t_sim, q_sim] = simulate_8param(mdl, q0, t0_sim, t_switch, t_final);

    otherwise
        error('Unknown model_type: ''%s''. Use ''symmetric'', ''asymmetric'', or ''8param''.', model_type);
end

%% --- Common time grid & interpolation ------------------------------------
dt  = max(1e-3, median(diff(Human.time)));
tc0 = max(t_sim(1),   Human.time(1));
tc1 = min(t_sim(end), Human.time(end));
tc  = (tc0:dt:tc1).';

Xs  = interp1(t_sim, q_sim(:,1), tc);  Ys  = interp1(t_sim, q_sim(:,2), tc);
Vxs = interp1(t_sim, q_sim(:,3), tc);  Vys = interp1(t_sim, q_sim(:,4), tc);
Xr  = interp1(Human.time, Human.x_rel, tc);
Yr  = interp1(Human.time, Human.y,     tc);
Vxr = interp1(Human.time, Human.vx,    tc);
Vyr = interp1(Human.time, Human.vy,    tc);

MSE_y  = mean((Yr-Ys).^2, 'omitnan');
MSE_x  = mean((Xr-Xs).^2, 'omitnan');
RMSE_y = sqrt(MSE_y);
RMSE_x = sqrt(MSE_x);
fprintf('RMSE_Y = %.4f m  |  RMSE_X = %.4f m\n', RMSE_y, RMSE_x);

%% --- Comparison plot -----------------------------------------------------
switch model_type
    case 'symmetric'
        param_str = sprintf('K=%.0f N/m  L0=%.3f m', mdl.K, mdl.L0);
    case 'asymmetric'
        param_str = sprintf('K_R=%.0f  K_L=%.0f  L0_R=%.3f  L0_L=%.3f', ...
                            mdl.K_R, mdl.K_L, mdl.L0_R, mdl.L0_L);
    case '8param'
        param_str = sprintf('FLEX KL=%.0f KR=%.0f | EXT KL=%.0f KR=%.0f', ...
                            mdl.KL_flex, mdl.KR_flex, mdl.KL_ext, mdl.KR_ext);
end

fig = figure('Color', 'w', 'Name', sprintf('Forward Simulation – %s', model_type));

subplot(2,2,1); hold on; grid on;
plot(tc, Yr, 'b',   'LineWidth', 1.5);
plot(tc, Ys, 'r--', 'LineWidth', 1.5);
if ~isnan(t_switch)
    xline(t_switch - t0_sim, ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 1, 'Label', 'switch');
end
ylabel('y [m]');  title('COM Y');  xlabel('t [s]');
legend('Measured', 'Simulated', 'Location', 'best');

subplot(2,2,2); hold on; grid on;
plot(tc, Xr, 'b',   'LineWidth', 1.5);
plot(tc, Xs, 'r--', 'LineWidth', 1.5);
if ~isnan(t_switch)
    xline(t_switch - t0_sim, ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 1);
end
ylabel('x_{rel} [m]');  title('COM X');  xlabel('t [s]');

subplot(2,2,3); hold on; grid on;
plot(tc, Vyr, 'b',   'LineWidth', 1.5);
plot(tc, Vys, 'r--', 'LineWidth', 1.5);
if ~isnan(t_switch)
    xline(t_switch - t0_sim, ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 1);
end
ylabel('v_y [m/s]');  title('Velocity Y');  xlabel('t [s]');

subplot(2,2,4); hold on; grid on;
plot(tc, Vxr, 'b',   'LineWidth', 1.5);
plot(tc, Vxs, 'r--', 'LineWidth', 1.5);
if ~isnan(t_switch)
    xline(t_switch - t0_sim, ':', 'Color', [0.5 0.5 0.5], 'LineWidth', 1);
end
ylabel('v_x [m/s]');  title('Velocity X');  xlabel('t [s]');

sgtitle(sprintf('%s | %s | %s\n%s | RMSE_Y=%.4f m', ...
        cfg.subject_tag, trial_key, model_type, param_str, RMSE_y), ...
        'FontSize', 10);

%% --- Animation -----------------------------------------------------------
if run_animation
    animate_squat_com(t_sim, q_sim, mdl, ...
        't_real',      Human.time, ...
        'x_real',      Human.x_rel, ...
        'y_real',      Human.y, ...
        'show_forces', show_forces, ...
        'force_scale', 0.002, ...
        't_switch',    t_switch, ...
        'saveMP4',     save_mp4, ...
        'saveGIF',     save_gif);
end

%% =========================================================================
function C = select_struct(S)
if isfield(S, 'Segment'),     C = S.Segment;
elseif isfield(S, 'Schnitt'), C = S.Schnitt;
else, error('No Segment or Schnitt field.'); end
end
