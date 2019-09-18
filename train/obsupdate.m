function hmm = obsupdate (T,Gamma,hmm,residuals,XX,XXGXX,Tfactor)
%
% Update observation model
%
% INPUT
% X             observations
% T             length of series
% Gamma         p(state given X)
% hmm           hmm data structure
% residuals     in case we train on residuals, the value of those.
%
% OUTPUT
% hmm           estimated HMMMAR model
%
% Author: Diego Vidaurre, OHBA, University of Oxford

K=hmm.K;

obs_tol = 0.00005;
obs_maxit = 1; %20;
mean_change = Inf;
obs_it = 1;
%fehist=0;

% Some stuff that will be later used
Gammasum = sum(Gamma);
if nargin<7, Tfactor = 1; end

if ~strcmp(hmm.train.covtype,'logistic') & ~strcmp(hmm.train.covtype,'poisson')
    while mean_change>obs_tol && obs_it<=obs_maxit

        last_state = hmm.state;

        %%% W
        [hmm,XW] = updateW(hmm,Gamma,residuals,XX,XXGXX,Tfactor);

        %%% Omega
        hmm = updateOmega(hmm,Gamma,Gammasum,residuals,T,XX,XXGXX,XW,Tfactor);

        %%% autoregression coefficient priors
        if isfield(hmm.train,'V') && ~isempty(hmm.train.V)
            %%% beta - one per autoregression coefficient
            hmm = updateBeta(hmm);
        else
            %%% sigma - channel x channel coefficients
            hmm = updateSigma(hmm);    
            %%% alpha - one per order
            hmm = updateAlpha(hmm);
        end

        %%% termination conditions
        obs_it = obs_it + 1;
        mean_changew = 0;
        for k=1:K
            mean_changew = mean_changew + ...
                sum(sum(abs(last_state(k).W.Mu_W - hmm.state(k).W.Mu_W))) / numel(hmm.state(k).W.Mu_W) / K;
        end
        mean_change = mean_changew;
    end
elseif strcmp(hmm.train.covtype,'logistic')
    % note that logistic models are slower to converge, so more iterations
    % may need to be allowed here
    obs_maxit = 1;
    if isfield(hmm,'psi')
        hmm=rmfield(hmm,'psi');
    end
    while mean_change>obs_tol && obs_it<=obs_maxit,
        
        last_state = hmm.state;
        hmm_orig=hmm;
        for iY = 1:hmm.train.logisticYdim
            hmm_marginalised = logisticMarginaliseHMM(hmm,iY);
            xdim=hmm_marginalised.train.ndim-1;
            %%% W
            [hmm_temp,~] = updateW(hmm_marginalised,Gamma,residuals(:,iY),XX(:,[1:xdim,xdim+iY]),XXGXX);
        
            %%% and hyperparameters alpha
            hmm_temp = updateAlpha(hmm_temp);
            
            hmm = logisticMergeHMM(hmm_temp,hmm,iY);
        end
        %%% termination conditions
        
        mean_changew = 0;
        for k=1:K
            mean_changew = mean_changew + ...
                sum(sum(abs(last_state(k).W.Mu_W - hmm.state(k).W.Mu_W))) / numel(hmm.state(k).W.Mu_W) / K;
        end
        mean_change = mean_changew;
        fprintf(['\nUpdating coefficients, iteration ',int2str(obs_it),', mean change ',num2str(mean_change)]);
        
        fehist(obs_it,:) = (evalfreeenergylogistic(T,Gamma,[],hmm,residuals,XX));
        fprintf(['\nObservation params updated, free energy: ',num2str(sum(fehist(obs_it,:)))]);
        obs_it = obs_it + 1;
    end
elseif strcmp(hmm.train.covtype,'poisson')
    hmm = updateW(hmm,Gamma,residuals,XX,XXGXX,Tfactor);
end
end
