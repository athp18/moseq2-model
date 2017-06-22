import numpy as np
from autoregressive.distributions import AutoRegression
from autoregressive.models import FastARWeakLimitStickyHDPHMM, FastARWeakLimitStickyHDPHMMSeparateTrans
from kinect_modeling.util import merge_dicts
import warnings

# Empirical bayes estimate of S_0 (from MoSeq)
def _get_empirical_ar_params(train_datas, params):
    """
    Estimate the parameters of an AR observation model
    by fitting a single AR model to the entire dataset.
    """

    assert isinstance(train_datas, list) and len(train_datas) > 0
    datadimension = train_datas[0].shape[1]
    assert params["nu_0"] > datadimension + 1

    # Initialize the observation parameters
    obs_params = dict(nu_0=params["nu_0"],
                      S_0=params['S_0'],
                      M_0=params['M_0'],
                      K_0=params['K_0'],
                      affine=params['affine'])

    # Fit an AR model to the entire dataset
    obs_distn = AutoRegression(**obs_params)
    obs_distn.max_likelihood(train_datas)

    # Use the inferred noise covariance as the prior mean
    # E_{IW}[S] = S_0 / (nu_0 - datadimension - 1)
    obs_params["S_0"] = obs_distn.sigma * (params["nu_0"] - datadimension - 1)

    return obs_params


def ARHMM(data_dict, kappa=1e6, gamma=999, nlags=3,
        K_0_scale=10.0, S_0_scale=0.01, max_states=100, empirical_bayes=True,
        affine=True, model_hypparams={}, obs_hypparams={}, sticky_init=False,
        separate_trans=False, groups=None):

    warnings.filterwarnings("ignore", category=np.VisibleDeprecationWarning)
    data_dim=data_dict.values()[0].shape[1]

    default_obs_hypparams = {
        'nu_0': data_dim+2,
        'S_0': S_0_scale*np.eye(data_dim),
        'M_0': np.hstack((np.eye(data_dim),
            np.zeros((data_dim, data_dim * (nlags-1))),
            np.zeros((data_dim, int(affine))))),
        'affine': affine,
        'K_0': K_0_scale*np.eye(data_dim*nlags+affine)
        }

    default_model_hypparams = {
        'alpha': 5.7,
        'gamma': gamma,
        'kappa': kappa,
        'init_state_distn': 'uniform'
        }

    obs_hypparams=merge_dicts(default_obs_hypparams,obs_hypparams)
    model_hypparams=merge_dicts(default_model_hypparams,model_hypparams)

    # TODO: return initialization parameters for saving downstream

    if empirical_bayes:
        obs_hypparams=_get_empirical_ar_params(data_dict.values(),obs_hypparams)

    obs_distns = [AutoRegression(**obs_hypparams) for _ in range(max_states)]

    if separate_trans:
        print 'Using model class FastARWeakLimitStickyHDPHMMSeparateTrans'
        model = FastARWeakLimitStickyHDPHMMSeparateTrans(obs_distns=obs_distns, **model_hypparams)
    else:
        print 'Using model class FastARWeakLimitStickyHDPHMM'
        model = FastARWeakLimitStickyHDPHMM(obs_distns=obs_distns, **model_hypparams)

    #print(model_hypparams)

    # add ze data
    # TODO: give user the option to supply group names for separate trans,
    # for now we will just map sessions-->groups, but just make others aware of this
    # for now

    # Separate Trans is killing us on RAM, need to figure out before we use!

    for index, (data_name, data) in enumerate(data_dict.items()):
        print 'Adding data from key '+data_name
        if separate_trans:
            print 'Group ID: '+groups[index]
            model.add_data(data,group_id=groups[index])
        else:
            model.add_data(data)

    # initialize ze states per SL's recommendation

    if sticky_init:
        for i in range(0,len(model.stateseqs)):
            seqlen=len(model.stateseqs[i])
            z_init=np.random.randint(max_states, size=seqlen//10).repeat(10)
            z_init=np.append(z_init,np.random.randint(max_states, size=seqlen-len(z_init)))
            model.stateseqs[i]=z_init.copy().astype('int32')

    return model
