function cost = cost_fn_8param(params, Human, mdl, q0, t0, t_switch, t_final)
% COST_FN_8PARAM  Weighted MSE cost for the 8-parameter 2-phase SLIP optimiser.
%
%   cost = cost_fn_8param(params, Human, mdl, q0, t0, t_switch, t_final)
%
%   Parameters
%   ----------
%   params     – [KL_flex, KR_flex, L0_L_flex, L0_R_flex,
%                 KL_ext,  KR_ext,  L0_L_ext,  L0_R_ext]
%   Human      – measured kinematics struct:
%                  .time   (s), .x_rel (m), .y (m), .vx (m/s), .vy (m/s)
%   mdl        – base model struct (m, g, xf) — spring values set internally
%   q0         – initial state [x0; y0; vx0; vy0]
%   t0         – simulation start time (s)
%   t_switch   – flex/ext switch time = deepest point (s)
%   t_final    – simulation end time (s)
%
%   Cost weights
%   ------------
%   Position y   : weight 200  (primary target: vertical COM)
%   Position x   : weight  40
%   Velocity vy  : weight  20
%   Velocity vx  : weight   5

mdl.KL_flex   = params(1);
mdl.KR_flex   = params(2);
mdl.L0_L_flex = params(3);
mdl.L0_R_flex = params(4);
mdl.KL_ext    = params(5);
mdl.KR_ext    = params(6);
mdl.L0_L_ext  = params(7);
mdl.L0_R_ext  = params(8);

try
    [ts, qs] = simulate_8param(mdl, q0, t0, t_switch, t_final);
catch
    cost = 1e9;  return;
end

if isempty(qs) || any(~isfinite(qs(:)))
    cost = 1e9;  return;
end

% Interpolate simulation onto measured time grid
t_meas = Human.time;
Xs  = interp1(ts, qs(:,1), t_meas, 'linear', 'extrap');
Ys  = interp1(ts, qs(:,2), t_meas, 'linear', 'extrap');
Vxs = interp1(ts, qs(:,3), t_meas, 'linear', 'extrap');
Vys = interp1(ts, qs(:,4), t_meas, 'linear', 'extrap');

MSEx  = mean((Human.x_rel - Xs ).^2, 'omitnan');
MSEy  = mean((Human.y     - Ys ).^2, 'omitnan');
MSEvx = mean((Human.vx    - Vxs).^2, 'omitnan');
MSEvy = mean((Human.vy    - Vys).^2, 'omitnan');

cost = 40*MSEx + 200*MSEy + 5*MSEvx + 20*MSEvy;
end
