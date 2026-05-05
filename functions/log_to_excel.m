function log_to_excel(logfile, new_row)
% LOG_TO_EXCEL  Append a table row to an Excel log file (create if absent).
%
%   log_to_excel(logfile, new_row)
%
%   logfile  – path to .xlsx file
%   new_row  – 1-row MATLAB table with the data to append
%
%   If the file already exists and the column layout matches, the new row
%   is appended.  If columns differ, a timestamped backup is written
%   instead so existing data is never lost.

if isfile(logfile)
    try
        old = readtable(logfile, 'VariableNamingRule', 'preserve');
        if width(old) == width(new_row)
            combined = [old; new_row];
            writetable(combined, logfile);
        else
            backup = [logfile(1:end-5) '_backup_' ...
                      datestr(now, 'yyyymmdd_HHMMSS') '.xlsx']; %#ok<DATST>
            writetable(new_row, backup);
            warning('log_to_excel: column mismatch – new row saved to %s', backup);
        end
    catch ME
        warning('log_to_excel: could not update %s (%s)', logfile, ME.message);
    end
else
    writetable(new_row, logfile);
end
end
