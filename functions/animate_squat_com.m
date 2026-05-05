function animate_squat_com(t, q, mdl, varargin)
% ANIMATE_SQUAT_COM  Animate the 2D squat SLIP model with optional overlay.
%
%   animate_squat_com(t, q, mdl)
%   animate_squat_com(t, q, mdl, 'Name', Value, ...)
%
%   Required inputs
%   ---------------
%   t         – simulation time vector (s)
%   q         – [N x 4] state matrix: [x_rel, y, vx, vy]
%   mdl       – model struct with at least mdl.xf (half stance width)
%                 For force arrows: mdl.K_R, mdl.L0_R, mdl.K_L, mdl.L0_L
%                 (or mdl.K and mdl.L0 for symmetric models)
%
%   Optional name-value pairs
%   -------------------------
%   't_real'     – measured time vector
%   'x_real'     – measured COM x (relative)
%   'y_real'     – measured COM y
%   'show_forces'– true/false: draw spring force arrows (default false)
%   'force_scale'– scalar for arrow length (default 1.0)
%   'speed'      – playback speed multiplier (default 1.0)
%   'trail_sec'  – seconds of COM trail to show (default 0.3)
%   'loop_count' – number of animation loops (default 1)
%   'real_time'  – enable real-time pacing (default true)
%   'saveMP4'    – save as MP4 video (default false)
%   'mp4name'    – video filename (default 'squat_com.mp4')
%   'saveGIF'    – save as GIF (default false)
%   'gifname'    – GIF filename (default 'squat_com.gif')

p = inputParser;
addParameter(p, 't_real',      [],           @(x) isnumeric(x) || isempty(x));
addParameter(p, 'x_real',      [],           @(x) isnumeric(x) || isempty(x));
addParameter(p, 'y_real',      [],           @(x) isnumeric(x) || isempty(x));
addParameter(p, 'show_forces', false,        @islogical);
addParameter(p, 'force_scale', 1.0,          @(x) isnumeric(x) && x > 0);
addParameter(p, 'speed',       1.0,          @(x) isnumeric(x) && x > 0);
addParameter(p, 'trail_sec',   0.3,          @(x) isnumeric(x) && x >= 0);
addParameter(p, 'loop_count',  1,            @(x) isnumeric(x) && x >= 1);
addParameter(p, 'real_time',   true,         @islogical);
addParameter(p, 'saveMP4',     false,        @islogical);
addParameter(p, 'mp4name',     'squat_com.mp4', @(x) ischar(x) || isstring(x));
addParameter(p, 'saveGIF',     false,        @islogical);
addParameter(p, 'gifname',     'squat_com.gif', @(x) ischar(x) || isstring(x));
parse(p, varargin{:});
R = p.Results;

x  = q(:,1);
y  = q(:,2);
xf = mdl.xf;

% Derive spring parameters (symmetric or asymmetric)
if isfield(mdl, 'K')
    K_R = mdl.K;  L0_R = mdl.L0;
    K_L = mdl.K;  L0_L = mdl.L0;
else
    K_R  = mdl.K_R;  L0_R = mdl.L0_R;
    K_L  = mdl.K_L;  L0_L = mdl.L0_L;
end

% Playback raster (~60 fps)
t0_v = t(1);  t1_v = t(end);
dt_play = max(1/60, max(1e-3, median(diff(t))));
t_play  = (t0_v : dt_play : t1_v).';

xi = interp1(t, x, t_play, 'linear', 'extrap');
yi = interp1(t, y, t_play, 'linear', 'extrap');

haveReal = ~isempty(R.t_real) && ~isempty(R.x_real) && ~isempty(R.y_real);
if haveReal
    xr = interp1(R.t_real(:), R.x_real(:), t_play, 'linear', 'extrap');
    yr = interp1(R.t_real(:), R.y_real(:), t_play, 'linear', 'extrap');
end

% Axis limits
margin = 0.1 * max(1, max(abs([xi; xf])));
XLim = [min([xi; -xf]) - margin,  max([xi; xf]) + margin];
YLim = [0, max(yi) + margin];

fig = figure('Color', 'w', 'Name', 'Squat COM Animation');
ax  = axes('Parent', fig);
hold(ax, 'on');  grid(ax, 'on');  box(ax, 'on');  axis(ax, 'equal');
ax.XLim = XLim;  ax.YLim = YLim;
plot(ax, XLim, [0 0], 'k-', 'LineWidth', 1.2);
xline(ax, 0, ':', 'Color', [0.6 0.6 0.6]);
title(ax, 'Squat: COM trajectory and legs');
xlabel(ax, 'x [m]');  ylabel(ax, 'y [m]');

% Foot markers
plot(ax, +xf, 0, 's', 'MarkerSize', 8, 'MarkerFaceColor', [0.1 0.1 0.1], 'MarkerEdgeColor', 'k');
plot(ax, -xf, 0, 's', 'MarkerSize', 8, 'MarkerFaceColor', [0.1 0.1 0.1], 'MarkerEdgeColor', 'k');

