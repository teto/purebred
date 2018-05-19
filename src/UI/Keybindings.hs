{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE KindSignatures #-}
module UI.Keybindings where

import qualified Brick.Types as Brick
import qualified Brick.Main as Brick
import qualified Brick.Focus as Brick
import qualified Brick.Widgets.Edit as E
import qualified Brick.Widgets.List as L
import Graphics.Vty (Event (..))
import Control.Lens ((&), view, set)
import Data.List (find)
import Prelude hiding (readFile, unlines)
import Data.Proxy
import Types

lookupKeybinding :: Event -> [Keybinding ctx a] -> Maybe (Keybinding ctx a)
lookupKeybinding e = find (\x -> view kbEvent x == e)

class EventHandler (m :: Name)  where
    keybindingsL
        :: Functor f
        => Proxy m
        -> ([Keybinding m (Brick.Next AppState)] -> f [Keybinding m (Brick.Next AppState)])
        -> AppState
        -> f AppState
    fallbackHandler :: Proxy m
                    -> AppState
                    -> Event
                    -> Brick.EventM Name (Brick.Next AppState)

instance EventHandler 'ListOfMails where
  keybindingsL _ = asConfig . confIndexView . ivBrowseMailsKeybindings
  fallbackHandler _ s e = Brick.continue =<< Brick.handleEventLensed s (asMailIndex . miListOfMails) L.handleListEvent e

instance EventHandler 'ListOfThreads where
  keybindingsL _ = asConfig . confIndexView . ivBrowseThreadsKeybindings
  fallbackHandler _ s e = Brick.continue =<< Brick.handleEventLensed s (asMailIndex . miListOfThreads) L.handleListEvent e

instance EventHandler 'SearchThreadsEditor where
  keybindingsL _ = asConfig . confIndexView . ivSearchThreadsKeybindings
  fallbackHandler _ s e = Brick.continue =<< Brick.handleEventLensed s (asMailIndex . miSearchThreadsEditor) E.handleEditorEvent e

instance EventHandler 'ManageMailTagsEditor where
  keybindingsL _ = asConfig . confIndexView . ivManageMailTagsKeybindings
  fallbackHandler _ s e = Brick.continue =<< Brick.handleEventLensed s (asMailIndex . miMailTagsEditor) E.handleEditorEvent e

instance EventHandler 'ManageThreadTagsEditor where
  keybindingsL _ = asConfig . confIndexView . ivManageThreadTagsKeybindings
  fallbackHandler _ s e = Brick.continue =<< Brick.handleEventLensed s (asMailIndex . miThreadTagsEditor) E.handleEditorEvent e

instance EventHandler 'ScrollingMailView where
  keybindingsL _ = asConfig . confMailView . mvKeybindings
  fallbackHandler _ s e = maybe
                          (Brick.continue s)
                          (\kb -> view (kbAction . aAction) kb s)
                          (lookupKeybinding e $ view (asConfig . confIndexView . ivBrowseMailsKeybindings) s)

instance EventHandler 'ScrollingHelpView where
  keybindingsL _ = asConfig . confHelpView . hvKeybindings
  fallbackHandler _ s _ = Brick.continue s

instance EventHandler 'ComposeFrom where
  keybindingsL _ = asConfig . confComposeView . cvFromKeybindings
  fallbackHandler _ s e = Brick.continue =<< Brick.handleEventLensed s (asCompose . cFrom) E.handleEditorEvent e

instance EventHandler 'ComposeTo where
  keybindingsL _ = asConfig . confComposeView . cvToKeybindings
  fallbackHandler _ s e = Brick.continue =<< Brick.handleEventLensed s (asCompose . cTo) E.handleEditorEvent e

instance EventHandler 'ComposeSubject where
  keybindingsL _ = asConfig . confComposeView . cvSubjectKeybindings
  fallbackHandler _ s e = Brick.continue =<< Brick.handleEventLensed s (asCompose . cSubject) E.handleEditorEvent e

dispatch :: EventHandler m => Proxy m -> AppState -> Event -> Brick.EventM Name (Brick.Next AppState)
dispatch m s e = let kbs = view (keybindingsL m) s
                 in case lookupKeybinding e kbs of
                      Just kb -> s & view (kbAction . aAction) kb . set asError Nothing
                      Nothing -> fallbackHandler m s e
