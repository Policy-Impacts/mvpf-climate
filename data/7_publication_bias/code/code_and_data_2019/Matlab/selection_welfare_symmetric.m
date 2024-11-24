
% JK ENVIRO PROJECT EDIT 4/2024
function selection_welfare(gitpath,filepath)
%set seed
rng(1);

application=0;

%add code and input file paths
addpath(strcat(gitpath,'/code/code_and_data_2019/Matlab'));
cd(strcat(filepath));

%loading the data
% 1 - skip estimating betap and assume kid estimates abs(t)>1.64 are 34.48x more
% 2 - estimate break at +/-1.64 on all estimates
% 3 - estimate break at +/-1.96 on all estimates
% 4 - estimate breaks at +/-1.64 and +/-1.96 on all estimates,
samples = {'baseline_symmetric'};
thresholds = [5 10]; 
for mode = 2:4
        for s= 1:length(samples)
            for thr = 1:length(thresholds)
            sample = samples{s};
            threshold = thresholds(thr);
            outpath = strcat(filepath,'/data/corrected/MLE/mode_', string(mode));
            input_data = strcat(filepath,'/data/uncorrected/policy_masterlist_symm.csv');
            data = readtable(input_data);
            names = data.estimate;
            X = data.pe(:,1);
            sigma = data.se(:,1);
            keep_neg=1;
            cluster_ID=data.clusterid(:,1);


            estimation_condition = strcat('data.',sample);
            
            includeinestimation=logical(data.abs_t_stat<=threshold);
           % includeinestimation2 = data.abs_t_stat<=threshold
            %includeinestimation=max(includeinestimation,includeinestimation2);
            %data.abs_t_stat(:,1) ;
            %cutoff_indicator= data.abs_t_stat <= threshold;
            %includeinestimation = min(includeinestimation,cutoff_indicator);

           
            n=size(X(includeinestimation),1);
            C=ones(length(X),1);
            disp(sample)
           

 
            %Set options for estimation
            identificationapproach=2;
            GMMapproach=0;

            %Estimate baseline model, rather than running spec test
            spec_test=0;
            %Set cutoffs to use in step function: should be given in increasing order;
            Psihat0=[0,1,1];    % [mean, sd of underlying dist., betap(1), betap(2)]

           if mode < 3
                cutoffs=[-1.64 0 1.64];
                lb = [-Inf 0 0 ];
            elseif mode == 3
                cutoffs = [-1.96 0 1.96 ];
                lb = [-Inf 0 0 ];

            else
                cutoffs = [-1.96 -1.64 0 1.64 1.96 ];
                lb = [-Inf 0 0 0];
                Psihat0=[Psihat0,1];    %[mean, sd of underlying dist., betap(1), betap(2), betap(3), betap(4)]
            end

            %Use a step function  symmetric around zero
            symmetric_cutoffs = 1;
            symmetric=0;
            symmetric_p=1;
            asymmetric_likelihood_spec=1; %Use a normal model for latent distribution of true effects (spec 1)
            controls=0;
            numerical_integration=0;
            %starting values for optimization
            %estimating the model
            if mode>1
                display(strcat('mode: ',string(mode)))
                EstimatingSelection;
                display("done")
            else
                    Psihat = [0,1,1,34.48];
               

                se_robust = [0,0,0,0]';
            end

            % export to csv
            filename = strcat(outpath,'/MLE_model_parameters_',  sample, '_sample_threshold_', string(threshold), 'neg', string(keep_neg), '.csv');
            csvwrite(filename,[Psihat;se_robust']);

            % MLE estimates for the true underlying parameters
                 corrected_mle;
         
    end
    end
end  
close;
display('Publication bias estimation complete, please proceed');
end
