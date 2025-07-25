module Main where

import Prelude

import Components.Dropdown as Dropdown
import Components.Typeahead as Typeahead
import Data.Array (zipWith)
import Data.Const (Const)
import Data.Map as M
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Traversable (for_, sequence, traverse)
import Data.Tuple (Tuple(..))
import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Class (liftEffect)
import Halogen as H
import Halogen.Aff as HA
import Halogen.HTML as HH
import Halogen.VDom.Driver (runUI)
import Internal.Proxy (ProxyS, proxy)
import Type.Proxy (Proxy(..))
import Web.DOM.Element (getAttribute)
import Web.DOM.NodeList (toArray)
import Web.DOM.ParentNode (QuerySelector(..), querySelectorAll)
import Web.HTML (window)
import Web.HTML.HTMLDocument (toParentNode)
import Web.HTML.HTMLElement (HTMLElement, toElement, fromNode)
import Web.HTML.Window (document)

-- Finds all nodes labeled "data-component-id" and retrieves the associated attribute.
-- Then, mounts the right component at each node.

main :: Effect Unit
main = HA.runHalogenAff do
  elements <- awaitSelectAll
    { query: QuerySelector "div[data-component]"
    , attr: "data-component"
    }
  for_ elements \e -> runUI app e.attr e.element

----------
-- Routes

type Components
  = M.Map String (H.Component (ProxyS (Const Void) Unit) Unit Void Aff)

routes :: Components
routes = M.fromFoldable
  [ Tuple "typeahead" $ proxy typeahead
  , Tuple "dropdown" $ proxy dropdown
  ]

app :: H.Component (Const Void) String Void Aff
app = H.mkComponent
  { initialState: identity
  , render
  , eval: H.mkEval H.defaultEval
  }
  where
  render st = M.lookup st routes # case _ of
    Nothing -> HH.div_ []
    Just component -> HH.slot (Proxy :: Proxy "child") unit component unit absurd

----------
-- Selection Helpers

awaitSelectAll
  :: { query :: QuerySelector, attr :: String }
  -> Aff (Array { element :: HTMLElement, attr :: String })
awaitSelectAll ask@{ query } = HA.awaitLoad >>= \_ -> selectElements ask

selectElements
  :: { query :: QuerySelector, attr :: String }
  -> Aff (Array { element :: HTMLElement, attr :: String })
selectElements { query, attr } = do
  nodeArray <- liftEffect do
    toArray =<< querySelectorAll query <<< toParentNode =<< document =<< window
  let
    elems = fromMaybe [] <<< sequence $ fromNode <$> nodeArray
  attrs <- liftEffect $ traverse (getAttribute attr <<< toElement) elems
  pure $ zipWith ({ element: _, attr: _ }) elems (fromMaybe "" <$> attrs)

----------
-- Components

dropdown :: forall t0 t1 t2. H.Component t0 t1 t2 Aff
dropdown = H.mkComponent
  { initialState: const unit
  , render: \_ ->
      HH.slot label unit Dropdown.component input \_ -> Nothing
  , eval: H.mkEval H.defaultEval
  }
  where
  label = Proxy :: Proxy "dropdown"
  input = { items: [ "Chris", "Forest", "Dave" ], buttonLabel: "Choose a character" }

typeahead :: forall t0 t1 t2. H.Component t0 t1 t2 Aff
typeahead = H.mkComponent
  { initialState: const unit
  , render: \_ ->
      HH.slot label unit Typeahead.component unit \_ -> Nothing
  , eval: H.mkEval H.defaultEval
  }
  where
  label = Proxy :: Proxy "typeahead"
