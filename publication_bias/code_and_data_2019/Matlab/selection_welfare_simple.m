
function selection_welfare(gitpath,filepath, threshold, mode)
%set seed
rng(1);

application=0;

%add code and input file paths
addpath(strcat(gitpath,'/code_and_data_2019/Matlab'));
% run the code with our estimated pub bias from RD-like spec
cd(strcat(filepath));
            sample = 'RD_simple';
            outpath = strcat(filepath,'/data/corrected/output');
            input_data = strcat(filepath,'/data/uncorrected/policy_masterlist.csv');
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
  
         
 % now run AK (2019) spec to estimate pub bias. we run winsorizing t-stats
 % above 5 and using the cutoff at 1.96 with symmetric pub bias regardless
 % of sign but get similar reults with other specs.
            
            includeinestimation=logical(data.abs_t_stat<=threshold);           
            n=size(X(includeinestimation),1);
            C=ones(length(X),1);
           
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
            filename = strcat(outpath,'/MLE_model_parameters_',  'threshold_', string(threshold), '_mode_', string(mode), '.csv');
            csvwrite(filename,[Psihat;se_robust']);

end
