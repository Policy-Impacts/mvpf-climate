
% JK ENVIRO PROJECT EDIT 4/2024
function selection_welfare_old(gitpath,filepath)
%set seed
rng(1);

application=0;

%add code and input file paths
addpath(strcat(gitpath,'/code/code_and_data_2019/Matlab'));
cd(strcat(filepath));
            sample = 'RD_simple';
            outpath = strcat(filepath,'/data/corrected/output');
            input_data = strcat(filepath,'/data/uncorrected/policy_masterlist_symm.csv');
            data = readtable(input_data);
            names = data.estimate;
            X = data.pe(:,1);
            sigma = data.se(:,1);
            keep_neg=1;
            cluster_ID=data.clusterid(:,1);
            pub_bias = data.estimated_bias(:,1);
            pub_bias = mean(pub_bias);
            cutoffs = [-1.96, 1.96];
            simple = 1;
            symmetric_cutoffs = 1;
            symmetric_p = 0;
            n=size(X,1);
            C=ones(length(X),1);
            disp(sample)
            Psihat = [0,1,pub_bias];
            se_robust = [0,0,0,0]';
            

            % export to csv
            % MLE estimates for the true underlying parameters
                 corrected_mle;
           % version with fixed 35x ish
           sample = '35x';
                Psihat = [0,1,34.48];
               

                se_robust = [0,0,0,0]';
            

            % export to csv
            % MLE estimates for the true underlying parameters
                 corrected_mle;

         
  
close;
display('Publication bias estimation complete, please proceed');
end
