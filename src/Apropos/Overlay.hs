module Apropos.Overlay (
  Overlay (..),
  soundOverlay,
  overlaySources,
  deduceFromOverlay,
) where

import Apropos.Error
import Apropos.HasLogicalModel
import Apropos.HasParameterisedGenerator
import Apropos.HasPermutationGenerator.Source
import Apropos.LogicalModel
import Data.Map (Map)
import Data.Map qualified as Map
import Data.Set (Set)
import Data.Set qualified as Set
import Hedgehog (Property, failure, footnote, property)

class (LogicalModel op, LogicalModel sp) => Overlay op sp | op -> sp where
  overlays :: op -> Formula sp

soundOverlay :: forall op sp. (Overlay op sp, Enumerable op) => Property
soundOverlay = property $
  case solveAll (antiValidity @op @sp) of
    (violation : _) -> do
      case uncoveredSubSolutions @sp @op of
        (uncovered : _) ->
          footnote $
            "found solution to sub model which is excluded by overlay logic\n"
              ++ show (Set.toList uncovered)
        [] -> internalError $ "overlay violation" ++ show violation
      failure
    [] -> case emptyOverlays @sp @op of
      (empty : _) -> do
        footnote $
          "found solution to overlay with no coresponding sub model solutions\n"
            ++ show (Set.toList empty)
        failure
      [] -> pure ()

conectingLogic :: (Overlay op sp, Enumerable op) => Formula (Either op sp)
conectingLogic = All [Var (Left op) :<->: (Right <$> overlays op) | op <- enumerated]

-- we want to assure: conectingLogic => (Left <$> logic) === (Right <$> logic)
antiValidity :: (Overlay op sp, Enumerable op) => Formula (Either op sp)
antiValidity =
  let overlayLogic = Left <$> logic
      subModelLogic = Right <$> logic
   in Not ((conectingLogic :&&: subModelLogic) :->: overlayLogic)

-- list of solutions to the overlay logic which have no coresponding solutions in the sub-model
-- if this is not empty that is considered unsound
emptyOverlays :: forall sp op. (Overlay op sp, Enumerable op) => [Set op]
emptyOverlays =
  let sols :: [Map op Bool]
      sols = solveAll (logic :: Formula op)
      solFormulas :: [(Set op, Formula op)]
      solFormulas = [(Map.keysSet $ Map.filter id sol, All [if b then Var sp else Not (Var sp) | (sp, b) <- Map.toList sol]) | sol <- sols]
   in [ sop | (sop, form) <- solFormulas, null $
                                            solveAll $
                                              (Left <$> form) :&&: (Right <$> logic @sp) :&&: conectingLogic
      ]

-- list of sub model solutions that aren't covered by any solutions to the overlaying model
-- if this is not empty that is also unsound
uncoveredSubSolutions :: forall sp op. (Overlay op sp, Enumerable op) => [Set sp]
uncoveredSubSolutions =
  let sols :: [Map sp Bool]
      sols = solveAll (logic :: Formula sp)
      solFormulas :: [(Set sp, Formula sp)]
      solFormulas = [(Map.keysSet $ Map.filter id sol, All [if b then Var sp else Not (Var sp) | (sp, b) <- Map.toList sol]) | sol <- sols]
   in [ ssp | (ssp, form) <- solFormulas, null $
                                            solveAll $
                                              (Right <$> form) :&&: (Left <$> logic @op) :&&: conectingLogic
      ]

overlaySources :: (Overlay p op, HasParameterisedGenerator op m, Enumerable p, Enumerable op) => [Source p m]
overlaySources =
  [ Source
    { sourceName = "overlay"
    , covers = All [if p `elem` ps then Var p else Not (Var p) | p <- enumerated]
    , gen = genSatisfying (All [(if p `elem` ps then id else Not) $ overlays p | p <- enumerated])
    }
  | ps <- scenarios
  ]

deduceFromOverlay :: (HasLogicalModel sp m, Overlay op sp) => op -> m -> Bool
deduceFromOverlay = satisfiesExpression . overlays
