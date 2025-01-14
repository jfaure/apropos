module Spec.TicTacToe.LocationSequence (
  LocationSequenceProperty (..),
  locationSequencePermutationGenSelfTest,
) where

import Apropos
import Apropos.LogicalModel
import Data.Set qualified as Set
import Spec.TicTacToe.Location
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.Hedgehog (fromGroup)

data LocationSequenceProperty
  = AllLocationsAreInBounds
  | SomeLocationIsOutOfBounds
  | SomeLocationIsOccupiedTwice
  | LocationSequenceIsNull
  | LocationSequenceIsSingleton
  | LocationSequenceIsLongerThanGame
  deriving stock (Eq, Ord, Enum, Show, Bounded, Generic)
  deriving anyclass (Hashable)

instance Enumerable LocationSequenceProperty where
  enumerated = [minBound .. maxBound]

instance LogicalModel LocationSequenceProperty where
  logic =
    ExactlyOne (Var <$> [AllLocationsAreInBounds, SomeLocationIsOutOfBounds])
      :&&: (Var LocationSequenceIsNull :->: Var AllLocationsAreInBounds)
      :&&: (Var LocationSequenceIsNull :->: Not (Var SomeLocationIsOutOfBounds))
      :&&: (Var LocationSequenceIsNull :->: Not (Var SomeLocationIsOccupiedTwice))
      :&&: (Var LocationSequenceIsNull :->: Not (Var LocationSequenceIsLongerThanGame))
      :&&: (Var LocationSequenceIsSingleton :->: Not (Var SomeLocationIsOccupiedTwice))
      :&&: (Var LocationSequenceIsSingleton :->: Not (Var LocationSequenceIsLongerThanGame))
      :&&: AtMostOne [Var LocationSequenceIsNull, Var LocationSequenceIsSingleton]
      :&&: ( (Var LocationSequenceIsLongerThanGame :&&: Var AllLocationsAreInBounds)
              :->: Var SomeLocationIsOccupiedTwice
           )

someLocationIsOccupiedTwice :: [Int] -> Bool
someLocationIsOccupiedTwice locationSeq =
  Set.size (Set.fromList locationSeq) < length locationSeq

instance HasLogicalModel LocationSequenceProperty [Int] where
  satisfiesProperty AllLocationsAreInBounds m =
    all (satisfiesProperty LocationIsWithinBounds) m
  satisfiesProperty SomeLocationIsOutOfBounds m =
    any (satisfiesProperty LocationIsOutOfBounds) m
  satisfiesProperty SomeLocationIsOccupiedTwice m = someLocationIsOccupiedTwice m
  satisfiesProperty LocationSequenceIsNull m = null m
  satisfiesProperty LocationSequenceIsSingleton m = length m == 1
  satisfiesProperty LocationSequenceIsLongerThanGame m = length m > 9

instance HasPermutationGenerator LocationSequenceProperty [Int] where
  sources =
    [ Source
        { sourceName = "null"
        , covers = Var LocationSequenceIsNull
        , gen = pure []
        }
    , Source
        { sourceName = "singleton out of bounds"
        , covers = Var LocationSequenceIsSingleton :&&: Var SomeLocationIsOutOfBounds
        , gen =
            list (singleton 1) $
              choice
                [ int (linear minBound (-1))
                , int (linear 9 maxBound)
                ]
        }
    , Source
        { sourceName = "MakeInBoundsSingleton"
        , covers = Var AllLocationsAreInBounds :&&: Var LocationSequenceIsSingleton
        , gen = list (singleton 1) $ int (linear 0 8)
        }
    , Source
        { sourceName = "MakeSomeLocationIsOccupiedTwiceSequenceTooLong"
        , covers =
            Var SomeLocationIsOccupiedTwice
              :&&: Var SomeLocationIsOutOfBounds
              :&&: Var LocationSequenceIsLongerThanGame
        , gen =
            genFilter (satisfiesProperty SomeLocationIsOutOfBounds) $ do
              let locationsLen = 10
              locations' <-
                list (singleton (locationsLen - 1)) $
                  int (linear minBound maxBound)
              list (singleton locationsLen) $ element locations'
        }
    ]
  generators =
    [ Morphism
        { name = "MakeAllLocationsAreInBoundsNoneOccupiedTwice"
        , match = Not $ Var LocationSequenceIsNull
        , contract =
            removeAll
              [ SomeLocationIsOutOfBounds
              , SomeLocationIsOccupiedTwice
              , LocationSequenceIsLongerThanGame
              ]
              >> add AllLocationsAreInBounds
        , morphism = \locations -> do
            let locationsLen = min 9 (length locations)
            locations' <- shuffle [0 .. 8]
            pure $ take locationsLen locations'
        }
    , Morphism
        { name = "MakeAllLocationsAreInBoundsSomeOccupiedTwice"
        , match = Yes
        , contract =
            removeAll
              [ SomeLocationIsOutOfBounds
              , LocationSequenceIsNull
              ]
              >> addAll
                [ AllLocationsAreInBounds
                , SomeLocationIsOccupiedTwice
                ]
        , morphism = \locations -> do
            let locationsLen = max 2 (length locations)
            locations' <- shuffle [0 .. 8]
            let locations'' = take (locationsLen - 1) locations'
            list (singleton locationsLen) $ element locations''
        }
    , Morphism
        { name = "MakeSomeLocationIsOutOfBoundsNoneOccupiedTwice"
        , match = Not $ Var LocationSequenceIsNull
        , contract =
            removeAll
              [ AllLocationsAreInBounds
              , SomeLocationIsOccupiedTwice
              ]
              >> add SomeLocationIsOutOfBounds
        , morphism = \locations ->
            let f =
                  ( satisfiesFormula
                      ( Var SomeLocationIsOutOfBounds
                          :&&: Not (Var SomeLocationIsOccupiedTwice)
                      )
                      . properties
                  )
             in do
                  let locationsLen = length locations
                  genFilter f $
                    list (singleton locationsLen) $
                      int (linear minBound maxBound)
        }
    , Morphism
        { name = "MakeSomeLocationIsOccupiedTwice"
        , match = Not (Var LocationSequenceIsNull :||: Var LocationSequenceIsSingleton)
        , contract =
            removeAll
              [ AllLocationsAreInBounds
              , LocationSequenceIsNull
              , LocationSequenceIsSingleton
              ]
              >> addAll
                [ SomeLocationIsOccupiedTwice
                , SomeLocationIsOutOfBounds
                ]
        , morphism = \locations -> genFilter (satisfiesProperty SomeLocationIsOutOfBounds) $ do
            let locationsLen = length locations
            locations' <-
              list (singleton (locationsLen - 1)) $
                int (linear minBound maxBound)
            list (singleton locationsLen) $ element locations'
        }
    ]

instance HasParameterisedGenerator LocationSequenceProperty [Int] where
  parameterisedGenerator = buildGen

locationSequencePermutationGenSelfTest :: TestTree
locationSequencePermutationGenSelfTest =
  testGroup "locationSequencePermutationGenSelfTest" $
    pure $
      fromGroup $
        permutationGeneratorSelfTest @LocationSequenceProperty
