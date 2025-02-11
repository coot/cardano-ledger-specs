{-# LANGUAGE EmptyDataDecls #-}
{-# LANGUAGE TypeFamilies #-}

module STS.Pool
  ( POOL
  , PoolEnv (..)
  )
where

import           Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import           Delegation.Certificates
import           Keys
import           Ledger.Core (dom, (∈), (∉), (⋪))
import           LedgerState
import           Lens.Micro ((^.))
import           PParams
import           Slot
import           TxData

import           Control.State.Transition
import           Control.State.Transition.Generator (HasTrace, envGen, sigGen)

import           Hedgehog (Gen)

data POOL hashAlgo dsignAlgo vrfAlgo

data PoolEnv =
  PoolEnv Slot PParams
  deriving (Show, Eq)

instance STS (POOL hashAlgo dsignAlgo vrfAlgo)
 where
  type State (POOL hashAlgo dsignAlgo vrfAlgo) = PState hashAlgo dsignAlgo vrfAlgo
  type Signal (POOL hashAlgo dsignAlgo vrfAlgo) = DCert hashAlgo dsignAlgo vrfAlgo
  type Environment (POOL hashAlgo dsignAlgo vrfAlgo) = PoolEnv
  data PredicateFailure (POOL hashAlgo dsignAlgo vrfAlgo)
    = StakePoolNotRegisteredOnKeyPOOL
    | StakePoolRetirementWrongEpochPOOL
    | WrongCertificateTypePOOL
    deriving (Show, Eq)

  initialRules = [pure emptyPState]
  transitionRules = [poolDelegationTransition]

poolDelegationTransition :: TransitionRule (POOL hashAlgo dsignAlgo vrfAlgo)
poolDelegationTransition = do
  TRC (PoolEnv slot pp, ps, c) <- judgmentContext
  let StakePools stPools_ = _stPools ps
  case c of
    RegPool poolParam -> do
      let hk = poolParam ^. poolPubKey

      if hk ∉ dom stPools_
        then -- register new
          pure $ ps { _stPools = StakePools $ stPools_ ∪ (hk, slot)
                    , _pParams = _pParams ps ∪ (hk, poolParam)
                    , _cCounters = _cCounters ps ∪ (hk, 0)}
        else -- re-register
          pure $ ps { _pParams = _pParams ps ⨃ (hk, poolParam)
                    , _retiring = Set.singleton hk ⋪ _retiring ps }

    RetirePool hk (Epoch e) -> do
      let Epoch cepoch   = epochFromSlot slot
          Epoch maxEpoch = pp ^. eMax

      hk ∈ dom stPools_ ?! StakePoolNotRegisteredOnKeyPOOL

      cepoch < e && e < cepoch + maxEpoch ?! StakePoolRetirementWrongEpochPOOL

      pure $ ps { _retiring = _retiring ps ⨃ (hk, Epoch e) }

    _ -> do
      failBecause WrongCertificateTypePOOL
      pure ps

-- Note: we avoid using the Relation operators (⨃) and (∪) here because that
-- would require an Ord instance for PParams, which we don't need otherwise.
-- Instead, we just define these operators here.

(⨃) :: Map (KeyHash hashAlgo dsignAlgo) a
    -> (KeyHash hashAlgo dsignAlgo, a)
    -> Map (KeyHash hashAlgo dsignAlgo) a
m ⨃ (k,v) = Map.union (Map.singleton k v) m

(∪) :: Map (KeyHash hashAlgo dsignAlgo) a
    -> (KeyHash hashAlgo dsignAlgo, a)
    -> Map (KeyHash hashAlgo dsignAlgo) a
m ∪ (k,v) = Map.union m (Map.singleton k v)

instance (HashAlgorithm hashAlgo, DSIGNAlgorithm dsignAlgo)
  => HasTrace (POOL hashAlgo dsignAlgo vrfAlgo) where
  envGen _ = undefined :: Gen PoolEnv
  sigGen _ _ = undefined :: Gen (DCert hashAlgo dsignAlgo vrfAlgo)
