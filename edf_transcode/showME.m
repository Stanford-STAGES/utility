function showME(me)
% showME(me)
% Simple error reporting function for exceptions caught with try catch(me)
% block MATLAB

% Author: Hyatt Moore IV
% Date: 2012/2013
fprintf(1, '%s\n', me.message);
for k=1:numel(me.stack)
    fprintf(1,'<a href="matlab: opentoline(''%s'', %u, 1)">%s at %u</a>\n', me.stack(k).file, me.stack(k).line, me.stack(k).name, me.stack(k).line);
end