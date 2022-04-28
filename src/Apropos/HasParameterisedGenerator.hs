{-# LANGUAGE AllowAmbiguousTypes #-}

module Apropos.HasParameterisedGenerator (
  HasParameterisedGenerator (..),
  runGeneratorTest,
  runGeneratorTestsWhere,
  enumerateGeneratorTest,
  enumerateGeneratorTestsWhere,
  genSatisfying,
  sampleGenTest,
) where

import Apropos.Gen hiding ((===))
import Apropos.Gen.BacktrackingTraversal
import Apropos.Gen.Enumerate
import Apropos.HasLogicalModel
import Apropos.LogicalModel
import Data.Map qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Data.String (fromString)
import Hedgehog (Group (..), Property, TestLimit, property, withTests, (===))

class (HasLogicalModel p m, Show m) => HasParameterisedGenerator p m where
  parameterisedGenerator :: Set p -> Traversal p m
  rootRetryLimit :: Int
  rootRetryLimit = 100

-- TODO caching calls to the solver in genSatisfying would probably be worth it
runGeneratorTest ::
  forall p m .
  HasParameterisedGenerator p m =>
  Set p ->
  Property
runGeneratorTest s = property $ do
  (m :: m) <- traversalContainRetry numRetries $ parameterisedGenerator s
  properties m === s
  where
    numRetries :: Int
    numRetries = rootRetryLimit @p

runGeneratorTestsWhere ::
  HasParameterisedGenerator p m =>
  String ->
  Formula p ->
  Group
runGeneratorTestsWhere name condition =
  Group (fromString name) $
    [ (fromString $ show $ Set.toList scenario, runGeneratorTest scenario)
    | scenario <- enumerateScenariosWhere condition
    ]

genPropSet :: forall p .LogicalModel p => Gen (Set p)
genPropSet = do
  let x = length (scenarios @p)
  i <- int (linear 0 (x - 1))
  case Map.lookup i scenarioMap of
    Nothing -> error "bad index in scenario sample this is a bug in apropos"
    Just set -> pure set

sampleGenTest ::
  forall p m.
  HasParameterisedGenerator p m =>
  Property
sampleGenTest = property $ do
  (ps :: Set p) <- forAll genPropSet
  (m :: m) <- forAll $ traversalAsGen $ parameterisedGenerator ps
  properties m === ps

enumerateGeneratorTest ::
  forall p m.
  HasParameterisedGenerator p m =>
  Set p ->
  Property
enumerateGeneratorTest s = withTests (1 :: TestLimit) $
  property $ do
    let (ms :: [m]) = enumerate $ traversalAsGen $ parameterisedGenerator s
        run m = properties m === s
    sequence_ (run <$> ms)

enumerateGeneratorTestsWhere ::
  HasParameterisedGenerator p m =>
  String ->
  Formula p ->
  Group
enumerateGeneratorTestsWhere name condition =
  Group (fromString name) $
    [ (fromString $ show $ Set.toList scenario, enumerateGeneratorTest scenario)
    | scenario <- enumerateScenariosWhere condition
    ]

genSatisfying :: HasParameterisedGenerator p m => Formula p -> Gen m
genSatisfying f = do
  label $ fromString $ show f
  s <- element (enumerateScenariosWhere f)
  traversalAsGen $ parameterisedGenerator s -- TODO this doesn't do shrink containment...
  -- we can lift a Traversal into Gen
  -- like GenWrap but for Traversal
  -- or something...
