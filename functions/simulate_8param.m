function [t_sim, q_sim] = simulate_8param(mdl, q0, t0, t_switch, t_final)
% SIMULATE_8PARAM  Two-phase (flexion → extension) ODE45 simulation.
%
%   [t_sim, q_sim] = simulate_8param(mdl, q0, t0, t_switch, t_final)
%
%   Phase 1 – Flexion  : integrated from t0       to t_switch
%   Phase 2 – Extension: integrated from t_switch  to t_final
%
%   The state at the end of Phase 1 is the initial condition for Phase 2.
%   This models the leg spring behaviour change at the deepest squat point.
%
%   Parameters
%   ----------
%   mdl      – model struct (m, g, xf, KL_flex, KR_flex, L0_L_flex, L0_R_flex,
%                                     KL_ext,  KR_ext,  L0_L_ext,  L0_R_ext)
%   q0       – initial state [x0; y0; vx0; vy0]
%   t0       – simulation start time (s)
%   t_switch – phase switch time = time of deepest point (s)
%   t_final  – simulation end time (s)
%
%   Returns
%   -------
%   t_sim  (Nx1) – time vector
%   q_sim  (Nx4) – state matrix [x, y, vx, vy]

ode_opts = odeset('RelTol', 1e-6, 'AbsTol', 1e-8);

%% Phase 1: Flexion
[t1, q1] = ode45(@(t,q) eom_8param(t, q, mdl, 'flex'), ...
                 [t0, t_switch], q0, ode_opts);

q_switch = q1(end, :).';   % state at switch point

%% Phase 2: Extension (only if time window is non-trivial)
if t_switch < t_final
    [t2, q2] = ode45(@(t,q) eom_8param(t, q, mdl, 'ext'), ...
                     [t_switch, t_final], q_switch, ode_opts);

    % Concatenate, removing duplicate switch-point row
    t_sim = [t1;          t2(2:end)];
    q_sim = [q1;          q2(2:end, :)];
else
    % Segment contains only flexion (switch == end)
    t_sim = t1;
    q_sim = q1;
end

if any(~isfinite(q_sim(:)))
    error('simulate_8param: integration produced non-finite values.');
end
end
