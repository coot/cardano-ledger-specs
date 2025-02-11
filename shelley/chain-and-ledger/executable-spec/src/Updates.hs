{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LambdaCase #-}

module Updates
  ( Ppm(..)
  , PPUpdateEnv(..)
  , PPUpdate(..)
  , updatePPup
  , ApName(..)
  , ApVer(..)
  , Mdt(..)
  , SystemTag(..)
  , InstallerHash(..)
  , Applications(..)
  , AVUpdate(..)
  , Update(..)
  , UpdateState(..)
  , Favs
  , apNameValid
  , allNames
  , newAVs
  , votedValue
  , emptyUpdateState
  , emptyUpdate
  , updatePParams
  , svCanFollow
  , sTagsValid
  )
where

import           Data.ByteString (ByteString)
import           Data.ByteString.Char8 (unpack)
import           Data.Char (isAscii)
import qualified Data.List as List (group)
import           Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import           Data.Set (Set)
import qualified Data.Set as Set
import           Data.Word (Word8)
import           GHC.Generics (Generic)

import           Cardano.Binary (ToCBOR (toCBOR), encodeListLen)
import           Cardano.Crypto.Hash (Hash, HashAlgorithm)
import           Cardano.Prelude (NoUnexpectedThunks(..))

import           BaseTypes (Nonce, UnitInterval)
import           Coin (Coin)
import           Keys (DSIGNAlgorithm, GenDelegs, GenKeyHash)
import           PParams (PParams (..))
import           Slot (Epoch, Slot)

import           Numeric.Natural (Natural)

import           Ledger.Core (dom, range, (∪), (◁))

newtype ApVer = ApVer Natural
  deriving (Show, Ord, Eq, NoUnexpectedThunks, ToCBOR)

newtype ApName = ApName ByteString
  deriving (Show, Ord, Eq, ToCBOR, NoUnexpectedThunks)

newtype SystemTag = SystemTag ByteString
  deriving (Show, Ord, Eq, ToCBOR, NoUnexpectedThunks)

newtype InstallerHash hashAlgo = InstallerHash (Hash hashAlgo ByteString)
  deriving (Show, Ord, Eq, ToCBOR, NoUnexpectedThunks)

newtype Mdt hashAlgo = Mdt (Map SystemTag (InstallerHash hashAlgo))
  deriving (Show, Ord, Eq, ToCBOR, NoUnexpectedThunks)

newtype Applications hashAlgo = Applications {
  apps :: Map ApName (ApVer, Mdt hashAlgo)
  } deriving (Show, Ord, Eq, ToCBOR, NoUnexpectedThunks)

newtype AVUpdate hashAlgo dsignAlgo = AVUpdate {
  aup :: Map (GenKeyHash hashAlgo dsignAlgo) (Applications hashAlgo)
  } deriving (Show, Eq, ToCBOR, NoUnexpectedThunks)

-- | Update Proposal
data Update hashAlgo dsignAlgo
  = Update (PPUpdate hashAlgo dsignAlgo) (AVUpdate hashAlgo dsignAlgo)
  deriving (Show, Eq, Generic)

instance NoUnexpectedThunks (Update hashAlgo dsignAlgo)

instance (HashAlgorithm hashAlgo, DSIGNAlgorithm dsignAlgo) => ToCBOR (Update hashAlgo dsignAlgo) where
  toCBOR (Update ppUpdate avUpdate) =
    encodeListLen 2 <> toCBOR ppUpdate <> toCBOR avUpdate

data PPUpdateEnv hashAlgo dsignAlgo = PPUpdateEnv {
    slot :: Slot
  , genDelegs  :: GenDelegs hashAlgo dsignAlgo
  } deriving (Show, Eq, Generic)

instance NoUnexpectedThunks (PPUpdateEnv hashAlgo dsignAlgo)

data Ppm = MinFeeA Integer
  | MinFeeB Natural
  | MaxBBSize Natural
  | MaxTxSize Natural
  | KeyDeposit Coin
  | KeyMinRefund UnitInterval
  | KeyDecayRate Rational
  | PoolDeposit Coin
  | PoolMinRefund UnitInterval
  | PoolDecayRate Rational
  | EMax Epoch
  | Nopt Natural
  | A0 Rational
  | Rho UnitInterval
  | Tau UnitInterval
  | ActiveSlotCoefficient UnitInterval
  | D UnitInterval
  | ExtraEntropy Nonce
  | ProtocolVersion (Natural, Natural, Natural)
  deriving (Show, Ord, Eq, Generic)

instance NoUnexpectedThunks Ppm

instance ToCBOR Ppm where
  toCBOR = \case
    MinFeeA a -> encodeListLen 2 <> toCBOR (0 :: Word8) <> toCBOR a

    MinFeeB b -> encodeListLen 2 <> toCBOR (1 :: Word8) <> toCBOR b

    MaxBBSize maxBBSize ->
      encodeListLen 2 <> toCBOR (2 :: Word8) <> toCBOR maxBBSize

    MaxTxSize maxTxSize ->
      encodeListLen 2 <> toCBOR (3 :: Word8) <> toCBOR maxTxSize

    KeyDeposit keyDeposit ->
      encodeListLen 2 <> toCBOR (4 :: Word8) <> toCBOR keyDeposit

    KeyMinRefund keyMinRefund ->
      encodeListLen 2 <> toCBOR (5 :: Word8) <> toCBOR keyMinRefund

    KeyDecayRate keyDecayRate ->
      encodeListLen 2 <> toCBOR (6 :: Word8) <> toCBOR keyDecayRate

    PoolDeposit poolDeposit ->
      encodeListLen 2 <> toCBOR (7 :: Word8) <> toCBOR poolDeposit

    PoolMinRefund poolMinRefund ->
      encodeListLen 2 <> toCBOR (8 :: Word8) <> toCBOR poolMinRefund

    PoolDecayRate poolDecayRate ->
      encodeListLen 2 <> toCBOR (9 :: Word8) <> toCBOR poolDecayRate

    EMax eMax -> encodeListLen 2 <> toCBOR (10 :: Word8) <> toCBOR eMax

    Nopt nopt -> encodeListLen 2 <> toCBOR (11 :: Word8) <> toCBOR nopt

    A0   a0   -> encodeListLen 2 <> toCBOR (12 :: Word8) <> toCBOR a0

    Rho  rho  -> encodeListLen 2 <> toCBOR (13 :: Word8) <> toCBOR rho

    Tau  tau  -> encodeListLen 2 <> toCBOR (14 :: Word8) <> toCBOR tau

    ActiveSlotCoefficient activeSlotCoeff ->
      encodeListLen 2 <> toCBOR (15 :: Word8) <> toCBOR activeSlotCoeff

    D d -> encodeListLen 2 <> toCBOR (16 :: Word8) <> toCBOR d

    ExtraEntropy extraEntropy ->
      encodeListLen 2 <> toCBOR (17 :: Word8) <> toCBOR extraEntropy

    ProtocolVersion protocolVersion ->
      encodeListLen 2 <> toCBOR (18 :: Word8) <> toCBOR protocolVersion

newtype PPUpdate hashAlgo dsignAlgo
  = PPUpdate (Map (GenKeyHash hashAlgo dsignAlgo) (Set Ppm))
  deriving (Show, Eq, ToCBOR, NoUnexpectedThunks)

-- | Update Protocol Parameter update with new values, prefer value from `pup1`
-- in case of already existing value in `pup0`
updatePPup
  :: PPUpdate hashAlgo dsignAlgo
  -> PPUpdate hashAlgo dsignAlgo
  -> PPUpdate hashAlgo dsignAlgo
updatePPup (PPUpdate pup0') (PPUpdate pup1') = PPUpdate (pup1' ∪ pup0')

-- | This is just an example and not neccessarily how we will actually validate names
apNameValid :: ApName -> Bool
apNameValid (ApName an) = all isAscii cs && length cs <= 12
  where cs = unpack an

-- | This is just an example and not neccessarily how we will actually validate system tags
sTagValid :: SystemTag -> Bool
sTagValid (SystemTag st) = all isAscii cs && length cs <= 10
  where cs = unpack st

sTagsValid :: Mdt hashAlgo -> Bool
sTagsValid (Mdt md) = all sTagValid (dom md)

type Favs hashAlgo = Map Slot (Applications hashAlgo)

maxVer :: ApName -> Applications hashAlgo -> Favs hashAlgo -> (ApVer, Mdt hashAlgo)
maxVer an avs favs =
  maximum $ vs an avs : fmap (vs an) (Set.toList (range favs))
    where
      vs n (Applications as) =
        Map.foldr max (ApVer 0, Mdt Map.empty) (Set.singleton n ◁ as)

svCanFollow :: Applications hashAlgo -> Favs hashAlgo -> (ApName, (ApVer, Mdt hashAlgo)) -> Bool
svCanFollow avs favs (an, (ApVer v, _)) = v == 1 + m
  where (ApVer m) = fst $ maxVer an avs favs

allNames :: Applications hashAlgo -> Favs hashAlgo -> Set ApName
allNames (Applications avs) favs =
  Prelude.foldr
    (\(Applications fav) acc -> acc `Set.union` Map.keysSet fav)
    (Map.keysSet avs)
    (Map.elems favs)

newAVs :: Applications hashAlgo -> Favs hashAlgo -> Applications hashAlgo
newAVs avs favs = Applications $
                    Map.fromList [(an, maxVer an avs favs) | an <- Set.toList $ allNames avs favs]

votedValue
  :: Eq a => Map (GenKeyHash hashAlgo dsignAlgo) a -> Maybe a
votedValue vs | null elemLists = Nothing
              | otherwise      = Just $ (head . head) elemLists  -- elemLists contains an element
                                               -- and that list contains at
                                               -- least 5 elements


 where
  elemLists =
    filter (\l -> length l >= 5) $ List.group $ map snd $ Map.toList vs

emptyUpdateState :: UpdateState hashAlgo dsignAlgo
emptyUpdateState = UpdateState
                     (PPUpdate Map.empty)
                     (AVUpdate Map.empty)
                     Map.empty
                     (Applications Map.empty)

emptyUpdate :: Update hashAlgo dsignAlgo
emptyUpdate = Update (PPUpdate Map.empty) (AVUpdate Map.empty)

updatePParams :: PParams -> Set Ppm -> PParams
updatePParams = Set.foldr updatePParams'
 where
  updatePParams' (MinFeeA               p) pps = pps { _minfeeA = p }
  updatePParams' (MinFeeB               p) pps = pps { _minfeeB = p }
  updatePParams' (MaxBBSize             p) pps = pps { _maxBBSize = p }
  updatePParams' (MaxTxSize             p) pps = pps { _maxTxSize = p }
  updatePParams' (KeyDeposit            p) pps = pps { _keyDeposit = p }
  updatePParams' (KeyMinRefund          p) pps = pps { _keyMinRefund = p }
  updatePParams' (KeyDecayRate          p) pps = pps { _keyDecayRate = p }
  updatePParams' (PoolDeposit           p) pps = pps { _poolDeposit = p }
  updatePParams' (PoolMinRefund         p) pps = pps { _poolMinRefund = p }
  updatePParams' (PoolDecayRate         p) pps = pps { _poolDecayRate = p }
  updatePParams' (EMax                  p) pps = pps { _eMax = p }
  updatePParams' (Nopt                  p) pps = pps { _nOpt = p }
  updatePParams' (A0                    p) pps = pps { _a0 = p }
  updatePParams' (Rho                   p) pps = pps { _rho = p }
  updatePParams' (Tau                   p) pps = pps { _tau = p }
  updatePParams' (ActiveSlotCoefficient p) pps = pps { _activeSlotCoeff = p }
  updatePParams' (D                     p) pps = pps { _d = p }
  updatePParams' (ExtraEntropy          p) pps = pps { _extraEntropy = p }
  updatePParams' (ProtocolVersion       p) pps = pps { _protocolVersion = p }

data UpdateState hashAlgo dsignAlgo
  = UpdateState
      (PPUpdate hashAlgo dsignAlgo)
      (AVUpdate hashAlgo dsignAlgo)
      (Map Slot (Applications hashAlgo))
      (Applications hashAlgo)
  deriving (Show, Eq, Generic)

instance NoUnexpectedThunks (UpdateState hashAlgo dsignAlgo)
