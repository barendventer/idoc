{-# OPTIONS_GHC -fno-warn-orphans #-}
module Text.IDoc.Render.Tex where

import ClassyPrelude
import Control.Lens
import qualified Data.Text.IO as IO
import qualified System.IO as SIO

import Text.IDoc.Syntax as S
import Text.IDoc.Parse
import Text.IDoc.Lex

import qualified Text.Megaparsec as MP
import Text.LaTeX as L hiding ((<>))
import Text.LaTeX.Base.Class
import Text.LaTeX.Packages.Graphicx
import Text.LaTeX.Packages.AMSSymb
import Text.LaTeX.Packages.AMSMath as M
import Text.LaTeX.Packages.AMSThm as T
import Text.LaTeX.Packages.Hyperref

type Icon = LaTeX

mLabel :: (LaTeXC l) => Maybe SetID -> (l -> l)
mLabel mid = case mid of
  Nothing -> id
  Just id_ -> ((texy id_) ++)

defaultDecorator :: LaTeXC l => l -> l -> l
defaultDecorator title_ d =
  (documentclass [letterpaper] "memoir") ++

  (usepackage [] hyperref) ++
  (usepackage [] graphicx) ++
  (usepackage [] "listings") ++
  (usepackage ["usenames", "dvipsnames"] "xcolor") ++
  (usepackage [] amsmath) ++
  (usepackage [] amsthm) ++
  (usepackage [] amssymb) ++
  (usepackage [] "mdframed") ++

  (newtheorem  "Theorem" "Theorem") ++
  (newtheorem' ["Theorem"] "Lemma" "Lemma") ++
  (newtheorem' ["Theorem"] "Corollary" "Corollary") ++
  (newtheorem' ["Theorem"] "Proposition" "Proposition") ++
  (newtheorem' ["Theorem"] "Conjecture" "Conjecture") ++
  (newtheorem' ["Theorem"] "Axiom" "Axiom") ++

  (lstset ["basicstyle=\\footnotesize\\ttfamily"]) ++
  (theoremstyle T.Definition) ++
  (newtheorem  "Definition" "Definition") ++

  (newmdenv ["frametitlebackgroundcolor=lightgray"] "SideNote") ++
  (newmdenv ["frametitlebackgroundcolor=SkyBlue"] "Info") ++
  (newmdenv ["frametitlebackgroundcolor=SkyBlue"] "Tip") ++
  (newmdenv ["frametitlebackgroundcolor=Goldenrod"] "Caution") ++
  (newmdenv ["frametitlebackgroundcolor=BrickRed"] "Warning") ++
  (newmdenv ["frametitlebackgroundcolor=SkyBlue"] "Intuition") ++
  (setcounter "tocdepth" "2") ++

  (document $
  title title_ ++
  author "ILS Contributors" ++
  date today ++
  maketitle ++
  tableofcontents ++
  d)

mkCode :: LaTeXC l => l -> l -> l
mkCode lang t = L.between t (raw "\\begin{lstlisting}[frame=single,framesep=5mm,breaklines,language={" ++ lang ++ raw "}]\n") (raw "\n\\end{lstlisting}\n")

mkBlock :: LaTeXC l => l -> l -> l -> l
mkBlock name btitle t = L.between t (raw "\\begin{" ++ name ++ raw "}" ++ 
                                     raw "[frametitle=" ++ btitle ++ raw "]") 
                                    (raw "\n\\end{" ++ name ++ raw "}\n")

sideNoteBlock :: LaTeXC l => l -> l -> l
sideNoteBlock = mkBlock "SideNote"

lstset :: LaTeXC l => [Text] -> l
lstset args = L.between (concatMap raw $ intersperse "," args) (raw "\\lstset{") (raw "}")

infoBlock :: LaTeXC l => l -> l -> l
infoBlock = mkBlock "Info"

tipBlock :: LaTeXC l => l -> l -> l
tipBlock = mkBlock "Tip"

intuitionBlock :: LaTeXC l => l -> l -> l
intuitionBlock = mkBlock "Intuition"

warningBlock :: LaTeXC l => l -> l -> l
warningBlock = mkBlock "Warning"

cautionBlock :: LaTeXC l => l -> l -> l
cautionBlock = mkBlock "Caution"

newmdenv :: LaTeXC l => [Text] -> Text -> l
newmdenv opts name = raw $ "\\newmdenv[" ++ (concat $ intersperse "," opts) ++ "]" ++
                           "{" ++ name ++ "}"

newtheorem' :: LaTeXC l => [Text] -> Text -> Text -> l
newtheorem' opts env caption_ = raw $ "\\newtheorem{" ++ env ++ "}" ++
                                      "[" ++ (concat $ intersperse "," opts) ++ "]" ++
                                      "{" ++ caption_ ++ "}"

hyperref' :: LaTeXC l => Text -> l -> l
hyperref' lnk caption_ = (raw $ "\\hyperref[" ++ lnk ++ "]") ++
                         raw "{" ++ caption_ ++ raw "}"

setcounter :: LaTeXC l => l -> l -> l
setcounter name_ val = raw "\\setcounter{" ++ name_ ++ raw "}{" ++ val ++ raw "}"

compileToTex :: LaTeX -> FilePath -> FilePath -> IO ()
compileToTex title_ inFile outFile = SIO.withFile inFile SIO.ReadMode 
                                     (\src -> do
                                         fileContents <- IO.hGetContents src
                                         case MP.parse dTokens inFile fileContents of
                                           Left e -> print e
                                           Right x -> do
                                             case MP.parse docP "<tokens>" x of
                                               Left e -> print e
                                               Right y -> renderFile outFile $ defaultDecorator title_ $ (texy y :: LaTeX))

compileIdocTexFile :: MonadIO m => Doc -> FilePath -> m ()
compileIdocTexFile doc_ outFile = liftIO $ renderFile outFile $ defaultDecorator (concatMap texy $ unDocTitle $ doc_^.docTitle) (texy doc_ :: LaTeX)

instance Texy Doc where
  texy d = chapter (mLabel (d^.docSetID) $ (texy $ d^.docTitle)) ++
           (vectorBlockTexy $ d^.docSections)

instance Texy Section where
  texy s = starter (mLabel (s^.secSetID) $ texy $ s^.secTitle) ++
           (vectorBlockTexy $ s^.secContents)
    where starter = case s^.secType of
            Preamble -> const ""
            TopSection -> section
            SubSection -> subsection

instance Texy SectionTitle where
  texy (SectionTitle s) = vectorBlockTexy s

instance Texy DocTitle where
  texy (DocTitle dt) = vectorBlockTexy dt

instance Texy Core where
  texy (SC sc) = texy sc
  texy (CC cc) = texy cc

instance Texy SimpleCore where
  texy (TextC t) = texy t
  texy (QTextC qt) = texy qt
  texy (LinkC l) = texy l
  texy (InlineMathC im) = texy im
  texy (MarkupC m) = texy m

instance Texy ComplexCore where
  texy (ListC l) = texy l
  texy (BlockC b) = texy b
  texy (ParagraphC p) = texy p

instance Texy QText where
  texy qt = decorateTextWith (qt^.qtType) $
            concatMap texy $ qt^.qtText
    where
      decorateTextWith Strong = textbf
      decorateTextWith Emphasis = emph
      decorateTextWith Monospace = texttt
      decorateTextWith Superscript = textsuperscript
      decorateTextWith Subscript = textsubscript
      decorateTextWith Quoted = qts

      textsuperscript x = between x (raw "\textsuperscript{") (raw "}")

      textsubscript x = between x (raw "\textsubscript{") (raw "}")

instance Texy SetID where
  texy (SetID { _sidName = IDHash sid }) = label $ texy sid

instance Texy Link where
  texy l = case l^.linkType of
             Out -> href []
                         (createURL $ unpack $ fromOut $ l^.linkLocation) 
                         (concatMap texy $ unLinkText $ l^.linkText)
             Internal -> hyperref' (fromInternal $ l^.linkLocation)
                                   (concatMap texy $ unLinkText $ l^.linkText)
             Back -> href [] 
                          (createURL $ unpack $ fromBack $ l^.linkLocation)
                          (concatMap texy $ unLinkText $ l^.linkText)
    where
      fromOut id_ =
        let (proto, hash_) =
              case (id_^.idProtocol, id_^.idHash) of
                (Just (Protocol "youtube"), Nothing) -> 
                  ("https://youtube.com/embed/", "")
                (Just (Protocol "youtube"), Just _) -> 
                  error "got youtube protocol with a hash!?"
                (Just (Protocol p), Just (IDHash h)) ->
                  (p ++ "://", h)
                (Just (Protocol p), Nothing) ->
                  (p ++ "://", "")
                _ -> error $ "Invalid Outlink:\nProtocol: " ++ (show $ id_^.idProtocol) ++ "\nHash: " ++ (show $ id_^.idHash)
        in
          proto ++
          (concatMap unIDBase $ intersperse (IDBase "/") (id_^.idBase)) ++ 
          (if hash_ /= "" then "#" ++ hash_ else "")
      fromInternal id_ = case id_^.idHash of
                           Just (IDHash h) -> h
                           _ -> "WTF"
      fromBack id_ = "http://www.independentlearning.science/tiki/" ++ 
                     (concatMap unIDBase $ intersperse (IDBase "/") (id_^.idBase))

instance Texy LinkText where
  texy (LinkText lt) = concatMap texy lt

instance Texy InlineMath where
  texy im = M.math $ concatMap texy $ im^.imContents

instance Texy Token where
  texy t = raw $ unToken t

instance Texy Markup where
  texy mu_ = mLabel (mu_^.muSetID) $
    case (mu_^.muType) of
      Footnote -> footnote $ concatMap texy $ mu_^.muContents
      FootnoteRef -> ref $ concatMap texy $ mu_^.muContents
      Citation -> cite $ concatMap texy $ mu_^.muContents

instance Texy Paragraph where
  texy p = (concatMap texy $ p^.paraContents) ++ "\n\n"

vectorBlockTexy :: (Texy a, LaTeXC l) => Vector a -> l
vectorBlockTexy vb = concatMap texy vb

instance Texy BlockTitle where
  texy (BlockTitle bt) = concatMap texy bt

instance Texy Block where
  texy b = case b^.bType of
             PrerexB p -> block (b^.bTitle) (b^.bSetID) p
             IntroductionB i -> block (b^.bTitle) (b^.bSetID) i
             MathB m -> block (b^.bTitle) (b^.bSetID) m
             EquationB e -> block (b^.bTitle) (b^.bSetID) e
             AlignB a -> block (b^.bTitle) (b^.bSetID) a
             TheoremB t -> block (b^.bTitle) (b^.bSetID) t
             LemmaB l -> block (b^.bTitle) (b^.bSetID) l
             CorollaryB c -> block (b^.bTitle) (b^.bSetID) c
             PropositionB p -> block (b^.bTitle) (b^.bSetID) p
             ConjectureB c -> block (b^.bTitle) (b^.bSetID) c
             AxiomB a -> block (b^.bTitle) (b^.bSetID) a
             ProofB p -> block (b^.bTitle) (b^.bSetID) p
             QuoteB q -> block (b^.bTitle) (b^.bSetID) q
             CodeB  c -> codeBlock (b^.bAttrs) (b^.bTitle) (b^.bSetID) c
             ImageB i -> block (b^.bTitle) (b^.bSetID) i
             VideoB v -> block (b^.bTitle) (b^.bSetID) v
             ConnectionB c -> block (b^.bTitle) (b^.bSetID) c
             DefinitionB d -> block (b^.bTitle) (b^.bSetID) d
             IntuitionB i -> block (b^.bTitle) (b^.bSetID) i
             YouTubeB y -> block (b^.bTitle) (b^.bSetID) y
             InfoB i -> block (b^.bTitle) (b^.bSetID) i
             TipB t -> block (b^.bTitle) (b^.bSetID) t
             CautionB c -> block (b^.bTitle) (b^.bSetID) c
             WarningB w -> block (b^.bTitle) (b^.bSetID) w
             SideNoteB s -> block (b^.bTitle) (b^.bSetID) s
             ExampleB e -> block (b^.bTitle) (b^.bSetID) e
             ExerciseB e -> block (b^.bTitle) (b^.bSetID) e
             BibliographyB b_ -> block (b^.bTitle) (b^.bSetID) b_
             FurtherReadingB f -> block (b^.bTitle) (b^.bSetID) f
             SummaryB s -> block (b^.bTitle) (b^.bSetID) s
             RecallB r -> block (b^.bTitle) (b^.bSetID) r
      
mTitle :: LaTeXC l => Maybe BlockTitle -> Text -> l
mTitle mbt defaultTitle = maybe (texy defaultTitle) texy mbt

class Blocky b where
  block :: LaTeXC l => Maybe BlockTitle -> Maybe SetID -> b -> l

instance Blocky Prerex where
  block mt msid (Prerex ps) = subsubsection (mLabel msid title_) ++ vectorBlockTexy ps
    where
      title_ = mTitle mt "Prerex"

instance Texy PrerexItem where
  texy p = (href [] "" $ texy $ fromBack $ p^.prerexItemPath) ++
           ": " ++
           (concatMap texy $ p^.prerexItemDescription) ++
           newline
    where fromBack id_ = "http://www.independentlearning.science/tiki/" ++ 
                         (concatMap unIDBase $ intersperse (IDBase "/") (id_^.idBase))


instance Blocky Introduction where
  block mt msid (Introduction i) = subsection (mLabel msid title_) ++ vectorBlockTexy i
    where
      title_ = mTitle mt "Introduction"

instance Blocky Math where
  block _ msid (Math m) = mLabel msid $ mathDisplay $ raw $ concatMap unToken m

instance Blocky Equation where
  block _ msid (Equation e) = mLabel msid $ M.equation $ raw $ concatMap unToken e

instance Blocky Align where
  block _ msid (Align a) = mLabel msid $ M.align [raw $ concatMap unToken a]

theoremBlock :: LaTeXC l => 
                Maybe BlockTitle
             -> Maybe SetID
             -> Vector Core
             -> Maybe (Vector Core)
             -> String
             -> l
theoremBlock _ msid thm mprf ttype = mLabel msid $
                                     T.theorem ttype $
                                     vectorBlockTexy thm ++
                                     maybe "" (T.proof Nothing . vectorBlockTexy) mprf

instance Blocky Theorem where
  block mt msid (Theorem (thm, mprf)) = theoremBlock mt msid thm mprf "Theorem"

instance Blocky Lemma where
  block mt msid (Lemma (thm, mprf)) = theoremBlock mt msid thm mprf "Lemma"

instance Blocky Corollary where
  block mt msid (Corollary (thm, mprf)) = theoremBlock mt msid thm mprf "Corollary"

instance Blocky Proposition where
  block mt msid (Proposition (thm, mprf)) = theoremBlock mt msid thm mprf "Proposition"

instance Blocky Conjecture where
  block _ msid (Conjecture c) = mLabel msid $
                                T.theorem "Conjecture" $
                                vectorBlockTexy c

instance Blocky Axiom where
  block _ msid (Axiom a) = mLabel msid $
                           T.theorem "Axiom" $
                           vectorBlockTexy a

instance Blocky Proof where
  block mt msid (Proof p) = mLabel msid $
                            T.proof (texy <$> mt) $
                            vectorBlockTexy p

instance Blocky Quote where
  block _ msid (Quote q) = mLabel msid $
                           L.quote $
                           vectorBlockTexy q

codeBlock :: LaTeXC l => AttrMap -> Maybe BlockTitle -> Maybe SetID -> Code -> l
codeBlock (AttrMap attrs) _ msid (Code c) = (mLabel msid $
                                             mkCode langName $
                                             raw $ concatMap unToken c) ++
                                            "\n"
  where 
    langName = maybe "" 
                     (\(AttrValue x) -> if x == "idoc" then "" else texy x)
                     (join $ attrs ^.at (AttrName "lang"))

instance Blocky Image where
  block _ msid (Image (lnk, mcaption)) = mLabel msid $
                                         texy lnk ++
                                         maybe "" vectorBlockTexy mcaption

instance Blocky Video where
  block _ msid (Video (lnk, mcaption)) = mLabel msid $ 
                                         texy lnk ++
                                         maybe "" vectorBlockTexy mcaption

instance Blocky Connection where
  block mt msid (Connection c) = (subsection $ mLabel msid title_) ++
                                 vectorBlockTexy c
    where title_ = mTitle mt "Connection"

instance Blocky Definition where
  block _ msid (S.Definition d) = mLabel msid $
                                  T.theorem "Definition" $
                                  vectorBlockTexy d

instance Blocky Intuition where
  block mt msid (Intuition i) = intuitionBlock (mLabel msid title_) (vectorBlockTexy i)
    where title_ = mTitle mt "Intuition"

instance Blocky YouTube where
  block _ msid (YouTube (lnk, mcaption)) = mLabel msid $ 
                                           texy lnk ++
                                           maybe "" vectorBlockTexy mcaption

instance Blocky Info where
  block mt msid (Info i) = infoBlock (mLabel msid title_) (vectorBlockTexy i)
    where
      title_ = mTitle mt "Info"

instance Blocky Tip where
  block mt msid (Tip t) = tipBlock (mLabel msid title_) (vectorBlockTexy t)
    where
      title_ = mTitle mt "Tip"

instance Blocky Caution where
  block mt msid (Caution c) = cautionBlock (mLabel msid title_) (vectorBlockTexy c)
    where
      title_ = mTitle mt "Caution"

instance Blocky Warning  where
  block mt msid (Warning w) = warningBlock (mLabel msid title_) (vectorBlockTexy w)
    where 
      title_ = mTitle mt "Warning"

instance Blocky SideNote where
  block mt msid (SideNote s) = sideNoteBlock (mLabel msid title_) (vectorBlockTexy s)
    where
      title_ = mTitle mt "SideNote"

instance Blocky Example where
  block mt msid (Example (ex, ans)) = (subsubsection $ mLabel msid title_) ++
                                      vectorBlockTexy ex ++
                                      vectorBlockTexy ans
    where
      title_ = mTitle mt "Example"

instance Blocky Exercise where
  block mt msid (Exercise e) = (subsubsection $ mLabel msid title_) ++
                               vectorBlockTexy e
    where
      title_ = mTitle mt "Exercise"

instance Blocky Bibliography where
  block mt msid (Bibliography b) = (subsection $ mLabel msid title_) ++
                                   vectorBlockTexy b
    where
      title_ = mTitle mt "Bibliography"

instance Texy BibItem where
  texy bi = texy (bi^.biTitle) ++
            ": " ++
            texy (bi^.biAuthor) ++
            "; " ++
            texy (bi^.biYear) ++
            "."

instance Blocky FurtherReading where
  block mt msid (FurtherReading f) = (subsection $ mLabel msid title_) ++
                                     vectorBlockTexy f
    where
      title_ = mTitle mt "Further Reading"

instance Blocky Summary where
  block mt msid (Summary s) = (subsection $ mLabel msid title_) ++
                              vectorBlockTexy s
    where
      title_ = mTitle mt "Summary"

instance Blocky Recall where
  block mt msid (Recall (_, r)) = (subsubsection $ mLabel msid title_) ++
                                  vectorBlockTexy r
    where
      title_ = mTitle mt "Recall"

instance Texy S.List where
  texy (S.List li) = enumerate $
                     concatMap (\li_ -> 
                                  mLabel (li_^.liSetID) $ 
                                  item (textbf <$> texy <$> (li_^.liLabel)) ++ (vectorBlockTexy $ li_^.liContents)) li

instance Texy ListLabel where
  texy (ListLabel ll_) = vectorBlockTexy ll_
