{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}

module TxData
  where

import           Cardano.Binary (FromCBOR (fromCBOR), ToCBOR (toCBOR), decodeListLen, decodeWord,
                     encodeListLen, encodeWord)
import           Cardano.Prelude (NoUnexpectedThunks (..))

import           Lens.Micro.TH (makeLenses)

import           Data.Foldable (toList)
import           Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import           Data.Ord (comparing)
import           Data.Sequence (Seq)
import           Data.Set (Set)
import           Data.Typeable (Typeable)
import           Data.Word (Word8)
import           GHC.Generics (Generic)
import           Numeric.Natural (Natural)

import           BaseTypes (UnitInterval)
import           Coin (Coin)
import           Keys (AnyKeyHash, pattern AnyKeyHash, DSIGNAlgorithm, GenKeyHash, Hash,
                     HashAlgorithm, KeyHash, Sig, VKey, VKeyGenesis, VRFAlgorithm (VerKeyVRF),
                     hashAnyKey)
import           Ledger.Core (Relation (..))
import           Slot (Epoch, Slot)
import           Updates (Update)

-- |The delegation of one stake key to another.
data Delegation hashAlgo dsignAlgo = Delegation
  { _delegator :: Credential hashAlgo dsignAlgo
  , _delegatee :: KeyHash hashAlgo dsignAlgo
  } deriving (Eq, Generic, Show)

instance NoUnexpectedThunks (Delegation hashAlgo dsignAlgo)

-- |A stake pool.
data PoolParams hashAlgo dsignAlgo vrfAlgo =
  PoolParams
    { _poolPubKey  :: KeyHash hashAlgo dsignAlgo
    , _poolVrf     :: Hash hashAlgo (VerKeyVRF vrfAlgo)
    , _poolPledge  :: Coin
    , _poolCost    :: Coin
    , _poolMargin  :: UnitInterval
    , _poolRAcnt   :: RewardAcnt hashAlgo dsignAlgo
    , _poolOwners  :: Set (KeyHash hashAlgo dsignAlgo)
    } deriving (Show, Generic, Eq)

instance NoUnexpectedThunks (PoolParams hashAlgo dsignAlgo vrfAlgo)

-- |An account based address for rewards
newtype RewardAcnt hashAlgo signAlgo = RewardAcnt
  { getRwdCred :: StakeCredential hashAlgo signAlgo
  } deriving (Show, Eq, NoUnexpectedThunks, Ord)

-- | Script hash or key hash for a payment or a staking object.
data Credential hashAlgo dsignAlgo =
    ScriptHashObj { _validatorHash :: ScriptHash hashAlgo dsignAlgo }
  | KeyHashObj    { _vkeyHash      :: KeyHash hashAlgo dsignAlgo }
  | GenesisHashObj { _genKeyHash   :: GenKeyHash hashAlgo dsignAlgo }
    deriving (Show, Eq, Generic, Ord)

instance NoUnexpectedThunks (Credential hashAlgo dsignAlgo)

-- |An address for UTxO.
data Addr hashAlgo dsignAlgo
  = AddrBase
      { _paymentObj :: Credential hashAlgo dsignAlgo
      , _stakingObj :: Credential hashAlgo dsignAlgo
      }
  | AddrEnterprise
    { _enterprisePayment :: Credential hashAlgo dsignAlgo }
  | AddrPtr
      { _paymentObjP :: Credential hashAlgo dsignAlgo
      , _stakePtr :: Ptr
      }
  deriving (Show, Eq, Ord, Generic)

instance NoUnexpectedThunks (Addr hashAlgo dsignAlgo)

type Ix  = Natural

-- | Pointer to a slot, transaction index and index in certificate list.
data Ptr
  = Ptr Slot Ix Ix
  deriving (Show, Eq, Ord, Generic)

instance NoUnexpectedThunks Ptr