% Animated elements
hTrail = animatedline(ax, 'Color', [0 0.447 0.741], 'LineStyle', '-', 'LineWidth', 1.5);
if haveReal
    plot(ax, xr, yr, '-', 'Color', [0.8 0.8 0.9], 'LineWidth', 1.0);
    hTrailR = animatedline(ax, 'Color', [0.3 0.3 0.75], 'LineStyle', '--', 'LineWidth', 1.0);
end
hLegR = plot(ax, [+xf xi(1)], [0 yi(1)], '-', 'LineWidth', 3, 'Color', [0.85 0.33 0.10]);
hLegL = plot(ax, [-xf xi(1)], [0 yi(1)], '-', 'LineWidth', 3, 'Color', [0.47 0.67 0.19]);
hCOM  = plot(ax, xi(1), yi(1), 'o', 'MarkerSize', 8, ...
             'MarkerFaceColor', [0.2 0.6 1], 'MarkerEdgeColor', 'k');

if R.show_forces
    hF_R = quiver(ax, +xf, 0, 0, 0, 'AutoScale', 'off', 'MaxHeadSize', 0.8, ...
                  'LineWidth', 1.2, 'Color', [0.2 0.7 0.2]);
    hF_L = quiver(ax, -xf, 0, 0, 0, 'AutoScale', 'off', 'MaxHeadSize', 0.8, ...
                  'LineWidth', 1.2, 'Color', [0.9 0.4 0.1]);
end

hTxt = text(ax, XLim(1) + 0.02*diff(XLim), YLim(2) - 0.06*diff(YLim), ...
            sprintf('t = %.3f s', t_play(1)), 'FontName', 'Courier', 'FontSize', 10);

trailN = max(1, round(R.trail_sec / dt_play));
try
    set(hTrail, 'MaximumNumPoints', trailN);
    if haveReal, set(hTrailR, 'MaximumNumPoints', trailN); end
catch; end

% Video / GIF setup
vidObj = [];
if R.saveMP4
    try
        vidObj = VideoWriter(char(R.mp4name), 'MPEG-4');
    catch
        vidObj = VideoWriter([char(R.mp4name(1:end-4)) '.avi'], 'Motion JPEG AVI');
    end
    vidObj.FrameRate = max(1, round(1/dt_play));
    open(vidObj);
end

for rep = 1:round(R.loop_count)
    t_wall = tic;
    for k = 1:numel(t_play)
        set(hLegR, 'XData', [+xf xi(k)], 'YData', [0 yi(k)]);
        set(hLegL, 'XData', [-xf xi(k)], 'YData', [0 yi(k)]);
        set(hCOM,  'XData', xi(k),        'YData', yi(k));
        addpoints(hTrail, xi(k), yi(k));
        if haveReal, addpoints(hTrailR, xr(k), yr(k)); end
        set(hTxt, 'String', sprintf('t = %.3f s', t_play(k)));

        if R.show_forces
            scale = R.force_scale / max(mdl.m, 1);

            dx_R = xi(k) - xf;  dy_R = yi(k);
            l_R  = hypot(dx_R, dy_R);  if l_R < 1e-12, l_R = 1e-12; end
            F_R  = K_R * max(0, L0_R - l_R);

            dx_L = xi(k) + xf;  dy_L = yi(k);
            l_L  = hypot(dx_L, dy_L);  if l_L < 1e-12, l_L = 1e-12; end
            F_L  = K_L * max(0, L0_L - l_L);

            set(hF_R, 'XData', +xf, 'YData', 0, ...
                      'UData', F_R*dx_R/l_R*scale, 'VData', F_R*dy_R/l_R*scale);
            set(hF_L, 'XData', -xf, 'YData', 0, ...
                      'UData', F_L*dx_L/l_L*scale, 'VData', F_L*dy_L/l_L*scale);
        end

        drawnow;

        if ~isempty(vidObj), writeVideo(vidObj, getframe(fig)); end
        if R.saveGIF
            [A, map] = frame2im(getframe(fig));
            [Ai, cm] = rgb2ind(A, 256);
            if rep == 1 && k == 1
                imwrite(Ai, cm, char(R.gifname), 'gif', 'Loopcount', inf, 'DelayTime', dt_play);
            else
                imwrite(Ai, cm, char(R.gifname), 'gif', 'WriteMode', 'append', 'DelayTime', dt_play);
            end
        end

        if R.real_time && ~R.saveMP4 && ~R.saveGIF
            elapsed = toc(t_wall);
            if elapsed < dt_play / R.speed
                pause(dt_play / R.speed - elapsed);
            end
            t_wall = tic;
        end
    end
end

if ~isempty(vidObj)
    close(vidObj);
    fprintf('Video saved: %s\n', vidObj.Filename);
end
if R.saveGIF
    fprintf('GIF saved: %s\n', char(R.gifname));
end
end
