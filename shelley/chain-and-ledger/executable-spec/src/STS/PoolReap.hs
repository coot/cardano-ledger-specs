{-# LANGUAGE EmptyDataDecls #-}
{-# LANGUAGE TypeFamilies #-}

module STS.PoolReap
  ( POOLREAP
  , PoolreapState (..)
  )
where

import qualified Data.Map.Strict as Map
import qualified Data.Set as Set

import           Lens.Micro ((^.))

import           Coin
import           Delegation.Certificates
import           LedgerState
import           PParams
import           Slot

import           Control.State.Transition
import           Control.State.Transition.Generator (HasTrace, envGen, sigGen)

import           Hedgehog (Gen)

import           Ledger.Core (dom, (∈), (∪+), (⋪), (⋫), (▷), (◁))

data POOLREAP hashAlgo dsignAlgo

data PoolreapState hashAlgo dsignAlgo =
  PoolreapState
    (UTxOState hashAlgo dsignAlgo)
    AccountState
    (DState hashAlgo dsignAlgo)
    (PState hashAlgo dsignAlgo)
  deriving (Show, Eq)

instance STS (POOLREAP hashAlgo dsignAlgo) where
  type State (POOLREAP hashAlgo dsignAlgo) = PoolreapState hashAlgo dsignAlgo
  type Signal (POOLREAP hashAlgo dsignAlgo) = Epoch
  type Environment (POOLREAP hashAlgo dsignAlgo) = PParams
  data PredicateFailure (POOLREAP hashAlgo dsignAlgo)
    = FailurePOOLREAP
    deriving (Show, Eq)
  initialRules = [pure $ PoolreapState emptyUTxOState emptyAccount emptyDState emptyPState]
  transitionRules = [poolReapTransition]

poolReapTransition :: TransitionRule (POOLREAP hashAlgo dsignAlgo)
poolReapTransition = do
  TRC (pp, PoolreapState us a ds ps, e) <- judgmentContext

  let retired = dom $ (ps ^. retiring) ▷ Set.singleton e
      relevant = retired ◁ (ps ^. pParams)
      rewardAcnts = Map.intersectionWith (\_ v -> v ^. poolRAcnt) relevant (ps ^. pParams)
      StakePools stPools' = ps ^. stPools
      pr = poolRefunds pp (retired ◁ stPools') (firstSlot e)
      refunds' = Map.fromList . Map.elems
               $ Map.intersectionWith (\coin addr -> (addr,coin)) pr rewardAcnts

      domRewards = dom (ds ^. rewards)
      (refunds, unclaimed') = Map.partitionWithKey (\k _ -> k ∈ domRewards) refunds'

      unclaimed = Map.foldl (+) (Coin 0) unclaimed'
      StakePools stakePools = ps ^. stPools
  pure $ PoolreapState
    us { _deposited = _deposited us - (unclaimed + sum (Map.elems refunds))}
    a { _treasury = _treasury a + unclaimed }
    ds { _rewards = _rewards ds ∪+ refunds
       , _delegations = _delegations ds ⋫ retired }
    ps { _stPools = StakePools $ retired ⋪ stakePools
       , _pParams = retired ⋪ _pParams ps
       , _retiring = retired ⋪ _retiring ps
       , _cCounters = retired ⋪ _cCounters ps}

instance HasTrace (POOLREAP hashAlgo dsignAlgo) where
  envGen _ = undefined :: Gen PParams
  sigGen _ _ = undefined :: Gen Epoch