-- | A simple language for expressing conditions under which it is valid to
-- withdraw from a normal UTxO payment address or to use a stake address.
--
-- The use case is for expressing multi-signature payment addresses and
-- multi-signature stake addresses. These can be combined arbitrarily using
-- logical operations:
--
-- * multi-way \"and\";
-- * multi-way \"or\";
-- * multi-way \"N of M\".
--
-- This makes it easy to express multi-signature addresses, and provides an
-- extension point to express other validity conditions, e.g., as needed for
-- locking funds used with lightning.
--
data MultiSig hashAlgo dsignAlgo =
       -- | Require the redeeming transaction be witnessed by the spending key
       --   corresponding to the given verification key hash.
       RequireSignature   (AnyKeyHash hashAlgo dsignAlgo)

       -- | Require all the sub-terms to be satisfied.
     | RequireAllOf      [MultiSig hashAlgo dsignAlgo]

       -- | Require any one of the sub-terms to be satisfied.
     | RequireAnyOf      [MultiSig hashAlgo dsignAlgo]

       -- | Require M of the given sub-terms to be satisfied.
     | RequireMOf    Int [MultiSig hashAlgo dsignAlgo]
  deriving (Show, Eq, Ord, Generic)

instance NoUnexpectedThunks (MultiSig hashAlgo dsignAlgo)

newtype ScriptHash hashAlgo dsignAlgo =
  ScriptHash (Hash hashAlgo (MultiSig hashAlgo dsignAlgo))
  deriving (Show, Eq, Ord, NoUnexpectedThunks, ToCBOR)

type Wdrl hashAlgo dsignAlgo = Map (RewardAcnt hashAlgo dsignAlgo) Coin

-- |A unique ID of a transaction, which is computable from the transaction.
newtype TxId hashAlgo dsignAlgo vrfAlgo
  = TxId { _TxId :: Hash hashAlgo (TxBody hashAlgo dsignAlgo vrfAlgo) }
  deriving (Show, Eq, Ord, NoUnexpectedThunks, ToCBOR)

-- |The input of a UTxO.
data TxIn hashAlgo dsignAlgo vrfAlgo
  = TxIn (TxId hashAlgo dsignAlgo vrfAlgo) Natural
  deriving (Show, Eq, Generic, Ord)

instance NoUnexpectedThunks (TxIn hashAlgo dsignAlgo vrfAlgo)

-- |The output of a UTxO.
data TxOut hashAlgo dsignAlgo
  = TxOut (Addr hashAlgo dsignAlgo) Coin
  deriving (Show, Eq, Generic, Ord)

instance NoUnexpectedThunks (TxOut hashAlgo dsignAlgo)

type StakeCredential hashAlgo dsignAlgo = Credential hashAlgo dsignAlgo

-- | A heavyweight certificate.
data DCert hashAlgo dsignAlgo vrfAlgo
    -- | A stake key registration certificate.
  = RegKey (StakeCredential hashAlgo dsignAlgo)
    -- | A stake key deregistration certificate.
  | DeRegKey (StakeCredential hashAlgo dsignAlgo)
    -- | A stake pool registration certificate.
  | RegPool (PoolParams hashAlgo dsignAlgo vrfAlgo)
    -- | A stake pool retirement certificate.
  | RetirePool (KeyHash hashAlgo dsignAlgo) Epoch
    -- | A stake delegation certificate.
  | Delegate (Delegation hashAlgo dsignAlgo)
    -- | Genesis key delegation certificate
  | GenesisDelegate (GenKeyHash hashAlgo dsignAlgo, KeyHash hashAlgo dsignAlgo)
    -- | Move instantaneous rewards certificate
  | InstantaneousRewards (Map (Credential hashAlgo dsignAlgo) Coin)
  deriving (Show, Generic, Eq)

instance NoUnexpectedThunks (DCert hashAlgo dsignAlgo vrfAlgo)

