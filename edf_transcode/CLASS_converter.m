%> @file CLASS_converter.cpp
%> @brief CLASS_converter is used for converting PSG studies from different
%> formats into a format compatible with SEV.
% ======================================================================
%> @brief CLASS_converter is used for converting PSG studies obtained
%> with proprietary equipment, such as that of Sandman or Embla.
%> @note Written by Hyatt Moore IV
% ======================================================================
classdef CLASS_converter < handle
    properties
        %> path to the source directory - preconversion
        srcPath;
        %> path to the output directory - converted files go here.
        destPath;
        %> String prefixed to studies
        prefixStr;
        %> can be 'tier','flat','group','layer'
        srcType;
    end
    
    
    properties(Constant)
        %> The events pathname
        events_pathname = '_events';
        %> Expected HDR header fields for signal.
        EDFHDRSignalFields = EDFWriter.EDFHDRSignalFields        
    end
    
    
    % Must be implemented by instantiating class
    methods(Abstract)
        convert2wsc(obj);        
    end
    
    methods(Abstract, Static)
        [dualchannel, singlechannel, unhandled] = getMontageConfigurations();
    end
    
    methods
        
        %> @brief Constructor
        %> @retval obj Instance of CLASS_converter
        function obj = CLASS_converter(varargin)
            if nargin                
                obj.srcPath = varargin{1};                
                if nargin > 1
                    obj.destPath = varargin{2};
                end
                
                if isdir(obj.srcPath) && isormkdir(obj.destPath)
                    obj.convert2wsc();
                end
            end                        
        end
        
        % Used to be an abstract method - overload with subclasses as
        % necessary.
        function mappedFilename = srcNameMapper(obj, srcFilename, mappedExtension)
            mappedFilename = srcFilename;
            % the end
        end
        
        %> @brief generates the mapping file for each conversion.  The
        %> mapping file helps audit cohort transcoding by placing the source
        %> psg filename on the same line with the generated .EDF, .SCO, and
        %> .STA files (as applicable) during the conversion process.
        %> @param obj Instance of CLASS_converter
        function generateMappingFile(obj)
            mapFilename = obj.getMappingFilename();
            fid = fopen(mapFilename,'w+');
            psgExt = '.edf';
            if(fid>0)
                try
                    if(strcmpi(obj.srcType,'group'))
                        
                        [~,edfPathnames] = getPathnames(obj.srcPath);
                        
                        for d=1:numel(edfPathnames)
                            fnames = getFilenamesi(edfPathnames{d},psgExt);
                            for f=1:numel(fnames)
                                srcFilename = fnames{f};
                                destFilename = obj.srcNameMapper(srcFilename,'EDF');
                                fprintf(fid,'%s\t%s\n',srcFilename,destFilename);
                            end
                        end
                        fclose(fid);
                    elseif(strcmpi(obj.srcType,'tier'))
                        [~,edfPathnames] = getPathnames(obj.srcPath);
                        
                        for f=1:numel(edfPathnames)
                            srcFilename = getFilenamesi(edfPathnames{f},psgExt);
                            srcFilename = char(srcFilename);
                            destFilename = obj.srcNameMapper(srcFilename,'EDF');
                            fprintf(fid,'%s\t%s\n',srcFilename,destFilename);
                        end
                        fclose(fid);
                    elseif(strcmpi(obj.srcType,'flat'))
                        fnames = getFilenamesi(obj.srcPath,psgExt);
                        for f=1:numel(fnames)
                            srcFilename = fnames{f};
                            destFilename = obj.srcNameMapper(srcFilename,'EDF');
                            fprintf(fid,'%s\t%s\n',srcFilename,destFilename);
                        end
                        
                        fclose(fid);
                    else
                        fprintf('This source type (%s) is not supported!',obj.srcType);
                        fclose(fid);
                    end
                catch me
                    showME(me);
                    fclose(fid);
                end
            else
                fprintf('Error!  Could not open %s for writing.\n',mapFilename);
            end
        end        
        
        function mapFilename = getMappingFilename(obj)
            mapFilename = strcat(obj.prefixStr,'.map');
        end
        
        %> @brief Retrieves single channel montage configuration from an .EDF input file.
        %> @param obj Instance of CLASS_converter
        %> @param fullEDFFilename Full filename of EDF input file.
        %> @retval newLabels is the renamed/normalized labels for the EDF channel names.
        %> @retval newLabelIndices are the indices to the original EDF
        %> channel names (their order) which the new labels (newLabels)
        %> correspond.
        function [newLabels, newLabelIndices, newHDREntries] = getSingleMontageConfigurations(obj,fullEDFFilename)
            [~, singleChannel, ~] = obj.getMontageConfigurations();
            HDR = loadEDF(fullEDFFilename);            
            newLabels = {};
            newLabelIndices = [];
            for d = 1:numel(singleChannel)
                curChannelLabels = singleChannel{d};
                for n=1:numel(curChannelLabels)-1
                    index = find(strcmpi(curChannelLabels{n},HDR.label));
                    if(~isempty(index))
                        % sadly some have more than 1
                        newLabelIndices(end+1) = index(1);
                        newLabels{end+1} = curChannelLabels{end};
                        if numel(index)>1
                            fprintf(1,'[WARNING] %s has multiple channels matching label for ''%s''\n',fullEDFFilename, curChannelLabels{end});
                            for ind=2:numel(index)
                                newLabelIndices(end+1) = index(1);
                                newLabels{end+1} = curChannelLabels{end};
                            end
                        end
                        break;
                    end
                end
            end
            
            newHDREntries = [];
            % remove any original labels
            if(~isempty(newLabels))
                newHDREntries = CLASS_converter.extractEDFHeader(HDR,newLabelIndices);
                newHDREntries.label = newLabels(:);
            end
        end
        
        %> @brief Retrieves montage configuration from an .EDF infput file.
        %> @param obj Instance of CLASS_converter
        %> @param fullSrcFile Full filename of EDF input file.
        %> @retval mergeHDRentries is empty if there are no dual channel
        %> configurations found in the EDF of the provided source file
        %> @retval mergeIndices is a two column matrix containing the indices of the
        %> EDF signals to combine (i.e., channel at mergeIndices(1) - channel
        %> at mergeIndices(2).
        function [mergedHDREntries, mergeIndices] = getDualMontageConfigurations(obj,fullSrcFile)
            [dualChannel, ~, ~] = obj.getMontageConfigurations();
            HDR = loadEDF(fullSrcFile);
            
            mergedHDREntries = [];
            mergeIndices = [];
            mergeLabels = {};
            % check for EDF's and dual configurations if necessary
            for d = 1:numel(dualChannel)
                index1 = find(strcmpi(HDR.label,dualChannel{d}{1}));
                index2 = find(strcmpi(HDR.label,dualChannel{d}{2}));
                if(~isempty(index1) && ~isempty(index2))
                    mergeIndices(end+1,:) = [index1,index2];
                    mergeLabels{end+1} = dualChannel{d}{3};
                end
            end
            
            % remove any repetitions (e.g. C3-A2 -> C3-Ax and C3-A1 -> C3-Ax)
            if(~isempty(mergeLabels))
                [mergedLabels,i] =unique(mergeLabels);
                mergedLabels = mergedLabels(:);
                mergeIndices = mergeIndices(i,:);
                primaryIndices = mergeIndices(:,1);
                mergedHDREntries = CLASS_converter.extractEDFHeader(HDR,primaryIndices);
                mergedHDREntries.label = mergedLabels;
            end
        end
        
        %> @brief export Grouped edf path - exports .EDF files found in subdirectories of the
        %> source directory.
        %> @param obj Instance of CLASS_converter
        function exportGroupedEDFPath(obj)
            [~,edfPathnames] = getPathnames(obj.srcPath);
            for d=1:numel(edfPathnames)
                obj.exportFlatEDFPath(obj,edfPathnames{d})
            end
        end
        
        %> @brief Exports only the channel names listed from
        %> getChannelMontageConfiguration at the samplerate provided.
        %> @param obj Instance of CLASS_converter
        %> @param fullSrcFile Full name of the source/input file
        %> @param fullDestFile Full name of the destination/export file.
        %> @param exportSamplerate Samplerate to use for destination
        %> channels.  If nothing is provided, then the original samplerate is
        %> kept.
        function didExport = exportCulledEDF(obj, fullSrcFile, fullDestFile, exportSamplerate)
            % returns two column array of indices to combine (each row
            % represents a unqiue channel that is formed by taking the
            % difference of EDF signal from the per row indices
            if(nargin< 4)
                exportSamplerate = [];
            end
            [mergeHDREntries, mergeIndices] = obj.getDualMontageConfigurations(fullSrcFile);
            %             [newLabels, newLabelIndices, newHDREntries] = obj.getSingleMontageConfigurations(fullSrcFile);
            
            if(isempty(mergeHDREntries))
                didExport = false;
            else
                didExport = obj.rewriteCulledEDF(fullSrcFile,fullDestFile,mergeIndices,mergeHDREntries,exportSamplerate);
            end
        end
        
        %> @brief Transfers .EDF files from their full source file to the full destination file given
        %> dual channel montage configurations are combined first
        %> single channel labels are normalized using list of names
        %> @param obj Instance of CLASS_converter
        %> @param fullSrcFile Full name of the source/input file
        %> @param fullDestFile Full name of the destination/export file.
        function success = exportEDF(obj,fullSrcFile,fullDestFile, optional_samplerate)
            if nargin < 4
                optional_samplerate = [];
            end
            success = false;
            
            % dual channel configurations are first reduced to single channels and
            % data is sent to destPath
            [hasValidHDR, corrected_HDR] = EDFWriter.checkEDFHeader(fullSrcFile);
            if ~hasValidHDR && isempty(corrected_HDR)
                fprintf('INVALID header found which cannot be fixed.  NOT exporting %s to %s.  FAIL\n',fullSrcFile, fullDestFile);
            elseif ~copyfile(fullSrcFile,fullDestFile)
                fprintf('Could not copy %s to %s.  FAIL\n',fullSrcFile, fullDestFile);
            else
                % Everything we are doing now is going to be the same file,
                % at the destination.  
                fullSrcFile = fullDestFile;                
                
                % Now that it is copied over, go ahead and make changes
                % directly to the file as necessary.
                if ~hasValidHDR
                    fprintf(1,'Updating previously invalid header.\n');
                    EDFWriter.updateEDFHeader(fullDestFile, corrected_HDR);
                end
                
                % Give an initial pass to get our channel labels updated
                [newLabels, newLabelIndices] = obj.getSingleMontageConfigurations(fullDestFile);
                if(~isempty(newLabels))
                    [success] = obj.rewriteEDFHeader(fullDestFile,newLabelIndices,newLabels);
                    if(~success)
                        fprintf('An error occurred when relabeling channel names in the EDF header of %s.\n',fullDestFile);
                    else
                        fprintf('Relabeled channels in the EDF header of %s.\n',fullDestFile);
                    end
                end                
                
                if ~isempty(optional_samplerate)
                    hdr = loadHDR(fullSrcFile);
                    success = EDFWriter.writeLiteEDF(fullSrcFile, fullDestFile, 1:hdr.num_signals, optional_samplerate);
                else
                    success = true;
                end
                
                if success
                    % returns two column array of indices to combine (each row
                    % represents a unqiue channel that is formed by taking the
                    % difference of EDF signal from the per row indices
                    [mergeHDRentries, mergeIndices] = obj.getDualMontageConfigurations(fullSrcFile);
                    if(~isempty(mergeHDRentries))
                        success = obj.rewriteEDF(fullSrcFile,fullDestFile,mergeIndices,mergeHDRentries);
                    end
                end            
                
                % destPath .EDF file headers are relabeled in place
                if(success)
                    % Now go ahead and possibly relabel dual channel
                    % montage configuration results.
                    [newLabels, newLabelIndices] = obj.getSingleMontageConfigurations(fullDestFile);
                    if(~isempty(newLabels))
                        [success] = obj.rewriteEDFHeader(fullDestFile,newLabelIndices,newLabels);
                        if(~success)
                            fprintf('An error occurred when relabeling channel names in the EDF header of %s.\n',fullDestFile);
                        end
                    end
                else
                    fprintf('Could not export %s.  An error occurred.\n',fullSrcFile);
                end
            end
        end
        
        %> @brief export flat edf path - exports a directory containing .EDFs listed
        %> flatly (i.e. not in subdirectories)
        %> @param obj Instance of CLASS_converter
        %> @param optionalSrcPath The optional 'optionalSrcPath' variable allows the flat EDF
        %> path method to be used by the Grouped EDF path method.
        function exportFlatEDFPath(obj,optionalSrcPath, optional_samplerate)            
            if(nargin<2 || isempty(optionalSrcPath))
                theSrcPath = obj.srcPath;
            else
                theSrcPath = optionalSrcPath;
            end
            [srcFilenames,fullSrcFilenames] = getFilenamesi(theSrcPath,'\.edf');
            
            if(~isdir(obj.destPath))
                mkdir(obj.destPath);
            end
            
            if nargin < 3
                optional_samplerate = [];
            end
            
            if(isdir(obj.destPath))
                % make sure the source and destination paths are not the same...
                if((nargin>2 && ~isempty(optionalSrcPath) && strcmpi(optionalSrcPath,obj.destPath)) || strcmpi(obj.srcPath,obj.destPath))
                    fprintf(1,'Will not convert files when source and destination path are identical (%s)\n',obj.destPath);
                else
                    fid = fopen('export_summary.txt','w');
                    if fid<=2
                        fprintf('Error could not create summary file to write to.  Sending summary to console only.\n');
                        fid = 1;
                    end
                    numFiles = numel(srcFilenames);
                    fprintf(fid, 'Exporting %s to %s\t%d files found (%s)\n\n',theSrcPath, obj.destPath, numFiles, datestr(now));

                    for f=1:numFiles
                        srcFile = srcFilenames{f};
                        if nargin>1
                            destFilename = obj.srcNameMapper(srcFile,'.EDF');
                            fullDestFilename = fullfile(obj.destPath,destFilename);
                        else
                            fullDestFilename = fullfile(obj.destPath,srcFile);
                        end
                        try
                            if(exist(fullSrcFilenames{f},'file'))
                                fprintf(1,'%3d of %3d: Exporting %s to %s\n', f, numFiles, fullSrcFilenames{f}, fullDestFilename);
                                if( obj.exportEDF(fullSrcFilenames{f},fullDestFilename, optional_samplerate))
                                    fprintf(fid,'%s\tSUCCESS\n', srcFile);
                                else
                                    fprintf(fid,'%s\tFAIL\n', srcFile);
                                end                                
                            else
                                fprintf('Could not export %s.  File not found.\n',fullSrcFile);
                                fprintf(fid,'%s\tFAIL\n', srcFile);
                            end
                        catch me
                            showME(me);
                            fprintf(fid,'%s\tFAIL (%s)\n', srcFile, me.message);
                        end
                    end
                    fprintf(fid,'\nExport complete (%s)\n', datestr(now));
                    if fid>2                        
                        fclose(fid);
                    end
                end
            else
                fprintf('Could not create the destination path (%s).  Check your system level permissions.\n',obj.destPath);
            end
        end
        
        function emblaEDFPathExport(obj)
            pathnames = getPathnames(obj.srcPath);
            unknown_range = '0000';
            
            [~,i]=intersect(pathnames,{'.','..','_events'});
            pathnames(i)=[];  %remove directories that are not from sleep study recordings
            
            for e=1:numel(obj.psg_expression)
                %matched files
                exp = regexp(pathnames,obj.psg_expression,'names');
                numExp = numel(exp);
                for s=1:numExp
                    fprintf('Set %u - file %u of %u.\n',e,s,numExp);
                    cur_exp = exp{s};                    
                    if(~isempty(cur_exp))
                        try
                            studyname = strcat(unknown_range(1:end-numel(cur_exp.studyname)),cur_exp.studyname);
                            srcFile = [pathnames{s},'.edf'];
                            
                            edfSrcPath = fullfile(obj.srcPath,pathnames{s});
                            studyID = strcat(obj.prefixStr,'_',studyname,'');
                            fullDestFile = fullfile(obj.destPath,strcat(studyID,'.EDF'));
                            fullSrcFile = fullfile(edfSrcPath,srcFile);                            

                            if(exist(fullSrcFile,'file'))
                                obj.exportEDF(fullSrcFile,fullDestFile);
                            else
                                fprintf('Could not export %s.  File not found. (Is extension case, .EDF vs .edf, correct?)\n',fullSrcFile);
                            end
                        catch me
                            showME(me);
                        end
                    end
                end
            end
        end        
        
        %> @brief export Grouped edf path - exports .EDF files found in subdirectories of the
        %> source directory.
        function exportGroupedXMLPath(obj,nameConvertFcn,exportType)
            [~,xmlPathnames] = getPathnames(obj.srcPath);
            for d=1:numel(xmlPathnames)
                obj.exportFlatXMLPath(nameConvertFcn,exportType,xmlPathnames{d})
            end
        end
        
        %> @brief Export flat XML path
        %> @param obj Instance of CLASS_converter
        %> @param nameConvertFcn
        %> @param exportType
        %> @param optionalSrcPath
        function exportFlatXMLPath(obj,nameConvertFcn,exportType, optionalSrcPath)
            
            % the optional 'optionalSrcPath' variable allows the flat EDF
            % path method to be used by the Grouped EDF path method.
            if(nargin<3 || isempty(optionalSrcPath))
                [srcFilenames,fullSrcFilenames] = getFilenamesi(obj.srcPath,'\.xml');
            else
                [srcFilenames,fullSrcFilenames] = getFilenamesi(optionalSrcPath,'\.xml');
            end
            if(~isdir(obj.destPath))
                mkdir(obj.destPath);
            end
            if(isdir(obj.destPath))
                
                for f=1:numel(srcFilenames)
                    try
                        srcFile = srcFilenames{f};
                        if(nargin>1 && isa(nameConvertFcn,'function_handle'))
                            destFilename = nameConvertFcn(srcFile);
                            fullDestFilename = fullfile(obj.destPath,destFilename);
                        else
                            fullDestFilename = fullfile(obj.destPath,srcFile);
                        end
                        
                        if(exist(fullSrcFilenames{f},'file'))
                            obj.exportXML(fullSrcFilenames{f},fullDestFilename,exportType);
                        else
                            fprintf('Could not export %s.  File not found.\n',fullSrcFile);
                        end
                    catch me
                        showME(me);
                        fprintf('Could not export %s.  File not found.\n',srcFile);
                        
                    end
                end
            else
                fprintf('Could not create the destination path (%s).  Check your system level permissions.\n',obj.destPath);
            end
        end
        
        %> @brief Method for exporting Embla file formats.
        %> @param obj Instance of CLASS_converter
        %> @param emblaStudyPath The path with the embla events to export.
        %> @param outPath The destination path to store the exported output.
        %> @param regularExpressions
        %> @param outputType is a string specifying the output format.  The following strings are recognized:
        %> - @c sco for .SCO file format
        %> - @c evt
        %> - @c evts
        %> - @c sta for .STA file format
        %> - @c all {default}
        %> - @c db for database
        %> - @c edf for .EDF
        function emblaEvtExport(obj,emblaStudyPath, outPath, regularexpressions,outputType)
            if(nargin<4)
                outputType = 'all';
            end
            pathnames = getPathnames(emblaStudyPath);
            unknown_range = '0000';
            
            if(~iscell(regularexpressions))
                regularexpressions = {regularexpressions};
            end
            
            studyStruct = CLASS_converter.getSEVStruct();
            studyStruct.samplerate = 256;
            
            studyTypeExportFilename = fullfile(outPath,'studyType.log');
            fid = fopen(studyTypeExportFilename,'w');
            fprintf(fid,'#ID, type\n'); % header line           
            for e=1:numel(regularexpressions)
                % matched files
                exp = regexp(pathnames,regularexpressions{e},'names');
                for s=1:numel(exp)                    
                    cur_exp = exp{s};                    
                    if(~isempty(cur_exp))
                        try
                            
                            srcFile = [pathnames{s},'.edf'];
                            
                            edfSrcPath = fullfile(emblaStudyPath,pathnames{s});
                            
                            studyID = obj.srcNameMapper(srcFile,'');
                            
                            fullSrcFile = fullfile(edfSrcPath,srcFile);
                            
                            HDR = loadEDF(fullSrcFile);
                            studyStruct.startDateTime = HDR.T0;
                            
                            num_epochs = ceil(HDR.duration_sec/studyStruct.standard_epoch_sec);
                            
                            stage_evt_file = fullfile(edfSrcPath,'stage.evt');
                            if(exist(stage_evt_file,'file'))
                                % gets called twice per file so that we can
                                % make sure we have the correct sample
                                % rate.
                                [stageEventStruct,embla_samplerate] = CLASS_codec.parseEmblaEvent(stage_evt_file,studyStruct.samplerate,studyStruct.samplerate);
                                studyStruct.samplerate = embla_samplerate;  % embla_samplerate is the source sample rate determined from the stage.evt file which we know/assume to use 30 seconds per epoch.
                                
                                if(num_epochs~=numel(stageEventStruct.epoch))
                                    % fprintf(1,'different stage epochs found in %s\n',studyname);
                                    if(any(strcmpi(outputType,{'STA','All'})))
                                        fprintf(1,'%s\texpected epochs: %u\tencountered epochs: %u to %u\n',srcFile,num_epochs,min(stageEventStruct.epoch),max(stageEventStruct.epoch));
                                    end
                                    
                                    new_stage = repmat(7,num_epochs,1);
                                    new_epoch = (1:num_epochs)';
                                    new_stage(stageEventStruct.epoch)=stageEventStruct.stage;
                                    stageEventStruct.epoch = new_epoch;
                                    stageEventStruct.stage = new_stage;
                                end
                                
                                if(strcmpi(outputType,'STA') || strcmpi(outputType,'all'))
                                    y = [stageEventStruct.epoch,stageEventStruct.stage];
                                    staFilename = fullfile(outPath,strcat(studyID,'STA'));
                                    save(staFilename,'y','-ascii');
                                end
                                
                                if(~strcmpi(outputType,'STA'))
                                    
                                    if(strcmpi(outputType,'EDF'))
                                        % export the .EDF
                                        obj.exportEDF(fullSrcFile,outPath);
                                        
                                    else
                                        studyStruct.line = stageEventStruct.stage;
                                        studyStruct.cycles = scoreSleepCycles_ver_REMweight(studyStruct.line);
                                        
                                        event_container = CLASS_events_container.importEmblaEvtDir(edfSrcPath,embla_samplerate);
                                        event_container.setStageStruct(studyStruct);
                                        
                                        if(strcmpi(outputType,'sco') || strcmpi(outputType,'all'))
                                            scoFilename = fullfile(outPath,strcat(studyID,'SCO'));
                                            event_container.save2sco(scoFilename);
                                        end
                                        
                                        if(strcmpi(outputType,'evt') || strcmpi(outputType,'all'))
                                            % avoid the problem of file
                                            % names like 'evt.studyName..txt'
                                            if(studyID(end)=='.')
                                                studyID = studyID(1:end-1);
                                            end
                                            event_container.save2txt(fullfile(outPath,strcat('evt.',studyID)));
                                        end
                                        
                                        if(strcmpi(outputType,'evts') || strcmpi(outputType,'all'))
                                            % avoid the problem of file
                                            % names like : evt.studyName..txt
                                            if(studyID(end)=='.')
                                                studyID = studyID(1:end-1);
                                            end
                                            event_container.loadEmblaEvent(stage_evt_file,embla_samplerate);
                                            try
                                                event_container.save2evts(fullfile(outPath,strcat(studyID,'.EVTS')));
                                                
                                                % Output study type info as available
                                                evtObj = event_container.getEventObjFromLabel('numeric');
                                                if(~isempty(evtObj))
                                                    fprintf(fid,'%s, %s\n',studyID,strtok(evtObj.paramStruct.description{1}));  %e.g., strtok('CPAP (6.000)') -> 'CPAP'
                                                end                                                
                                            catch me
                                                fprintf(fid,'%s,%s\n',studyID,'<error occurred>');                                                
                                                showME(me);
                                            end
                                        end                                        
                                        if(strcmpi(outputType,'db') || strcmpi(outputType,'all'))
                                            % ensure there is a record of it in the database !!!
                                            CLASS_events_container.import_evtFile2db(dbStruct,ssc_edf_path,ssc_evt_path);
                                        end
                                    end
                                end
                            else
                                fprintf(1,'%s\tNo stage File found\n',srcFile);
                            end
                            
                        catch me
                            showME(me);
                            fprintf(1,'%s (%u) - Fail\n',srcFile,s);
                            fprintf(fid,'%s,%s\n',studyID,'<error occurred>');
                                                
                        end
                    end
                end
            end
            fclose(fid);
        end        
    end
    
    methods(Static)
        %> @brief Retrieve a struct of values helpful for SEV conversion.
        %> @retval Struct with default field value pairs for SEV
        function sevStruct = getSEVStruct()
            sevStruct.src_edf_pathname = '.'; % initial directory to look in for EDF files to load
            sevStruct.src_event_pathname = '.'; % initial directory to look in for EDF files to load
            sevStruct.batch_folder = '.'; % '/Users/hyatt4/Documents/Sleep Project/EE Training Set/';
            sevStruct.yDir = 'normal';  % or can be 'reverse'
            sevStruct.standard_epoch_sec = 30; % perhaps want to base this off of the hpn file if it exists...
            sevStruct.samplerate = 100;
            sevStruct.channelsettings_file = 'channelsettings.mat'; % used to store the settings for the file
            sevStruct.output_pathname = 'output';
            sevStruct.detectionInf_file = 'detection.inf';
            sevStruct.detection_path = '+detection';
            sevStruct.filter_path = '+filter';
            sevStruct.databaseInf_file = 'database.inf';
            sevStruct.parameters_filename = '_sev.parameters.txt';
        end
        
        
        % =================================================================
        %> @brief Parses EDF Plus file or directory of files and checks each file for overlapping events.
        %> @param edfFileOrPath Full filename (i.e. with path) or path of
        %> an EDF Plus file(s).
        %> @retval verificationStructs Nx1 cell of verification structs.
        %> @note See verifyEvents for verification struct description.
        % =================================================================
        function [verificationStructs, edfFiles] = verifyEDFAnnotationsPath(edfFileOrPath)
            if(isdir(edfFileOrPath))
                [~,edfFiles] = getFilenamesi(edfFileOrPath,'*.edf');
            elseif(exist(edfFileOrPath,'file'))
                edfFiles = {edfFileOrPath};
            else
                fprintf(1,'Input argument must either be an EDF file or a pathname containing EDF files\n');
                edfFiles = {};
            end
            numFiles = numel(edfFiles);
            verificationStructs = cell(numFiles,1);  %CLASS_converter.getVerificationStruct();
            if(numFiles == 0)
                fprintf('No files found!\n');
            else
                % verificationStructs = repmat(verificationStructs,numFiles,1);
                for f=1:numFiles
                    edfFile = edfFiles{f};
                    [~, edfBase,edfExt] = fileparts(edfFile);
                    fprintf('Checking events from %s%s\n',edfBase,edfExt);
                    verificationStructs{f} = CLASS_converter.verifyEDFAnnotations(edfFile);
                end
            end
        end
        
        % =================================================================
        %> @brief Checks for overlapping events or sleep scorings in annotations of an EDF Plus file
        %> @param edfFile Full EDF Plus filename.
        %> @retval verificationStruct verification struct
        %> @note See getVerificationStruct for field names and their descriptions.
        % =================================================================
        function verificationStruct = verifyEDFAnnotations(edfFilename)
            verificationStruct = CLASS_converter.getVerificationStruct(edfFilename);
            
            if(exist(edfFilename,'file'))
                [annotationRecords, HDR] = getEDFPlusAnnotations(edfFilename);
                
                recordCount = numel(annotationRecords);
                talsPerRecord = cellfun(@(c)numel(c),annotationRecords);
                stopIndicesPerRecord = cumsum(talsPerRecord);
                startIndicesPerRecord = [1;stopIndicesPerRecord(1:end-1)+1];
                numTals = sum(talsPerRecord);
                tmpStruct = CLASS_codec.makeEventStruct();
                eventStructs = repmat(tmpStruct,numTals,1);
                for r=1:recordCount
                    eventStructs(startIndicesPerRecord(r):stopIndicesPerRecord(r)) = CLASS_codec.getEventsFromEDFAnnotationRecord(annotationRecords{r},HDR);
                end
                
                eventTable = struct2table(eventStructs);
                % evtInd = cellfun(@isempty,(eventTable.stage));  %This
                % turns out to not be a cell when there are no events in
                % the table (aside from the hypnogram).
                evtInd = ~strcmpi(eventTable.type,'stage');
                
                evtTable  = eventTable(evtInd,:);
                uniqueEvtDescriptions = unique(evtTable.description);
                
                evtNum = 0;  %for label mapping
                numEvtDescriptions = numel(uniqueEvtDescriptions);
                evtMappingCell = cell(numEvtDescriptions,2);
                overlapEvents = false(numEvtDescriptions,1);
                for u=1:numel(uniqueEvtDescriptions)
                    curLabel = uniqueEvtDescriptions{u};
                    curInd = strcmpi(evtTable.description,curLabel);
                    
                    % Here I am finding the current event description and
                    % examing all matching indices for overlap.  If there
                    % are overlaps, then I proceed to identify where these
                    % start and stop in the file and then convert these
                    % start/stop indices to their equivalent start/stop
                    % date vectors in order to make them more universally
                    % identifiable when trying to resolve the issues (i.e.
                    % invesitage where the overlaps occur visually with
                    % another software tool.
                    % Each duplicated event gets its own field name in the
                    % verification struct with the naming convention
                    % event_# where # is the description's ordinal value.
                    if(sum(curInd)>1)
                        curTable = evtTable(curInd,:);
                        [~,overlapInd] = CLASS_events.merge_nearby_events(curTable.start_stop_matrix, 1);
                        numOverlap = sum(overlapInd);
                        if(numOverlap>0)
                            overlapEvents(u)=true;
                            evtNum = evtNum+1;
                            
                            [~,verStruct] = CLASS_converter.getVerificationStruct();
                            verStruct.start_stop_matrix = evtTable.start_stop_matrix(overlapInd,:);
                            verStruct.description = evtTable.description(overlapInd);
                            verStruct.startTime = repmat(HDR.T0,numOverlap,1)+[zeros(numOverlap,numel(HDR.T0)-1),evtTable.start_sec(overlapInd)];
                            verStruct.stopTime = repmat(HDR.T0,numOverlap,1)+[zeros(numOverlap,numel(HDR.T0)-1),evtTable.stop_sec(overlapInd)];
                            verStruct.label = curLabel;
                            evtName = sprintf('event_%u',evtNum);
                            evtMappingCell(u,:)={evtName,curLabel};
                            verificationStruct.(evtName) = verStruct;
                        end
                    end
                end
                
                if(sum(overlapEvents)>0)
                    verificationStruct.hasOverlappingEvents = true;
                    verificationStruct.eventNameMapping = evtMappingCell(overlapEvents,:); % only take the ones that we found.
                end
                
                % Now handle the hypnogram in the same way
                stageInd = ~evtInd;
                
                if(sum(stageInd)>1)
                    curTable = eventTable(stageInd,:);
                    [~,overlapInd, mergedToInd] = CLASS_events.merge_nearby_events(curTable.start_stop_matrix, 0);
                    numOverlap = sum(overlapInd);
                    if(numOverlap>0)
                        verificationStruct.stage.start_stop_matrix = curTable.start_stop_matrix(overlapInd,:);
                        verificationStruct.stage.description = curTable.description(overlapInd);
                        verificationStruct.stage.stage = cell2mat(curTable.stage(overlapInd));
                        
                        verificationStruct.stage.startTime = datevec(datenum(repmat(HDR.T0,numOverlap,1)+[zeros(numOverlap,numel(HDR.T0)-1),curTable.start_sec(overlapInd)]));
                        verificationStruct.stage.stopTime = datevec(datenum(repmat(HDR.T0,numOverlap,1)+[zeros(numOverlap,numel(HDR.T0)-1),curTable.stop_sec(overlapInd)]));
                        verificationStruct.hasOverlappingStages = true;
                        
                        
                        % For debugging and testing:
                        % [datestr(datenum(verificationStruct.stage.startTime(end-33:end,:)),'HH:MM:SS  '),datestr(datenum(verificationStruct.stage.stopTime(end-33:end,:)),'HH:MM:SS ')]
                        overlapMergedToInd = mergedToInd(overlapInd);
                        uniqueMergeToInd = unique(overlapMergedToInd);
                        numFinalMerges = numel(uniqueMergeToInd);
                        stageLabelsMerged = cell(numFinalMerges,1);
                        for n=1:numFinalMerges
                            curMergedGroupInd = (mergedToInd==uniqueMergeToInd(n));
                            stageLabelsMerged{n} = cell2mat(curTable.stage(curMergedGroupInd))';
                        end
                        verificationStruct.stage.scoresOfMergedStages = stageLabelsMerged;
                    end
                end
                
            end
            %start_time = datenum(cur_datevec)+t0_as_datenum;
            %start_time = datestr(start_time,'HH:MM:SS.FFF');
            
        end
        
        % =================================================================
        %> @brief Returns template struct for holding event verification
        %> information.
        %> @retval verificationStruct struct with the following fields
        %> - filename
        %> - hasOverlappingStages Boolean true if any stages overlap in the
        %> hypnogram.
        %> - stage Struct with fields of verStruct.
        %> - eventNameMapping Nx2 cell of additional field names and their
        %> corresponding description label.
        %> - event_# Variable number of verStruct structs corresponding to
        %> the number of unique event types that were found to have overlaps.
        %> @note There can be a variety of different events scored and
        %> labeled.  Each of these different event types should be checked,
        %> in turn, for overlap within its group.  If overlaps are found,
        %> then the boolean flag hasOverlappingEvents should be set to
        %> true, a new event field name should be added to verification
        %> struct with the name event_# where # corresponds to the next
        %> available number (beginning with 1).  This new field name should
        %> hold a verStruct containing the overlapping event details.  An
        %> entry should also be made in the eventNameMapping cell showing the
        %> name mapping between event_# and its label/description.
        %> @retval verStruct Struct with following fields
        %> - label String label describing the structs overlapping events.
        %> - start_stop_matrix indices of overlapping events.
        %> - startVec datevec of start date times of overlapping events.
        %> - stopVec datevec of stop date times of overlapping events.
        % =================================================================
        function [verificationStruct, verStruct] = getVerificationStruct(optionalFilename)
            if(nargin<1)
                optionalFilename = '';
            end
            %sz_datevec=size(datevec(now));
            verStruct = struct('start_stop_matrix',[],'label','','startTime',[],'stopTime',[]);
            stageVerStruct = struct('start_stop_matrix',[],'label','stage','startTime',[],'stopTime',[]);
            
            %verStruct = struct('start_stop_matrix',[],'label','','startVec',zeros(sz_datevec),'stopVec',zeros(sz_datevec));
            verificationStruct = struct('filename',optionalFilename,'hasOverlappingStages',false,'hasOverlappingEvents',false,'stage',stageVerStruct,'eventNameMapping',{''});
            
            
            % Weird bug or something I don't understand.  You cannot
            % include empty 2D cells without making the struct come up as
            % empty.  See 'eventNameMapping' entry
            % Here is the buggy version: verificationStruct = struct('filename',optionalFilename,'hasOverlappingStages',false,'hasOverlappingEvents',false,'stage',verStruct,'eventNameMapping',{'',''});
            
            % Here's a fix though:
            %             if(numel(verificationStruct)>1)
            %                 verificationStruct = verificationStruct(1);
            %             end
        end
        
        % =================================================================
        %> @brief Parses EDF Plus file or directory of files and exports
        %> corresponding hynpogram as a .STA file.
        %> @param edfFileOrPath Full filename (i.e. with path) or path of
        %> an EDF Plus file(s).
        % =================================================================
        function edfAnnotations2STA(edfFileOrPath)
            if(exist(edfFileOrPath,'file'))
                edfFiles = {edfFileOrPath};
            elseif(exist(edfFileOrPath,'dir'))
                [~,edfFiles] = getFilenamesi(edfFileOrPath,'*.edf');
            else
                fprintf(1,'Input argument must either be an EDF file or a pathname containing EDF files\n');
                edfFiles = {};
            end
            numFiles = numel(edfFiles);
            if(numFiles == 0)
                fprintf('No files found!\n');
            else
                for f=1:numel(edfFiles)
                    [edfPath, edfBase,edfExt] = fileparts(edfFiles{f});
                    
                    staFilename = fullfile(edfPath,[edfBase,'.STA']);
                    
                    % Export the annotations to a new file
                    fprintf('Generating %s.STA from %s%s\n',edfBase,edfBase,edfExt);
                    % fprintf('Processing %s\n',edfFiles{f});
                    stageStruct = CLASS_codec.getStageStructFromEDFPlusFile(edfFiles{f});
                    CLASS_codec.saveHypnogram2STA(stageStruct.stage, staFilename);
                end
            end
        end
        
        
        % =================================================================
        %> @brief Parses EDF Plus file or directory of files and exports
        %> corresponding hynpogram as a .STA file.
        %> @param edfFileOrPath Full filename (i.e. with path) or path of
        %> an EDF Plus file(s).
        % =================================================================
        function edfAnnotations2Evt(edfFileOrPath)
            if(exist(edfFileOrPath,'file'))
                edfFiles = {edfFileOrPath};
            elseif(exist(edfFileOrPath,'dir'))
                [~,edfFiles] = getFilenamesi(edfFileOrPath,'*.edf');
            else
                fprintf(1,'Input argument must either be an EDF file or a pathname containing EDF files\n');
                edfFiles = {};
            end
            numFiles = numel(edfFiles);
            if(numFiles == 0)
                fprintf('No files found!\n');
            else
                for f=1:numel(edfFiles)
                    [edfPath, edfBase,edfExt] = fileparts(edfFiles{f});
                    
                    evtFile = fullfile(edfPath,[edfBase,'.evts']);
                    
                    fid = fopen(evtFile,'w');
                    % Export the annotations to a new file
                    if(fid>1)
                        fprintf('Generating %s.evts from %s%s\n',edfBase,edfBase,edfExt);
                        % fprintf('Processing %s\n',edfFiles{f});
                        [annotationRecords, HDR] = getEDFPlusAnnotations(edfFiles{f});
                        
                        fs = max(HDR.samplerate);  %use highest sampling rate available to avoid issues of non integer indices.
                        
                        % print the header
                        fprintf(fid,'# Samplerate=%d\n',fs);
                        fprintf(fid,'Start Sample,End Sample,Start Time,End Time,Event,File Name\n');
                        t0 = HDR.T0;
                        t0_as_datenum = datenum(t0);
                        cur_datevec = zeros(size(t0));
                        recordCount = numel(annotationRecords);
                        for r=1:recordCount
                            
                            eventStructs = CLASS_codec.getEventsFromEDFAnnotationRecord(annotationRecords{r},HDR);
                            for e=1:numel(eventStructs)
                                evtStruct = eventStructs(e);
                                
                                % Files are stored with 0-based indexing, hence -1
                                start = evtStruct.start_stop_matrix(1)-1;
                                stop = evtStruct.start_stop_matrix(end)-1;
                                cur_datevec(end) = evtStruct.start_sec;
                                start_time = datenum(cur_datevec)+t0_as_datenum;
                                start_time = datestr(start_time,'HH:MM:SS.FFF');
                                
                                cur_datevec(end) = evtStruct.stop_sec;
                                stop_time = datestr(datenum(cur_datevec)+t0_as_datenum,'HH:MM:SS.FFF');
                                
                                fprintf(fid,'%u,%u,%s,%s,"%s",%s\n',start,stop,start_time,stop_time,evtStruct.description,evtStruct.type);
                            end
                        end
                        fclose(fid);
                    else
                        fprintf('Could not open %s.evt for writing!  Skipping %s%s\n',evtFile,edfBase,edfExt);
                    end
                end
            end
        end
        
        function stagesEventsExport(stagesPath, outputPath, outputType)
            if(nargin<3)
                outputType = 'all';
            end
            pathnames = getPathnames(emblaStudyPath);
            studyStruct = CLASS_converter.getSEVStruct();
            studyStruct.samplerate = 256;
            
            studyTypeExportFilename = fullfile(outPath,'studyType.log');
            fid = fopen(studyTypeExportFilename,'w');
            fprintf(fid,'# ID, type\n'); % header line
            for s=1:numel(pathnames)
                try
                    studyName = pathnames{s};
                    srcFile = [studyName,'.edf'];
                    edfSrcPath = fullfile(emblaStudyPath,pathnames{s});
                    fullSrcFile = fullfile(edfSrcPath,srcFile);
                    
                    HDR = loadEDF(fullSrcFile);
                    studyStruct.startDateTime = HDR.T0;
                    
                    num_epochs = ceil(HDR.duration_sec/studyStruct.standard_epoch_sec);
                    
                    stage_evt_file = fullfile(edfSrcPath,'stage.evt');
                    if(exist(stage_evt_file,'file'))
                        [eventStruct,src_samplerate] = CLASS_codec.parseSTAGESEvent(stage_evt_file,studyStruct.samplerate,studyStruct.samplerate);
                        studyStruct.samplerate = src_samplerate;
                        
                        if(num_epochs~=numel(eventStruct.epoch))
                            % fprintf(1,'different stage epochs found in %s\n',studyname);
                            if(any(strcmpi(outputType,{'STA','All'})))
                                fprintf(1,'%s\texpected epochs: %u\tencountered epochs: %u to %u\n',srcFile,num_epochs,min(eventStruct.epoch),max(eventStruct.epoch));
                            end
                            
                            new_stage = repmat(7,num_epochs,1);
                            new_epoch = (1:num_epochs)';
                            new_stage(eventStruct.epoch)=eventStruct.stage;
                            eventStruct.epoch = new_epoch;
                            eventStruct.stage = new_stage;
                        end
                        
                        if(strcmpi(outputType,'STA') || strcmpi(outputType,'all'))
                            y = [eventStruct.epoch,eventStruct.stage];
                            staFilename = fullfile(outPath,strcat(studyName,'.STA'));
                            save(staFilename,'y','-ascii');
                        end
                        
                        if(~strcmpi(outputType,'STA'))
                            % export the .EDF
                            if(strcmpi(outputType,'EDF'))
                                fprintf('EDF conversion is not implemented as a static method');
                            else
                                event_container = CLASS_events_container.importEmblaEvtDir(edfSrcPath,src_samplerate);
                                studyStruct.line = eventStruct.stage;
                                studyStruct.cycles = scoreSleepCycles_ver_REMweight(studyStruct.line);
                                event_container.setStageStruct(studyStruct);
                                if(strcmpi(outputType,'sco') || strcmpi(outputType,'all'))
                                    scoFilename = fullfile(outPath,strcat(studyName,'.SCO'));
                                    event_container.save2sco(scoFilename);
                                end
                                
                                if(strcmpi(outputType,'evt') || strcmpi(outputType,'all'))
                                    % avoid the problem of file
                                    % names like  'evt.studyName..txt'
                                    if(studyName(end)=='.')
                                        studyName = studyName(1:end-1);
                                    end
                                    event_container.save2txt(fullfile(outPath,strcat('evt.',studyName)));
                                end
                                
                                if(strcmpi(outputType,'evts') || strcmpi(outputType,'all'))
                                    % avoid the problem of file
                                    % names like 'studyName..EVTS'
                                    if(studyName(end)=='.')
                                        studyName = studyName(1:end-1);
                                    end
                                    event_container.save2evts(fullfile(outPath,strcat(studyName,'.EVTS')));
                                    % Output study type info as available
                                    evtObj = event_container.getEventObjFromLabel('numeric');
                                    if(~isempty(evtObj))
                                        fprintf(fid,'%s,%s\n',studyName,strtok(evtObj.description{1}));  %e.g., strtok('CPAP (6.000)') -> 'CPAP'
                                    end
                                    
                                    
                                end
                            end
                        end
                    else
                        fprintf(1,'%s\tNo stage File found\n',srcFile);
                    end
                    
                catch me
                    showME(me);
                    fprintf(1,'%s (%u) - Fail\n',srcFile,s);
                end
            end
            fclose(fid);
        end
        
        %> @brief Static method for exporting Embla file formats.
        %> @param emblaStudyPath The path with the embla events to export.
        %> @param outPath The destination path to store the exported output.
        %> @param outputType is a string specifying the output format.  The following strings are recognized:
        %> - @c sco for .SCO file format
        %> - @c evt
        %> - @c evts
        %> - @c sta for .STA file format
        %> - @c all (default)
        %> - @c db for database
        %> - @c edf for .EDF
        function staticEmblaEvtExport(emblaStudyPath, outPath,outputType)
            
            if(nargin<3)
                outputType = 'all';
            end
            pathnames = getPathnames(emblaStudyPath);
            studyStruct = CLASS_converter.getSEVStruct();
            studyStruct.samplerate = 256;
            
            studyTypeExportFilename = fullfile(outPath,'studyType.log');
            fid = fopen(studyTypeExportFilename,'w');
            fprintf(fid,'# ID, type\n'); % header line
            for s=1:numel(pathnames)
                try
                    studyName = pathnames{s};
                    srcFile = [studyName,'.edf'];
                    edfSrcPath = fullfile(emblaStudyPath,pathnames{s});
                    fullSrcFile = fullfile(edfSrcPath,srcFile);
                    
                    HDR = loadEDF(fullSrcFile);
                    studyStruct.startDateTime = HDR.T0;
                    
                    num_epochs = ceil(HDR.duration_sec/studyStruct.standard_epoch_sec);
                    
                    stage_evt_file = fullfile(edfSrcPath,'stage.evt');
                    if(exist(stage_evt_file,'file'))
                        [eventStruct,src_samplerate] = CLASS_codec.parseEmblaEvent(stage_evt_file,studyStruct.samplerate,studyStruct.samplerate);
                        studyStruct.samplerate = src_samplerate;
                        
                        if(num_epochs~=numel(eventStruct.epoch))
                            % fprintf(1,'different stage epochs found in %s\n',studyname);
                            if(any(strcmpi(outputType,{'STA','All'})))
                                fprintf(1,'%s\texpected epochs: %u\tencountered epochs: %u to %u\n',srcFile,num_epochs,min(eventStruct.epoch),max(eventStruct.epoch));
                            end
                            
                            new_stage = repmat(7,num_epochs,1);
                            new_epoch = (1:num_epochs)';
                            new_stage(eventStruct.epoch)=eventStruct.stage;
                            eventStruct.epoch = new_epoch;
                            eventStruct.stage = new_stage;
                        end
                        
                        if(strcmpi(outputType,'STA') || strcmpi(outputType,'all'))
                            y = [eventStruct.epoch,eventStruct.stage];
                            staFilename = fullfile(outPath,strcat(studyName,'.STA'));
                            save(staFilename,'y','-ascii');
                        end
                        
                        if(~strcmpi(outputType,'STA'))
                            % export the .EDF
                            if(strcmpi(outputType,'EDF'))
                                fprintf('EDF conversion is not implemented as a static method');
                            else
                                event_container = CLASS_events_container.importEmblaEvtDir(edfSrcPath,src_samplerate);
                                studyStruct.line = eventStruct.stage;
                                studyStruct.cycles = scoreSleepCycles_ver_REMweight(studyStruct.line);
                                event_container.setStageStruct(studyStruct);
                                if(strcmpi(outputType,'sco') || strcmpi(outputType,'all'))
                                    scoFilename = fullfile(outPath,strcat(studyName,'.SCO'));
                                    event_container.save2sco(scoFilename);
                                end
                                
                                if(strcmpi(outputType,'evt') || strcmpi(outputType,'all'))
                                    % avoid the problem of file
                                    % names like  'evt.studyName..txt'
                                    if(studyName(end)=='.')
                                        studyName = studyName(1:end-1);
                                    end
                                    event_container.save2txt(fullfile(outPath,strcat('evt.',studyName)));
                                end
                                
                                if(strcmpi(outputType,'evts') || strcmpi(outputType,'all'))
                                    % avoid the problem of file
                                    % names like 'studyName..EVTS'
                                    if(studyName(end)=='.')
                                        studyName = studyName(1:end-1);
                                    end
                                    event_container.save2evts(fullfile(outPath,strcat(studyName,'.EVTS')));
                                    % Output study type info as available
                                    evtObj = event_container.getEventObjFromLabel('numeric');
                                    if(~isempty(evtObj))
                                        fprintf(fid,'%s,%s\n',studyName,strtok(evtObj.description{1}));  %e.g., strtok('CPAP (6.000)') -> 'CPAP'
                                    end
                                    
                                    
                                end
                            end
                        end
                    else
                        fprintf(1,'%s\tNo stage File found\n',srcFile);
                    end
                    
                catch me
                    showME(me);
                    fprintf(1,'%s (%u) - Fail\n',srcFile,s);
                end
            end
            fclose(fid);
        end
        
        function sampleRates  = getAllSamplingRates(psgPath, srcType, channelName)
            if(nargin<2)
                srcType = 'flat';
                
                if(nargin<1)
                    msg_string = 'Select directory with .EDFs';
                    psgPath =uigetdir(pwd,msg_string);
                    if(isnumeric(psgPath) && ~psgPath)
                        psgPath = [];
                    end
                end
            end
            
            sampleRates = [];
            if(strcmpi(srcType,'flat'))
                files = getFilenamesi(psgPath,'EDF');
                
                for f=1:numel(files)
                    srcFile = files{f};
                    fullSrcFile = fullfile(psgPath,srcFile);
                    if(exist(fullSrcFile,'file'))
                        HDR = loadEDF(fullSrcFile);
                        chInd = find(strcmpi(HDR.label,channelName),1);
                        if(~isempty(chInd))
                            sampleRates = union(sampleRates,HDR.samplerate);
                        end
                    end
                end
            elseif(strcmpi(srcType,'tier'))
                [~,edfPathnames] = getPathnames(psgPath);
                for d=1:numel(edfPathnames)
                    psgPath = edfPathnames{d};
                    srcFile = getFilenamesi(psgPath,'EDF');
                    if(iscell(srcFile) && ~isempty(srcFile))
                        srcFile = srcFile{1};
                    end
                    fullSrcFile = fullfile(psgPath,srcFile);
                    if(exist(fullSrcFile,'file'))
                        HDR = loadEDF(fullSrcFile);
                        chInd = find(strcmpi(HDR.label,channelName),1);
                        if(~isempty(chInd))
                            sampleRates = union(sampleRates,HDR.samplerate);
                        end
                    end
                end
            else
                fprintf('Source type must be ''tier'' or ''flat''\n');
            end
            
        end
        
        %> @brief Return full list of channel names found by checking all .EDF file
        %> headers listed in the flat directory path provided.
        %> @param psgPath Pathname to search for .EDF headers (optional).  If not included, a popup dialog
        %> is presented to the user to choose the path.
        %> @retval channelNames is a cell of all unique channel labels
        %> listed in the EDF header's @c label field.
        %> @param srcType This is the source type for the psgPath.  It is a
        %> string and can be:
        %> - tier
        %> - flat (default)
        %> @retval channelNamesAll is a Nx1 cell, where N is the number of
        %> .EDF files found in the psg path.  Each cell contains the channel
        %> labels listed for the n_th EDF file (n is between 1 and N).
        %> @retval edfNamesAll - Nx1 cell of the EDF filenames (srcType='flat') 
        %> or pathname (srcType='tier') which match the channel names all
        %> entry for the corresponding row/index.
        function [channelNames, channelNamesAll, edfNamesAll, channelNameOccurrences] = getAllChannelNames(psgPath,srcType)
                
            if(nargin<2)
                srcType = 'flat';
                
                if(nargin<1)
                    msg_string = 'Select directory with .EDFs';
                    psgPath =uigetdir(pwd,msg_string);
                    if(isnumeric(psgPath) && ~psgPath)
                        psgPath = [];
                    end
                end
            end
            edfNamesAll = {};
            if(strcmpi(srcType,'flat'))
                files = getFilenamesi(psgPath,'EDF');
                channelNames = {};
                edfNamesAll = files;
                channelNamesAll = cell(numel(files),1);
                for f=1:numel(files)
                    srcFile = files{f};
                    fullSrcFile = fullfile(psgPath,srcFile);
                    if(exist(fullSrcFile,'file'))
                        HDR = loadEDF(fullSrcFile);
                        channelNames = union(channelNames,HDR.label);
                        channelNamesAll{f} = HDR.label;
                    end
                end
            elseif(strcmpi(srcType,'tier'))
                [~,edfPathnames] = getPathnames(psgPath);
                channelNamesAll = cell(numel(edfPathnames),1);
                channelNames = {};
                edfNamesAll = edfPathnames;
                for d=1:numel(edfPathnames)
                    psgPath = edfPathnames{d};
                    srcFile = getFilenamesi(psgPath,'EDF');
                    if(iscell(srcFile) && ~isempty(srcFile))
                        srcFile = srcFile{1};
                    end
                    fullSrcFile = fullfile(psgPath,srcFile);
                    if(exist(fullSrcFile,'file'))
                        HDR = loadEDF(fullSrcFile);
                        channelNames = union(channelNames,HDR.label);
                        channelNamesAll{d} = HDR.label;
                    end
                end
            else
                fprintf('Source type must be ''tier'' or ''flat''\n');
            end
            if nargout>3
                channelsCount = cellfun(@numel,channelNamesAll);
                channelsAllCount = sum(channelsCount);
                channelNamesAllTogether = cell(channelsAllCount, 1);
                startC = 1;
                for c=1:numel(channelNamesAll)
                    curChannels = channelNamesAll{c};
                    endC = startC+numel(curChannels)-1;
                    channelNamesAllTogether(startC:endC) = curChannels;
                    startC = endC+1;
                end
                channelNameOccurrences = zeros(size(channelNames));
                for ch=1:numel(channelNames)
                    chName = channelNames{ch};
                    channelNameOccurrences(ch) = sum(strcmp(chName, channelNamesAllTogether));
                end                
            end
            disp(char(channelNames));
        end
        
        %> @brief Montage configuration for MrOS cohort.
        %> @retval dualchannel Dual channel configurations (requires combination of two
        %> channels to be combined into one.  The first and second elements
        %> of each cell represent the two channels to use (subtracting the
        %> second from the first) and the third cell value is the name of the
        %> channel to apply to the result.
        %> @retval singleChannel Single channel configurations - Cell array, where last
        %> column is the name to use in place of any names listed in the
        %> preceding columns of a row.
        %> @retval unhandled Cell of unhandled names.  These EDF channel labels are
        %> ignored and not handled.
        function [dualchannel, singlechannel, unhandled] = getMontageConfigurationsMROS()
            unhandled ={};
            dualchannel = {
                %                 {'Leg L','Leg R','L/RAT'}
                {'L Chin','R Chin','L Chin-R Chin'}
                {'ECG L','ECG R','ECG L-ECG R'}
                {'C4','A1','C4-A1'}
                {'C3','A2','C3-A2'}
                {'LOC','A2','LOC-A2'}
                {'ROC','A1','ROC-A1'}
                };
            singlechannel = {
                {'SAO2','SaO2','SpO2'};
                {'HR','Heart Rate'};
                };
        end
        
        
        %> @brief Montage configuration for SSC's APOE cohort.
        %> @retval dualchannel Dual channel configurations (requires combination of two
        %> channels to be combined into one.  The first and second elements
        %> of each cell represent the two channels to use (subtracting the
        %> second from the first) and the third cell value is the name of the
        %> channel to apply to the result.
        %> @retval singlechannel Single channel configurations - Cell array, where last
        %> column is the name to use in place of any names listed in the
        %> preceding columns of a row.
        %> @retval unhandled Cell of unhandled names.  These EDF channel labels are
        %> ignored and not handled.
        function [dualchannel, singlechannel, unhandled] = getMontageConfigurationsAPOE()
            
            unhandled ={
                {'Cannula'}
                {'Airflow'}
                {'PAP Tidal Volume'}
                {'T3-O1'}
                {'T4-O2'}
                {'C3-O1'}
                {'C3-AVG'}
                };
            
            dualchannel = {
                {'LAT','RAT','L/RAT'}
                {'O1','A2','O1-A2'}
                {'O2','A1','O2-A1'}
                {'C3','A1','C3-A1'}
                {'C3','A2','C3-A2'}
                {'C4','A1','C4-A1'}
                {'C4','A2','C4-A2'}
                {'Fz','A1','Fz-A1'}
                {'Fz','A2','Fz-A2'}
                {'Fp1','A2','F1-A2'}
                {'Fp2','C4','F2-C4'}
                {'Fp2','T4','F2-T4'}
                {'Arms-1','Arms-2','Arms'}
                {'EKG-R','EKG-L','EKG'}
                {'RIC-1','RIC-2','RIC'}
                {'LOC','A2','LOC-A2'}
                {'ROC','A1','ROC-A1'}
                };
            
            singlechannel = {
                {'ABD', 'Abd','Abdomen'};
                {'ARMS', 'Arm EMG','Arms'};
                {'CHEST','Chest' };
                {'MIC','Mic'};
                {'Chin EMG','EMG','Chin1-Chin2','Chin1-Chin3','Chin3-Chin2','Chin EMG'};
                {'FZ-A1/A2','FZ-A1A2','Fz-A2'};
                {'F1/A2','FP1-A2','FP1-AZ','FP1/A2','F1-A2'};
                {'FP1-C33456','FP1-T3','FP-?'};
                {'F2/A1','FP2-A1','F2-A1'};
                {'FP2-T4','F2-T4'};
                {'PES','Pes','Esophageal Pressure'};
                {'SaO2', 'SpO2'};
                {'LLEG1-RLEG1','LLEG1-RLEG2','RLEG1-RLEG2','LLEG2-RLEG1','LLEG2-RLEG2','LAT-RAT'};
                {'EKG1-EKG2','EKG'};
                {'O1-A2','O1-AVG','O1-M2','O1-x'};
                {'O2-A1','O2-AVG','O2-M1','O2-x'};
                {'C3-A2','C3-A23456','C3-M2','C3-A2'};
                {'F3-AVG','F3-M2','F3-x'};
                {'F4-AVG','F4-M2','F4-x'};
                {'LEOG-AVG','LEOG-M2','LEOG-x'};
                {'REOG-AVG','REOG-M1','REOG-M2','REOG-x'};
                {'POSITION','Position'};
                {'ETCO2', 'EtCO2'};
                {'Nasal','Nasal Pressure'};
                {'C-PRES', 'PAP Pressure'};
                {'Oral','Oral Thermistor'};
                {'CPAP Leak', 'PAP Leak','PAP Leak'};
                {'Pulse','PULSE','Pulse Rate'};
                {'PTT','Pulse Transit Time'};
                {'pCO2','TcCO2'};
                {'PAP Pt Flow','PAP Patient Flow'}
                };
            
        end
        
        
        % =================================================================
        %> @brief This function automates the file conversion process from
        %> twin formatted .nvt and .evt files to SEV formatted event files.
        %> @param twinStudyPath (optional) This is the parent directory of
        %> twin saved sleep studies.  Contents of this folder include
        %> subfolders for each sleep study.  The twinStudyPath is parsed for
        %> subfolders and the events found in each subfolder are saved to a
        %> separate evt.[study].[event].txt file name using the subfolder name
        %> for [study] and the event file name for [event].
        %> The user is prompted if twinStudy does not exist or is not
        %> entered.
        %> @param outPath (optional) String name of the directory to store the output .SCO files.
        %> The user is prompted if outPath does not exist or is not entered.
        % =================================================================
        function twin2evt(twinStudyPath, outPath)
            if(nargin<2)
                disp('Select Directory containing twin PSG directories.  Typically twin stores each study as a separate named directory.  Choose the directory that contains these named directories in them.');
                msg = 'Select Event directory (*.evt) to use or Cancel for none.';
                twinStudyPath = CLASS_converter.getPathname(pwd,msg);
                msg = 'Select Directory to save SEV evt files to';
                disp(msg);
                outPath =CLASS_converter.getPathname(twinStudyPath,msg);
            end
            
            if(exist(twinStudyPath,'file') && exist(outPath,'file'))
                CLASS_converter.twinEvtExport(twinStudyPath,outPath,'evt');
            else
                fprintf('One or both of the paths were not found');
            end
        end
        
        % =================================================================
        %> @brief This function automates the file conversion process from
        %> twin formatted stage.evt files to STA file format used by SEV.formatted event files.
        %> @param twinStudyPath (optional) This is the parent directory of
        %> twin saved sleep studies.  Contents of this folder include
        %> subfolders for each sleep study.  The twinStudyPath is parsed for
        %> subfolders and the stage.evt files in each subfolder are saved to a
        %> [study].STA files using each subfolder name in the twinStudyPath to
        %> identify [study].
        %> for [study] and the event file name for [event].
        %> The user is prompted if twinStudy does not exist or is not
        %> entered.
        %> @param outPath (optional) String name of the directory to store the output .SCO files.
        %> The user is prompted if outPath does not exist or is not entered.
        % =================================================================
        function twin2STA(twinStudyPath, outPath)
            if(nargin<2)
                disp('Select Directory containing twin PSG directories.  Typically twin stores each study as a separate named directory.  Choose the directory that contains these named directories in them.');
                msg = 'Select Event directory (*.evt) to use or Cancel for none.';
                twinStudyPath = CLASS_converter.getPathname(pwd,msg);
                disp('Select Directory to save .STA files to');
                outPath =CLASS_converter.getPathname(twinStudyPath,'Select directory to save .STA files to.');
            end
            
            if(exist(twinStudyPath,'file') && exist(outPath,'file'))
                
                CLASS_converter.twinEvtExport(twinStudyPath,outPath,'STA');
            else
                fprintf('One or both of the paths were not found');
            end
        end
        
        % =================================================================
        %> @brief This function automates the file conversion process from
        %> Twin formatted event files (*_E.TXT) to a single Wisconsin Sleep
        %> Cohort multiplex .SCO format.
        %> @param twinStudyPath (optional) This is the parent directory of
        %> Twin saved sleep studies.  Contents of this folder include
        %> subfolders for each sleep study.  The twinStudyPath is parsed for
        %> subfolders and the events found in each subfolder are saved to a
        %> .SCO file of same name as the subfolder in the outPath directory.
        %> The user is prompted if twinStudy does not exist or is not
        %> entered.
        %> @param outPath (optional) String name of the directory to store the output .SCO files.
        %> The user is prompted if outPath does not exist or is not entered.
        % =================================================================
        function twin2sco(twinStudyPath, outPath)
            if(nargin<2)
                disp('Select the directory containing Twin PSG files (i.e. *_E.TXT).');
                msg = 'Select Twin PSG event directory (*_E.TXT) to use or Cancel for none.';
                twinStudyPath = CLASS_converter.getPathname(pwd,msg);
                disp('Select destination directory for .SCO files ');
                outPath =CLASS_converter.getPathname(twinStudyPath,'Select directory to send .SCO files to.');
            end
            
            if(exist(twinStudyPath,'file') && exist(outPath,'file'))
                CLASS_converter.twinEvtExport(twinStudyPath,outPath,'sco');
            else
                fprintf('One or both of the paths were not found');
            end
        end
        
        %> @brief stages here refers to Stanford's STAGES cohort, a multisite 
        %> collection of PSGs.
        function stages2evt(stagesEventsPath, evtDestinationPath)
            if(nargin<2)
                disp('Select Directory containing STAGES event files.');
                msg = 'Select Event directory (*.csv) to use or Cancel for none.';
                stagesEventsPath = CLASS_converter.getPathname(pwd,msg);
                msg = 'Select Directory to save SEV evt files to';
                disp(msg);
                evtDestinationPath = CLASS_converter.getPathname(stagesEventsPath, msg);
            end
            
            if exist(stagesEventsPath,'file') && isormkdir(evtDestinationPath)
                CLASS_converter.stagesEventsExport(stagesEventsPath,evtDestinationPath, 'evt'); %exports .evt files
            else
                fprintf('One or both of the paths were not found');
            end
        end
        
        % =================================================================
        %> @brief This function automates the file conversion process from
        %> Embla formatted .nvt and .evt files to SEV formatted event files.
        %> @param emblaStudyPath (optional) This is the parent directory of
        %> Embla saved sleep studies.  Contents of this folder include
        %> subfolders for each sleep study.  The emblaStudyPath is parsed for
        %> subfolders and the events found in each subfolder are saved to a
        %> separate evt.[study].[event].txt file name using the subfolder name
        %> for [study] and the event file name for [event].
        %> The user is prompted if emblaStudy does not exist or is not
        %> entered.
        %> @param outPath (optional) String name of the directory to store the output .SCO files.
        %> The user is prompted if outPath does not exist or is not entered.
        % =================================================================
        function embla2evt(emblaStudyPath, outPath)
            if(nargin<2)
                disp('Select Directory containing Embla PSG directories.  Typically Embla stores each study as a separate named directory.  Choose the directory that contains these named directories in them.');
                msg = 'Select Event directory (*.evt) to use or Cancel for none.';
                emblaStudyPath = CLASS_converter.getPathname(pwd,msg);
                msg = 'Select Directory to save SEV evt files to';
                disp(msg);
                outPath =CLASS_converter.getPathname(emblaStudyPath,msg);
            end
            
            if(exist(emblaStudyPath,'file') && exist(outPath,'file'))
                CLASS_converter.staticEmblaEvtExport(emblaStudyPath,outPath,'evt'); %exports .evt files
            else
                fprintf('One or both of the paths were not found');
            end
        end
        
        % =================================================================
        %> @brief This function automates the file conversion process from
        %> Embla formatted stage.evt files to STA file format used by SEV.formatted event files.
        %> @param emblaStudyPath (optional) This is the parent directory of
        %> Embla saved sleep studies.  Contents of this folder include
        %> subfolders for each sleep study.  The emblaStudyPath is parsed for
        %> subfolders and the stage.evt files in each subfolder are saved to a
        %> [study].STA files using each subfolder name in the emblaStudyPath to
        %> identify [study].
        %> for [study] and the event file name for [event].
        %> The user is prompted if emblaStudy does not exist or is not
        %> entered.
        %> @param outPath (optional) String name of the directory to store the output .SCO files.
        %> The user is prompted if outPath does not exist or is not entered.
        % =================================================================
        function embla2STA(emblaStudyPath, outPath)
            if(nargin<2)
                disp('Select Directory containing Embla PSG directories.  Typically Embla stores each study as a separate named directory.  Choose the directory that contains these named directories in them.');
                msg = 'Select Event directory (*.evt) to use or Cancel for none.';
                emblaStudyPath = CLASS_converter.getPathname(pwd,msg);
                disp('Select Directory to save .STA files to');
                outPath =CLASS_converter.getPathname(emblaStudyPath,'Select directory to save .STA files to.');
            end
            
            if(exist(emblaStudyPath,'file') && exist(outPath,'file'))
                CLASS_converter.staticEmblaEvtExport(emblaStudyPath,outPath,'STA'); %exports all STA files
            else
                fprintf('One or both of the paths were not found');
            end
        end
        
        
        % =================================================================
        %> @brief This function automates the file conversion process from
        %> Embla formatted .nvt and .evt files and a single Wisconsin Sleep
        %> Cohort multiplex .SCO format.
        %> @param emblaStudyPath (optional) This is the parent directory of
        %> Embla saved sleep studies.  Contents of this folder include
        %> subfolders for each sleep study.  The emblaStudyPath is parsed for
        %> subfolders and the events found in each subfolder are saved to a
        %> .SCO file of same name as the subfolder in the outPath directory.
        %> The user is prompted if emblaStudy does not exist or is not
        %> entered.
        %> @param outPath (optional) String name of the directory to store the output .SCO files.
        %> The user is prompted if outPath does not exist or is not entered.
        % =================================================================
        function embla2sco(emblaStudyPath, outPath)
            if(nargin<2)
                disp('Select Directory containing Embla PSG directories.  Typically Embla stores each study as a separate named directory.  Choose the directory that contains these named directories in them.');
                msg = 'Select Event directory (*.evt) to use or Cancel for none.';
                emblaStudyPath = CLASS_converter.getPathname(pwd,msg);
                disp('Select Directory (*.evt)');
                outPath =CLASS_converter.getPathname(emblaStudyPath,'Select directory to send .SCO files to.');
            end
            
            if(exist(emblaStudyPath,'file') && exist(outPath,'file'))
                CLASS_converter.staticEmblaEvtExport(emblaStudyPath,outPath,'SCO'); %exports SCO files
                
                %SSC_APOE_expressions = {'^(?<studyname>\d{4})_(?<studydate>\d{1,2}-\d{1,2}-\d{4})';
                %    '^nonMatch(?<studyname>\d{1,3})'};
                %CLASS_converter.emblaEvtExport(emblaStudyPath,outPath,SSC_APOE_expressions,'sco');
            else
                fprintf('One or both of the paths were not found');
            end
        end        
            
        
        %> @brief helper/wrapper function to get the pathnames.
        %> @param src_directory
        %> @param msg_string
        function pathnameOut = getPathname(src_directory,msg_string)
            if(nargin<1 || ~isdir(src_directory))
                src_directory = pwd;
            end
            pathnameOut =uigetdir(src_directory,msg_string);
            if(isnumeric(pathnameOut) && ~pathnameOut)
                pathnameOut = [];
            end
        end        
        
        %> @brief Export Twin collection format data.
        %> @param srcPath
        %> @param destPath
        %> @param outputType
        %> outputType is 'sco','evt','sta','all' {default}, 'db','edf'
        %> -db is database
        %> - sco is .SCO format
        %> - sta is .STA file formats
        %> -EDF is .EDF        
        function twinEvtExport(srcPath, destPath, outputType)
            if(nargin<3)
                outputType = 'all';
            end
            
            % export event and stage files
            files = getFilenames(srcPath,'*_E.TXT');
            % filename = 'A0013_7_120409_E.TXT';
            % filename = 'A0014_7_120409_E.TXT';
            
            studyStruct = CLASS_converter.getSEVStruct();
            
            if(~isdir(destPath))
                mkdir(destPath)
            end
            
            sta_problems = {};
            unknown_problems = {};
            
            for f=1:numel(files)
                try
                    filename = files{f};
                    evt_fullfilename = fullfile(srcPath,filename);
                    studyName = strrep(filename,'_E.TXT','');
                    EDF_name = fullfile(srcPath,strcat(studyName,'.EDF'));
                    
                    HDR = loadEDF(EDF_name);
                    
                    % studyStruct.samplerate = max(HDR.samplerate);
                    num_epochs_expected = ceil(HDR.duration_sec/studyStruct.standard_epoch_sec);
                    
                    fid = fopen(evt_fullfilename,'r');
                    
                    c = textscan(fid,'%f/%f/%f_%f:%f:%f %[^\r\n]');
                    startDateNum = datenum(HDR.T0);
                    
                    allDateNum = datenum([c{3},c{1},c{2},c{4},c{5},c{6}]);
                    % allDateNum = datenum(cell2mat(cells2cell(c{1:end-1})));
                    
                    datenumPerSec = datenum([0, 0 , 0 ,0 ,0 ,1]);
                    
                    all_elapsed_sec = (allDateNum - startDateNum)/datenumPerSec+1/studyStruct.samplerate; %this is necessary because they began at elapsed seconds of 0
                    seconds_per_epoch = studyStruct.standard_epoch_sec;
                    all_epoch = ceil(all_elapsed_sec/seconds_per_epoch);
                    
                    txt = c{end};
                    exp = regexp(txt,['(?<type>.+) - DUR: (?<dur_sec>\d+.\d+) SEC. - (?<description>[^-]+).*|',...
                        '(?<type>.+) - (?<description>[^-]+).*|',...
                        '(?<type>.+)'],'names');
                    
                    expMat = cell2mat(exp);
                    expTypes = cells2cell(expMat.type);
                    expDursec = cells2cell(expMat.dur_sec);
                    expDescription = cells2cell(expMat.description);
                    
                    fclose(fid);
                    
                    max_epoch_encountered = max(all_epoch);
                    if(max_epoch_encountered>num_epochs_expected)
                        sta_problems{end+1} = filename;
                        fprintf(1,'%s\texpected epochs: %u\tencountered epochs: %u\n',filename,num_epochs_expected,max_epoch_encountered);
                        okay_ind =all_epoch<=num_epochs_expected;
                        all_epoch = all_epoch(okay_ind);
                        all_elapsed_sec = all_elapsed_sec(okay_ind);
                        expTypes = expTypes(okay_ind);
                        expDursec = expDursec(okay_ind);
                        expDescription = expDescription(okay_ind);
                    end
                    
                    expDursec = str2double(expDursec);
                    
                    %give 0 duration to events with no listing
                    expDursec(isnan(expDursec))=0;
                    
                    % studyStruct.samplerate = mode(HDR.samplerate);
                    studyStruct.startDateTime  = HDR.T0;
                    
                    all_start_stop_sec = [all_elapsed_sec(:), all_elapsed_sec+expDursec(:)];
                    all_start_stop_matrix = ceil(all_start_stop_sec.*studyStruct.samplerate);
                    
                    %/  types = {'STAGE','AROUSAL','LM','RESPIRATORY EVENT','DESATURATION','NEW MONTAGE'};
                    %not interested in all of these ones
                    
                    num_epochs = ceil(HDR.duration_sec/studyStruct.standard_epoch_sec);
                    
                    %handle the stages first
                    ind = strcmpi(expTypes,'STAGE');
                    
                    stageDescription = expDescription(ind);
                    %         unique(stageDescription)
                    stageMat = [1:num_epochs_expected;repmat(7,1,num_epochs_expected)]';
                    
                    %change out the text identifiers to numeric stage identifiers (0 =
                    %W, 5= N5, 7 = unknown'
                    stageStrings = {'W','N1','N2','N3','N4','R','N6','NO STAGE'};
                    stageValues = repmat(7,size(stageDescription));
                    for s = 1:numel(stageStrings)
                        stageValues(strcmpi(stageDescription,stageStrings{s}))=s-1;
                    end
                    
                    %go to an epoch based indexing
                    stage_epoch = all_epoch(ind==1);
                    cur_epoch = stage_epoch(1);
                    stageValue = stageValues(1);
                    
                    for s=2:numel(stage_epoch)
                        next_epoch = stage_epoch(s);
                        try
                            stageMat(cur_epoch:next_epoch-1,2) = stageValue;
                        catch me
                            me.message
                        end
                        
                        cur_epoch = next_epoch;
                        stageValue = stageValues(s);
                    end
                    stageMat(cur_epoch:end,2) = stageValue;
                    
                    if(strcmpi(outputType,'STA')||strcmpi(outputType,'ALL'))
                        stageFilename = fullfile(destPath,strcat(studyName,'.STA'));
                        save(stageFilename,'stageMat','-ascii');
                    end
                    
                    if(~strcmpi(outputType,'STA'))
                        types = {'LM','AROUSAL','RESPIRATORY EVENT','DEASUTRATION'};
                        src_label = 'WSC Twin File';
                        
                        studyStruct.line = stageMat(:,2);
                        
                        studyStruct.cycles = scoreSleepCycles_ver_REMweight(studyStruct.line);
                        eventContainer = CLASS_events_container([],[],studyStruct.samplerate,studyStruct);
                        
                        % eventContainer.setStageStruct(studyStruct);
                        % eventContainer.setSamplerate(studyStruct.samplerate);
                        for t=1:numel(types)
                            type = types{t};
                            ind = strcmpi(expTypes,type);
                            
                            typeName = strrep(type,' ','_');
                            evtLabel = strcat('SCO_',typeName);
                            start_stop_matrix = all_start_stop_matrix(ind,:);
                            paramStruct = [];
                            if(~isempty(start_stop_matrix))
                                eventContainer.loadGenericEvents(start_stop_matrix,evtLabel,src_label,paramStruct);
                            end
                        end
                        
                        if(strcmpi(outputType,'sco') || strcmpi(outputType,'all'))
                            scoFilename = fullfile(destPath,strcat(studyName,'.SCO'));
                            eventContainer.save2sco(scoFilename);
                        end
                        
                        if(strcmpi(outputType,'evt') || strcmpi(outputType,'all'))
                            eventContainer.save2txt(fullfile(destPath,strcat('evt.',studyName)));
                        end
                    end
                    
                catch me
                    showME(me);
                    fprintf(1,'%s (%u) - Fail\n',filename,f);
                end
            end
        end
        
        
        %> @brief this function requires the use of loadSCOfile.m and is useful
        %> for batch processing...
        %
        %> Usage:
        %>  exportSCOtoEvt() prompts user for .SCO directory and evt output directory
        %>  exportSCOtoEvt(sco_pathname) sco_pathname is the .SCO file containing
        %>     directory.  User is prompted for evt output directory
        %>  exportSCOtoEvt(sco_pathname, evt_pathname) evt_pathname is the directory
        %>     where evt files are exported to.
        %> @param sco_pathname
        %> @param evt_pathname
        %  Author: Hyatt Moore IV, Stanford University
        %  Date Created: 1/9/2012
        %  modified 2/6/2012: Checked if evt_pathname exists first and, if not,
        %  creates the directory before proceeding with export
        function convertSCOtoEvt(sco_pathname, evt_pathname)
            if(nargin<1 || isempty(sco_pathname))
                sco_pathname = uigetdir(pwd,'Select .SCO (and .STA) import directory');
            end
            if(nargin<2 || isempty(evt_pathname))
                evt_pathname = uigetdir(sco_pathname,'Select .evt export directory');
            end
            
            if(~exist(evt_pathname,'dir'))
                mkdir(evt_pathname);
            end
            if(~isempty(sco_pathname) && ~isempty(evt_pathname))
                
                dirStruct = dir(fullfile(sco_pathname,'*.SCO'));
                
                if(~isempty(dirStruct))
                    filecount = numel(dirStruct);
                    filenames = cell(numel(dirStruct),1);
                    [filenames{:}] = dirStruct.name;
                end
                
                % example output file name
                %  evt.C1013_4 174933.SWA.0.txt
                evt_filename_str = 'evt.%s.%s.0.txt'; % use this in conjunction with sprintf below for each evt output file
                
                % evt header example:
                %     Event Label =	SWA
                %     EDF Channel Label(number) = 	C3-M2 (3)
                %     Start_time	Duration_seconds	Start_sample	Stop_sample	Epoch	Stage	freq	amplitude
                evt_header_str = ['Event Label =\t%s\r\nEDF Channel Label(number) =\tUnset (0)\r\n',...
                    'Start_time\tDuration_seconds\tStart_sample\tStop_sample\tEpoch\tStage\r\n'];
                
                for k=1:filecount
                    sco_filename = filenames{k};
                    study_name = strtok(sco_filename,'.'); % fileparts() would also work
                    
                    % example .STA filename:    A0097_4 174733.STA
                    %          sta_filename = [sco_filename(1:end-3),'STA'];
                    sta_filename = [study_name,'.STA'];
                    try
                        SCO = loadSCOfile(fullfile(sco_pathname,sco_filename));
                    catch me
                        showME(me);
                        rethrow(me);
                    end
                    if(~isempty(SCO))
                        
                        STA = load(fullfile(sco_pathname,sta_filename),'-ASCII'); % for ASCII file type loading
                        stages = STA(:,2); % grab the sleep stages
                        
                        % indJ contains the indices corresponding to the unique
                        % labels in event_labels (i.e. SCO.labels = event_labels(indJ)
                        SCO.label(strcmpi(SCO.label,'Obst. Apnea')) = {'Obs Apnea'};
                        [event_labels,~,indJ] = unique(SCO.label);
                        
                        for j=1:numel(event_labels)
                            try
                                evt_label = strcat('SCO_',deblank(event_labels{j}));
                                space_ind = strfind(evt_label,' ');  % remove blanks and replace tokenizing spaces
                                evt_label(space_ind) = '_';  % with an underscore for database and file naming convention conformance
                                evt_filename = fullfile(evt_pathname,sprintf(evt_filename_str,study_name,evt_label));
                                evt_indices = indJ==j;
                                start_stop_matrix = SCO.start_stop_matrix(evt_indices,:);
                                
                                duration_seconds = SCO.duration_seconds(evt_indices);
                                epochs = SCO.epoch(evt_indices);
                                
                                evt_stages = stages(epochs);  % pull out the stages of interest
                                
                                start_time = char(SCO.start_time(evt_indices));
                                
                                % this must be here to take care of the text to file  problem
                                % that pops up when we get different lengthed time
                                % stamps (i.e. it is not guaranteed to be HH:MM:SS but
                                % can be H:MM:SS too)
                                evt_content_str = [repmat('%c',1,size(start_time,2)),...
                                    '\t%0.2f',...
                                    '\t%d',...
                                    '\t%d',...
                                    '\t%d',...
                                    '\t%d',...
                                    '\r\n'];
                                
                                % Start_time\tDuration_seconds\tStart_sample\tStop_sample\tEpoch\tStage'];
                                evt_content = [start_time+0,duration_seconds,start_stop_matrix,epochs, evt_stages];
                                fout = fopen(evt_filename,'w');
                                fprintf(fout,evt_header_str, evt_label);
                                fprintf(fout,evt_content_str,evt_content');
                                fclose(fout);
                            catch ME
                                showME(ME);
                                disp(['failed on ',study_name,' for event ',evt_label]);
                            end
                            
                        end
                    end
                end
            end
        end
        
        %> @brief Returns EDF names found in a flat directory.
        %> @param edfPathname Pathname to check for EDF names.
        %> @retval dirdump
        function dirdump = getEDFNames(edfPathname)
            if(nargin <1)
                edfPathname = uigetfulldir(pwd,'Select directory containing .EDF files');
            end
            if(isdir(edfPathname))
                dirdump = dir(edfPathname);
            else
                dirdump = [];
            end
        end
        
        %> @brief Export XML format
        %> @param srcFilename
        %> @param destFilename
        %> @param exportType
        function exportXML(srcFilename,destFilename,exportType)
            
            dom = xmlread(srcFilename);
            epochLengthSec = str2double(dom.getDocumentElement.getElementsByTagName('EpochLength').item(0).getTextContent);
            
            edfFilename = strcat(destFilename,'.EDF');
            % strrep(strrep(destFilename,'.STA','.EDF'),'.SCO','.EDF');
            
            edfHDR = loadEDF(edfFilename); % get the EDF header
            
            if(strcmpi(exportType,'STA'))
                
                numEDFEpochs = ceil(edfHDR.duration_sec/epochLengthSec);
                
                sleepstages= dom.getElementsByTagName('SleepStage');
                numStages = sleepstages.getLength();
                if(numEDFEpochs~=numStages)
                    fprintf(1,'%s\texpected epochs: %u\tencountered epochs: %u\n',srcFilename,numEDFEpochs,numStages);
                end
                if(numStages>0)
                    % java's xml implementation is 0-based
                    fid = fopen(strcat(destFilename,'.STA'),'w');
                    for n=0:min(numEDFEpochs,numStages)-1
                        curStage = char(sleepstages.item(n).getTextContent);
                        if(numel(curStage)<1 || numel(curStage)>1 || curStage<'0' || curStage>'7' || curStage == '6')
                            curStage = '7';
                        end
                        fprintf(fid,'%u\t%s\n',n+1,curStage);
                    end
                    fclose(fid);
                    
                    %  stageVec = repmat(7,numEDFEpochs,1);
                    %  for n=0:min(numel(numEDFEpochs),numel(numStages))-1
                    %       stageVec(n) = str2double(sleepstages.item(n).getTextContent);
                    %  end
                    %  y = [(1:numStages)',stageVec(:)];
                    %  save(destFilename,'y','-ascii');
                end
            elseif(strcmpi(exportType,'SCO'))
                scoredEvents = dom.getElementsByTagName('ScoredEvent');
                t0 = edfHDR.T0;
                numEvents = scoredEvents.getLength;
                
                fid = fopen(strcat(destFilename,'.SCO'),'w');
                for e=0:numEvents-1
                    try
                        curEntry = scoredEvents.item(e);
                        
                        curEventName = char(curEntry.getElementsByTagName('Name').item(0).getTextContent);
                        startSec = str2double(curEntry.getElementsByTagName('Start').item(0).getTextContent);
                        
                        durationSec = char(curEntry.getElementsByTagName('Duration').item(0).getTextContent);
                        %/ if(~isnull(curEntry.getElementsByTagName('Input').item(0)))
                        %/ channelSrc = char(curEntry.getElementsByTagName('Input').item(0).getTextContent);
                        %/    -> this sometimes fails, and because it is not
                        %/       used, we will leave it out.
                        sevSamplerate = 100;
                        
                        % make sure we stay 1-based for MATLAB (MrOS studies are
                        % 0-based.
                        startSample = floor(startSec*sevSamplerate+1);
                        startTimeStr = datestr(datenum(0,0,0,0,0,startSec)+datenum(t0),'HH:MM:SS.FFF');
                        
                        durationSamples = round(str2double(durationSec)*sevSamplerate);
                        % start_epochs = sample2epoch(starts,studyStruct.standard_epoch_sec,obj.samplerate);
                        startEpoch = sample2epoch(startSample,epochLengthSec,sevSamplerate);
                        
                        
                        % this is the event category typed to the event, which has no meaning for us now, but still need this as a place holder
                        unk = '0';
                        fprintf(fid,'%u\t%u\t%u\t%c\t%s\t%c\t%s\n',startEpoch,startSample,durationSamples,unk,...
                            curEventName,unk,startTimeStr);
                        % miscellaneous values that are added in
                        % desaturationPct = curEntry.getElementsByTagName('Desaturation').item(0).getTextContent;
                        % lowestSpO2 = curEntry.getElementsByTagName('LowestSpO2').item(0).getTextContent;
                        
                        % alternative way to get around this problem.
                        %                      channelSrc = dom.getElementsByTagName('ScoredEvents').item(0).getElementsByTagName('Input').item(e).getTextContent;
                        %                      fprintf(fidOut,'');
                    catch me
                        showME(me);
                    end
                end
                fclose(fid);
            end
            
        end
        
        
        function didExport = exportFromPath(fullSrcPath, fullDestPath, methodStruct, varargin)
            try
                didExport = false;
                fullMethodName = CLASS_codec.getPackageMethodName(methodStruct.mfilename,'export');
                if(~isfield(methodStruct,'settings'))
                    methodStruct.settings = [];  % uses saved parameters when calling the fullMethodName
                end
                exportData = feval(fullMethodName,fullSrcPath,fullDestPath,methodStruct.settings, varargin{:});
                
                didExport = ~isempty(exportData) && exportData;
            catch me
                showME(me);
            end
        end
        
        function didExport = exportFromFile(fullSrcFilename, fullDestFilename, methodStruct)
            % getExportData(edfChannels,methodStructs,stagesStruct,fileInfoStruct)
            try
                didExport = false;
                fullMethodName = CLASS_codec.getPackageMethodName(methodStruct.mfilename,'export');
                methodParameters = methodStruct.settings;
                exportData = feval(fullMethodName,fullSrcFilename,fullDestFilename,methodParameters);
                didExport = ~isempty(exportData) && exportData;
            catch me
                showME(me);
            end
        end
        
        function varargout = deidentifyHDR(varargin)
            varargout{:} = EDFWriter.deidentifyHDR(varargin{:});
        end
        
        function varargout = purgeEDFHeader(varargin)
            varargout{:} = EDFWriter.purgeEDFHeader(varargin{:});
        end
        function varargout = mergeEDFHeader(varargin)
            varargout{:} = EDFWriter.mergeEDFHeader(varargin{:});
        end
        
        function varargout = extractEDFHeader(varargin)
            varargout{:} = EDFWriter.extractEDFHeader(varargin{:});
        end
        
        function success = rewriteEDFHeader(varargin)
            success = EDFWriter.rewriteEDFHeader(varargin{:});
        end
        
        function varargout = writeEDF(varargin)
            varargout{:} = EDFWriter.writeEDF(varargin{:});
        end
        
        function varargout = rewriteEDF(varargin)
            varargout{:} = EDFWriter.rewriteEDF(varargin{:});
        end
        
        function varargout = writeLiteEDF(varargin)
            varargout{:} = EDFWriter.writeLiteEDF(varargin{:});
        end
        
        function varargout = rewriteCulledEDF(varargin)
            varargout{:} = EDFWriter.rewriteCulledEDF(varargin{:});
        end
        
        %> @brief The following XML functions were taken from the Mathworks website
        %> on March 5, 2014
        %> @note Reference http://www.mathworks.com/help/matlab/ref/xmlread.html
        function theStruct = parseXML(filename)
            %  PARSEXML Convert XML file to a MATLAB structure.
            try
                tree = xmlread(filename);
            catch
                error('Failed to read XML file %s.',filename);
            end
            
            % Recurse over child nodes. This could run into problems
            % with very deeply nested trees.
            try
                theStruct = CLASS_converter.parseChildNodes(tree);
            catch
                error('Unable to parse XML file %s.',filename);
            end
        end
        
        %> @brief Local function PARSECHILDNODES
        %> @param theNode
        %> @retval children
        %> @note Reference http://www.mathworks.com/help/matlab/ref/xmlread.html
        
        function children = parseChildNodes(theNode)
            % Recurse over node children.
            children = [];
            if theNode.hasChildNodes
                childNodes = theNode.getChildNodes;
                numChildNodes = childNodes.getLength;
                allocCell = cell(1, numChildNodes);
                
                children = struct(             ...
                    'Name', allocCell, 'Attributes', allocCell,    ...
                    'Data', allocCell, 'Children', allocCell);
                
                for count = 1:numChildNodes
                    theChild = childNodes.item(count-1);
                    children(count) = CLASS_converter.makeStructFromNode(theChild);
                end
            end
        end
        
        %> @brief Local function MAKESTRUCTFROMNODE (see note)
        %> @param theNode
        %> @retval nodeStruct
        %> @note Reference http://www.mathworks.com/help/matlab/ref/xmlread.html
        function nodeStruct = makeStructFromNode(theNode)
            % Create structure of node info.
            
            nodeStruct = struct(                        ...
                'Name', char(theNode.getNodeName),       ...
                'Attributes', CLASS_converter.parseAttributes(theNode),  ...
                'Data', '',                              ...
                'Children', CLASS_converter.parseChildNodes(theNode));
            
            if any(strcmp(methods(theNode), 'getData'))
                nodeStruct.Data = char(theNode.getData);
            else
                nodeStruct.Data = '';
            end
        end
        
        %> @brief  ----- Local function PARSEATTRIBUTES  (see note)
        %> @param theNode
        %> @retval attributes
        %> @note Reference http://www.mathworks.com/help/matlab/ref/xmlread.html
        function attributes = parseAttributes(theNode)
            % Create attributes structure.
            
            attributes = [];
            if theNode.hasAttributes
                theAttributes = theNode.getAttributes;
                numAttributes = theAttributes.getLength;
                allocCell = cell(1, numAttributes);
                attributes = struct('Name', allocCell, 'Value', ...
                    allocCell);
                
                for count = 1:numAttributes
                    attrib = theAttributes.item(count-1);
                    attributes(count).Name = char(attrib.getName);
                    attributes(count).Value = char(attrib.getValue);
                end
            end
        end  % function      
        
    end % methods(static)     
end % classdef