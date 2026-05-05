function q = read_motionFile(fname, nr)
% READ_MOTIONFILE  Read a SIMM / OpenSim .mot or .sto file.
%
%   q = read_motionFile(fname)
%   q = read_motionFile(fname, nr)   (nr is accepted but unused – legacy arg)
%
%   Output struct fields
%   --------------------
%   q.labels  – cell array of column header strings
%   q.data    – [nRows x nCols] numeric matrix (col 1 is time)
%   q.nr      – number of data rows
%   q.nc      – number of data columns
%
%   Original: ASA 12/03, modified by Eran Guendelman 09/06.

fid = fopen(fname, 'r');
if fid == -1
    error('read_motionFile: cannot open ''%s''.', fname);
end

q.nr = 0;
q.nc = 0;

nextline = fgetl(fid);
while ~strncmpi(nextline, 'endheader', length('endheader'))
    if strncmpi(nextline, 'datacolumns', length('datacolumns'))
        q.nc = str2num(nextline(find(nextline==' ',1)+1:end)); %#ok<ST2NM>
    elseif strncmpi(nextline, 'datarows', length('datarows'))
        q.nr = str2num(nextline(find(nextline==' ',1)+1:end)); %#ok<ST2NM>
    elseif strncmpi(nextline, 'nColumns', length('nColumns'))
        q.nc = str2num(nextline(find(nextline=='=',1)+1:end)); %#ok<ST2NM>
    elseif strncmpi(nextline, 'nRows', length('nRows'))
        q.nr = str2num(nextline(find(nextline=='=',1)+1:end)); %#ok<ST2NM>
    end
    nextline = fgetl(fid);
end

% Column labels line (skip blank lines)
nextline = fgetl(fid);
if all(isspace(nextline))
    nextline = fgetl(fid);
end

q.labels = cell(1, q.nc);
for j = 1:q.nc
    [q.labels{j}, nextline] = strtok(nextline); %#ok<STTOK>
end

q.data = fscanf(fid, '%f', [q.nc, q.nr])';
fclose(fid);
end