-- |A raw transaction
data TxBody hashAlgo dsignAlgo vrfAlgo
  = TxBody
      { _inputs   :: !(Set (TxIn hashAlgo dsignAlgo vrfAlgo))
      , _outputs  :: [TxOut hashAlgo dsignAlgo]
      , _certs    :: Seq (DCert hashAlgo dsignAlgo vrfAlgo)
      , _wdrls    :: Wdrl hashAlgo dsignAlgo
      , _txfee    :: Coin
      , _ttl      :: Slot
      , _txUpdate :: Update hashAlgo dsignAlgo
      } deriving (Show, Eq, Generic)

instance NoUnexpectedThunks (TxBody hashAlgo dsignAlgo vrfAlgo)

-- |Proof/Witness that a transaction is authorized by the given key holder.
data WitVKey hashAlgo dsignAlgo vrfAlgo
  = WitVKey (VKey dsignAlgo) !(Sig dsignAlgo (TxBody hashAlgo dsignAlgo vrfAlgo))
  | WitGVKey (VKeyGenesis dsignAlgo) !(Sig dsignAlgo (TxBody hashAlgo dsignAlgo vrfAlgo))
  deriving (Show, Eq, Generic)

instance (DSIGNAlgorithm dsignAlgo)
  => NoUnexpectedThunks (WitVKey hashAlgo dsignAlgo vrfAlgo)

witKeyHash
  :: forall hashAlgo dsignAlgo vrfAlgo. (DSIGNAlgorithm dsignAlgo, HashAlgorithm hashAlgo)
  => WitVKey hashAlgo dsignAlgo vrfAlgo
  -> AnyKeyHash hashAlgo dsignAlgo
witKeyHash (WitVKey key _) = hashAnyKey key
witKeyHash (WitGVKey key _) = hashAnyKey key

instance forall hashAlgo dsignAlgo vrfAlgo
  . (DSIGNAlgorithm dsignAlgo, HashAlgorithm hashAlgo)
  => Ord (WitVKey hashAlgo dsignAlgo vrfAlgo) where
    compare = comparing witKeyHash

-- |A fully formed transaction.
data Tx hashAlgo dsignAlgo vrfAlgo
  = Tx
      { _body           :: !(TxBody hashAlgo dsignAlgo vrfAlgo)
      , _witnessVKeySet :: !(Set (WitVKey hashAlgo dsignAlgo vrfAlgo))
      , _witnessMSigMap ::
          Map (ScriptHash hashAlgo dsignAlgo) (MultiSig hashAlgo dsignAlgo)
      } deriving (Show, Eq, Generic)

instance (DSIGNAlgorithm dsignAlgo)
  => NoUnexpectedThunks (Tx hashAlgo dsignAlgo vrfAlgo)

newtype StakeCreds hashAlgo dsignAlgo =
  StakeCreds (Map (StakeCredential hashAlgo dsignAlgo) Slot)
  deriving (Show, Eq, NoUnexpectedThunks)

newtype StakePools hashAlgo dsignAlgo =
  StakePools (Map (KeyHash hashAlgo dsignAlgo) Slot)
  deriving (Show, Eq, NoUnexpectedThunks)


-- CBOR

instance
  (HashAlgorithm hashAlgo, DSIGNAlgorithm dsignAlgo, VRFAlgorithm vrfAlgo)
  => ToCBOR (DCert hashAlgo dsignAlgo vrfAlgo)
 where
  toCBOR = \case
    RegKey vk ->
      encodeListLen 2
        <> toCBOR (0 :: Word8)
        <> toCBOR vk

    DeRegKey vk ->
      encodeListLen 2
        <> toCBOR (1 :: Word8)
        <> toCBOR vk

    RegPool poolParams ->
      encodeListLen 2
        <> toCBOR (2 :: Word8)
        <> toCBOR poolParams

    RetirePool vk epoch ->
      encodeListLen 3
        <> toCBOR (3 :: Word8)
        <> toCBOR vk
        <> toCBOR epoch

    Delegate delegation ->
      encodeListLen 2
        <> toCBOR (4 :: Word8)
        <> toCBOR delegation

    GenesisDelegate keys ->
      encodeListLen 2
        <> toCBOR (5 :: Word8)
        <> toCBOR keys

    InstantaneousRewards credCoinMap ->
      encodeListLen 2
        <> toCBOR (6 :: Word8)
        <> toCBOR credCoinMap

