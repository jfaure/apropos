module Spec.IntOverlay (
  intSmplPermutationGenTests,
  IntSmpl (..),
) where

import Apropos

import Spec.IntPermutationGen (IntProp (IsNegative))
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.Hedgehog (fromGroup, testPropertyNamed)

data IntSmpl = NonNegative
  deriving stock (Eq, Ord, Show, Generic)
  deriving anyclass (Enumerable, Hashable)

instance LogicalModel IntSmpl where
  logic = Yes

instance Overlay IntSmpl IntProp where
  overlays NonNegative = Not $ Var IsNegative

instance HasLogicalModel IntSmpl Int where
  satisfiesProperty = deduceFromOverlay

instance HasPermutationGenerator IntSmpl Int where
  sources = overlaySources

instance HasParameterisedGenerator IntSmpl Int where
  parameterisedGenerator = buildGen

intSmplPermutationGenTests :: TestTree
intSmplPermutationGenTests =
  testGroup
    "intSmplPermutationGenTests"
    [ testPropertyNamed "overlay is sound" "soundOverlay" $ soundOverlay @IntSmpl
    , fromGroup $ permutationGeneratorSelfTest @IntSmpl
    ]
