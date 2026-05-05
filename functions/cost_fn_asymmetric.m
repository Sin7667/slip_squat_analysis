function cost = cost_fn_asymmetric(params, Human, mdl, q0, sim_dur)
% COST_FN_ASYMMETRIC  Weighted MSE cost for the asymmetric SLIP optimiser.
%
%   cost = cost_fn_asymmetric(params, Human, mdl, q0, sim_dur)
%
%   Parameters
%   ----------
%   params  – [K_R, K_L, L0_R, L0_L]  (right/left stiffness and rest length)
%   Human   – measured kinematics struct (same fields as cost_fn_symmetric)
%   mdl     – base model struct (m, g, xf) – spring values set internally
%   q0      – initial state [x0, y0, vx0, vy0]
%   sim_dur – simulation duration (s)

mdl.K_R  = params(1);
mdl.K_L  = params(2);
mdl.L0_R = params(3);
mdl.L0_L = params(4);

try
    [ts, qs] = ode45(@(t,q) eom_asymmetric(t, q, mdl), [0, sim_dur], q0);
catch
    cost = 1e9;  return;
end
if isempty(qs) || any(~isfinite(qs(:)))
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

cost = 50*MSEx + 100*MSEy + 10*MSEvx + 10*MSEvy;
end