instance
  (Typeable dsignAlgo, HashAlgorithm hashAlgo, VRFAlgorithm vrfAlgo)
  => ToCBOR (TxIn hashAlgo dsignAlgo vrfAlgo)
 where
  toCBOR (TxIn txId index) =
    encodeListLen 2
      <> toCBOR txId
      <> toCBOR index

instance
  (Typeable dsignAlgo, HashAlgorithm hashAlgo)
  => ToCBOR (TxOut hashAlgo dsignAlgo)
 where
  toCBOR (TxOut addr coin) =
    encodeListLen 2
      <> toCBOR addr
      <> toCBOR coin

instance
  (Typeable hashAlgo, DSIGNAlgorithm dsignAlgo, VRFAlgorithm vrfAlgo)
  => ToCBOR (WitVKey hashAlgo dsignAlgo vrfAlgo)
 where
  toCBOR (WitVKey vk sig) =
    encodeListLen 2
      <> toCBOR vk
      <> toCBOR sig
  toCBOR (WitGVKey vk sig) =
    encodeListLen 2
      <> toCBOR vk
      <> toCBOR sig


instance
  (HashAlgorithm hashAlgo, DSIGNAlgorithm dsignAlgo, VRFAlgorithm vrfAlgo)
  => ToCBOR (Tx hashAlgo dsignAlgo vrfAlgo)
 where
  toCBOR tx =
    encodeListLen 2
      <> toCBOR (_body tx)
      <> toCBOR (_witnessVKeySet tx)
      <> toCBOR (_witnessMSigMap tx)

instance
  (HashAlgorithm hashAlgo, DSIGNAlgorithm dsignAlgo, VRFAlgorithm vrfAlgo)
  => ToCBOR (TxBody hashAlgo dsignAlgo vrfAlgo)
 where
  toCBOR txbody =
    encodeListLen 6
      <> toCBOR (_inputs txbody)
      <> toCBOR (_outputs txbody)
      <> toCBOR (toList $ _certs txbody)
      <> toCBOR (_wdrls txbody)
      <> toCBOR (_txfee txbody)
      <> toCBOR (_ttl txbody)
      <> toCBOR (_txUpdate txbody)

instance (DSIGNAlgorithm dsignAlgo, HashAlgorithm hashAlgo) =>
  ToCBOR (MultiSig hashAlgo dsignAlgo) where
  toCBOR (RequireSignature hk) =
    encodeListLen 2 <> encodeWord 0 <> toCBOR hk
  toCBOR (RequireAllOf msigs) =
    encodeListLen 2 <> encodeWord 1 <> toCBOR msigs
  toCBOR (RequireAnyOf msigs) =
    encodeListLen 2 <> encodeWord 2 <> toCBOR msigs
  toCBOR (RequireMOf m msigs) =
    encodeListLen 3 <> encodeWord 3 <> toCBOR m <> toCBOR msigs

instance (DSIGNAlgorithm dsignAlgo, HashAlgorithm hashAlgo) =>
  FromCBOR (MultiSig hashAlgo dsignAlgo) where
  fromCBOR = do
    _ <- decodeListLen
    ctor <- decodeWord
    case ctor of
      0 -> do
       hk <- AnyKeyHash <$> fromCBOR
       pure $ RequireSignature hk
      1 -> do
        msigs <- fromCBOR
        pure $ RequireAllOf msigs
      2 -> do
        msigs <- fromCBOR
        pure $ RequireAnyOf msigs
      3 -> do
        m     <- fromCBOR
        msigs <- fromCBOR
        pure $ RequireMOf m msigs
      _ -> error "pattern no supported"

