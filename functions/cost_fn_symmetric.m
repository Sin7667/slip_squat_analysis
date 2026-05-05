function cost = cost_fn_symmetric(K, L0, Human, mdl, q0, sim_dur)
% COST_FN_SYMMETRIC  Weighted MSE cost for the symmetric SLIP optimiser.
%
%   cost = cost_fn_symmetric(K, L0, Human, mdl, q0, sim_dur)
%
%   Parameters
%   ----------
%   K, L0     – candidate spring stiffness (N/m) and rest length (m)
%   Human     – struct with measured kinematics:
%                 .time   relative time vector (s)
%                 .x_rel  COM x relative to foot midpoint (m)
%                 .y      COM y (m)
%                 .vx     COM x velocity (m/s)
%                 .vy     COM y velocity (m/s)
%   mdl       – model struct (m, g, xf) – K and L0 are set internally
%   q0        – initial state [x0, y0, vx0, vy0]
%   sim_dur   – simulation duration (s)
%
%   Cost weights
%   ------------
%   Position y   : weight 100  (primary fitting target)
%   Position x   : weight  50
%   Velocity vy  : weight   0.1
%   Velocity vx  : weight  10

mdl.K  = K;
mdl.L0 = L0;

% Initial-state support check: penalise near-free-fall starts
x0 = q0(1);  y0 = q0(2);  xf = mdl.xf;
l_R0 = hypot(x0 - xf, y0);
l_L0 = hypot(x0 + xf, y0);
Fy0  = mdl.K * max(0, mdl.L0 - l_R0) * (y0/l_R0) + ...
       mdl.K * max(0, mdl.L0 - l_L0) * (y0/l_L0);
if Fy0 < 0.1 * mdl.m * mdl.g
    cost = 1e9 + (mdl.m * mdl.g - Fy0)^2;
    return;
end
pen_start = max(0, 0.8*mdl.m*mdl.g - Fy0)^2;

try
    [ts, qs] = ode45(@(t,q) eom_symmetric(t, q, mdl), [0, sim_dur], q0);
catch
    cost = 1e9;  return;
end
if any(~isfinite(qs(:)))
    cost = 1e9;  return;
end

dt = max(1e-3, median(diff(Human.time)));
t0 = max(ts(1),  Human.time(1));
t1 = min(ts(end), Human.time(end));
if t1 <= t0,  cost = 1e9;  return;  end
tc = (t0:dt:t1).';

Xs  = interp1(ts, qs(:,1), tc, 'linear');
Ys  = interp1(ts, qs(:,2), tc, 'linear');
Vxs = interp1(ts, qs(:,3), tc, 'linear');
Vys = interp1(ts, qs(:,4), tc, 'linear');

Xr  = interp1(Human.time, Human.x_rel, tc, 'linear');
Yr  = interp1(Human.time, Human.y,     tc, 'linear');
Vxr = interp1(Human.time, Human.vx,    tc, 'linear');
Vyr = interp1(Human.time, Human.vy,    tc, 'linear');

MSEx  = mean((Xr  - Xs ).^2, 'omitnan');
MSEy  = mean((Yr  - Ys ).^2, 'omitnan');
MSEvx = mean((Vxr - Vxs).^2, 'omitnan');
MSEvy = mean((Vyr - Vys).^2, 'omitnan');

cost = 50*MSEx + 100*MSEy + 10*MSEvx + 0.1*MSEvy + pen_start;
end
