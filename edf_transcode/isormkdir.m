function isIt = isormkdir(dirName)
    if ~isdir(dirName)
        mkdir(dirName);
    end
    isIt = isdir(dirName);
end