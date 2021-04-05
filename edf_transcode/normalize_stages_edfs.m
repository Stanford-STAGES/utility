function edfconv = normalize_stages_edfs(src_path, dest_path)
narginchk(1,2);

if ~isdir(src_path)
    throw(MException('EDF:TRANSCODE:ARGS','%s requires valid source path for first argument', mfilename))
end

% ensure the destination path exists.
if nargin < 2 || ~isempty(dest_path)
    dest_path = fullfile(src_path,'normalized_edfs');    
end

if ~isormkdir(dest_path)
    throw(MException('EDF:TRANSCODE:ARGS','%s requires a valid destination path for writing to.  %s is not valid.', mfilename, dest_path))
end

edfconv = CLASS_stages_edf_converter(src_path, dest_path);
% Read the number of edf files in the src_path    