instance (Typeable dsignAlgo, HashAlgorithm hashAlgo)
  => ToCBOR (Credential hashAlgo dsignAlgo) where
  toCBOR = \case
    ScriptHashObj hs ->
      encodeListLen 2
      <> toCBOR (0 :: Word8)
      <> toCBOR hs
    KeyHashObj kh ->
      encodeListLen 2
      <> toCBOR (1 :: Word8)
      <> toCBOR kh
    GenesisHashObj kh ->
      encodeListLen 2
      <> toCBOR (2 :: Word8)
      <> toCBOR kh

instance
  (Typeable dsignAlgo, HashAlgorithm hashAlgo)
  => ToCBOR (Addr hashAlgo dsignAlgo)
 where
  toCBOR = \case
    AddrBase pay stake ->
      encodeListLen 3
        <> toCBOR (0 :: Word8)
        <> toCBOR pay
        <> toCBOR stake
    AddrEnterprise pay ->
      encodeListLen 2
        <> toCBOR (1 :: Word8)
        <> toCBOR pay
    AddrPtr pay stakePtr ->
      encodeListLen 3
        <> toCBOR (2 :: Word8)
        <> toCBOR pay
        <> toCBOR stakePtr

instance ToCBOR Ptr where
  toCBOR (Ptr sl txIx certIx) =
    encodeListLen 3
      <> toCBOR sl
      <> toCBOR txIx
      <> toCBOR certIx

instance (HashAlgorithm hashAlgo, DSIGNAlgorithm dsignAlgo) =>
  ToCBOR (Delegation hashAlgo dsignAlgo) where
  toCBOR delegation =
    encodeListLen 2
      <> toCBOR (_delegator delegation)
      <> toCBOR (_delegatee delegation)


instance
  (HashAlgorithm hashAlgo, DSIGNAlgorithm dsignAlgo, VRFAlgorithm vrfAlgo)
  => ToCBOR (PoolParams hashAlgo dsignAlgo vrfAlgo)
 where
  toCBOR poolParams =
    encodeListLen 7
      <> toCBOR (_poolPubKey poolParams)
      <> toCBOR (_poolVrf poolParams)
      <> toCBOR (_poolPledge poolParams)
      <> toCBOR (_poolCost poolParams)
      <> toCBOR (_poolMargin poolParams)
      <> toCBOR (_poolRAcnt poolParams)
      <> toCBOR (_poolOwners poolParams)

instance (HashAlgorithm hashAlgo, DSIGNAlgorithm dsignAlgo)
  => ToCBOR (RewardAcnt hashAlgo dsignAlgo) where
  toCBOR rwdAcnt =
    encodeListLen 1
      <> toCBOR (getRwdCred rwdAcnt)

instance Relation (StakeCreds hashAlgo dsignAlgo) where
  type Domain (StakeCreds hashAlgo dsignAlgo) = StakeCredential hashAlgo dsignAlgo
  type Range (StakeCreds hashAlgo dsignAlgo)  = Slot

  singleton k v = StakeCreds $ Map.singleton k v

  dom (StakeCreds stkCreds) = dom stkCreds

  range (StakeCreds stkCreds) = range stkCreds

  s ◁ (StakeCreds stkCreds) = StakeCreds $ s ◁ stkCreds

  s ⋪ (StakeCreds stkCreds) = StakeCreds $ s ⋪ stkCreds

  (StakeCreds stkCreds) ▷ s = StakeCreds $ stkCreds ▷ s

  (StakeCreds stkCreds) ⋫ s = StakeCreds $ stkCreds ⋫ s

  (StakeCreds a) ∪ (StakeCreds b) = StakeCreds $ a ∪ b

  (StakeCreds a) ⨃ b = StakeCreds $ a ⨃ b

  vmax <=◁ (StakeCreds stkCreds) = StakeCreds $ vmax <=◁ stkCreds

  (StakeCreds stkCreds) ▷<= vmax = StakeCreds $ stkCreds ▷<= vmax

  (StakeCreds stkCreds) ▷>= vmin = StakeCreds $ stkCreds ▷>= vmin

  size (StakeCreds stkCreds) = size stkCreds

-- Lenses

makeLenses ''TxBody

makeLenses ''Tx

makeLenses ''Delegation

makeLenses ''PoolParams
