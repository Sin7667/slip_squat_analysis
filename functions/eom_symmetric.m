function dqdt = eom_symmetric(~, q, mdl)
% EOM_SYMMETRIC  Equations of motion for a 2D symmetric two-legged SLIP.
%
%   State vector  q = [x; y; x_dot; y_dot]
%     x     – COM horizontal position relative to stance midpoint (m)
%     y     – COM vertical position (m)
%     x_dot – horizontal velocity (m/s)
%     y_dot – vertical velocity (m/s)
%
%   Model struct  mdl
%     mdl.m    – body mass (kg)
%     mdl.g    – gravitational acceleration (m/s^2), typically 9.81
%     mdl.xf   – half stance width (m); right foot at +xf, left at -xf
%     mdl.K    – leg spring stiffness, same for both legs (N/m)
%     mdl.L0   – leg spring rest length, same for both legs (m)
%
%   Note: horizontal acceleration is set to zero (x_dot clamped).
%   This is consistent with the original implementation and valid for
%   symmetric squats where lateral COM movement is negligible.

x  = q(1);
y  = q(2);
xd = q(3);
yd = q(4);
xf = mdl.xf;

l_R = hypot(x - xf, y);   % right leg length  (foot at +xf)
l_L = hypot(x + xf, y);   % left  leg length  (foot at -xf)

F_R = mdl.K * max(0, mdl.L0 - l_R);   % right spring force (compression only)
F_L = mdl.K * max(0, mdl.L0 - l_L);   % left  spring force

uy_R = y / l_R;   % vertical unit-vector component, right leg
uy_L = y / l_L;   % vertical unit-vector component, left leg

xdd = 0;
ydd = (F_R * uy_R + F_L * uy_L) / mdl.m - mdl.g;

dqdt = [xd; yd; xdd; ydd];
end
