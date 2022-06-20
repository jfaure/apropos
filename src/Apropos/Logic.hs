{-# LANGUAGE TypeFamilies #-}

module Apropos.Logic (
  Formula (..),
  solveAll,
  enumerateSolutions,
  enumerateScenariosWhere,
  scenarios,
  scenarioMap,
  satisfiedBy,
  satisfies,
  runTest,
) where

import Data.Map (Map)
import Data.Map qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set

import Apropos.Description (DeepHasDatatypeInfo, Description, VariableRep, descriptionToVariables, logic, universe)
import Apropos.Formula (
  Formula (..),
  enumerateSolutions,
  satisfiable,
  solveAll,
 )
import Hedgehog (Gen, Property, PropertyT, forAll, property)

enumerateScenariosWhere :: forall d a. (Description d a, DeepHasDatatypeInfo d) => Formula (VariableRep d) -> [Set (VariableRep d)]
enumerateScenariosWhere holds = enumerateSolutions $ logic :&&: holds

scenarios :: forall d a. (Description d a, DeepHasDatatypeInfo d) => [Set (VariableRep d)]
scenarios = enumerateScenariosWhere Yes

scenarioMap :: (Description d a, DeepHasDatatypeInfo d) => Map Int (Set (VariableRep d))
scenarioMap = Map.fromList $ zip [0 ..] scenarios

satisfiedBy :: (Description d a, DeepHasDatatypeInfo d) => [VariableRep d]
satisfiedBy = Set.toList $
  case scenarios of
    [] -> error "no solutions found for model logic"
    (sol : _) -> sol

satisfies :: forall d. (DeepHasDatatypeInfo d) => Formula (VariableRep d) -> d -> Bool
satisfies f s = satisfiable $ f :&&: All (Var <$> set) :&&: None (Var <$> unset)
  where
    set :: [VariableRep d]
    set = Set.toList (descriptionToVariables s)
    unset :: [VariableRep d]
    unset = filter (`notElem` descriptionToVariables s) universe

runTest :: (Show a) => Gen a -> (a -> PropertyT IO ()) -> Property
runTest gen comp = property (forAll gen >>= comp)
