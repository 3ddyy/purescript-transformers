module Control.Monad.Error.Trans where

import Prelude
import Control.Monad.Error
import Control.Monad.Trans
import Data.Either
import Data.Monoid
import Data.Tuple

data ErrorT e m a = ErrorT (m (Either e a))

runErrorT :: forall e m a. ErrorT e m a -> m (Either e a)
runErrorT (ErrorT x) = x

mapErrorT :: forall e1 e2 m1 m2 a b. (m1 (Either e1 a) -> m2 (Either e2 b)) -> ErrorT e1 m1 a -> ErrorT e2 m2 b
mapErrorT f m = ErrorT $ f (runErrorT m)

instance monadErrorT :: (Monad m, Error e) => Monad (ErrorT e m) where
  return a = ErrorT $ return $ Right a
  (>>=) m f = ErrorT $ do
    a <- runErrorT m
    case a of
      Left e -> return $ Left e
      Right x -> runErrorT (f x)
    
instance appErrorT :: (Functor m, Monad m) => Applicative (ErrorT e m) where
  pure a  = ErrorT $ return $ Right a
  (<*>) f v = ErrorT $ do
    mf <- runErrorT f
    case mf of
      Left e -> return $ Left e
      Right k -> do
        mv <- runErrorT v
        return case mv of
          Left e -> Left e
          Right x -> Right (k x)

instance functorErrorT :: (Functor m) => Functor (ErrorT e m) where
  (<$>) f = ErrorT <<< (<$>) ((<$>) f) <<< runErrorT

instance monadTransErrorT :: (Error e) => MonadTrans (ErrorT e) where
  lift m = ErrorT $ do
    a <- m
    return $ Right a

liftListenError :: forall e m a w. (Monad m) => (m (Either e a) -> m (Tuple (Either e a) w)) -> ErrorT e m a -> ErrorT e m (Tuple a w)
liftListenError listen = mapErrorT $ \m -> do
  Tuple a w <- listen m
  return $ (\r -> Tuple r w) <$> a

liftPassError :: forall e m a w. (Monad m) => (m (Tuple (Either e a) (w -> w)) -> m (Either e a)) -> ErrorT e m (Tuple a (w -> w)) -> ErrorT e m a
liftPassError pass = mapErrorT $ \m -> pass $ do
  a <- m
  return $ case a of
    Left e -> Tuple (Left e) id
    Right (Tuple r f) -> Tuple (Right r) f
