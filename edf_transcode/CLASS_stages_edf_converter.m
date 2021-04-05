% @brief Subclass of CLASS_edf_converter.  Contains montage configuration
% for STAGES study - multisite study.

% @author Hyatt Moore, IV
classdef CLASS_stages_edf_converter < CLASS_edf_converter
    methods(Static)
        
        function [dualchannel, singlechannel, unhandled] = getMontageConfigurations(siteName)
            if nargin<1
                siteName = 'STNF';
            end
            switch lower(siteName)
                case 'stnf'
                    [dualchannel, singlechannel, unhandled] = CLASS_stages_edf_converter.getSTNF();
                otherwise
                    error('Unrecognized site label: %s', siteName)
            end
        end
        function [dualchannel, singlechannel, unhandled] = getSTNF()
            unhandled = {};
            dualchannel = {
                {'LAT','RAT','LAT-RAT'};
                {'ECG','ECG 2','EKG'}   ;
                {'ECG','ECG II','EKG'}   ;
                };
            
            singlechannel = {
                {'wPLMl','PLMl','PLMl.','LAT'};
                {'wPLMr','PLMr','PLMr.','RAT'};
                {'EKG1-EKG2','LLEG1-EKG2','ECG','EKG'};
                };
        end
    end
end