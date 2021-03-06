module LokiPY where

import Control.Applicative hiding (many, (<|>))
import Control.Monad.Except

import qualified Data.List as L
import qualified Data.Map as M
import Data.Maybe
import Text.Printf (printf)

import Utils

-- Contains code that converts symbols from their lisp form
-- to their equivalent name in helperFunctions.py
formatPy :: [String] -> IO String
formatPy py = do helperFns <- readFile "src/helperFunctions.py"
                 let py' = L.intercalate "\n" py
                 return $ helperFns ++ py'

primitives :: M.Map String String
primitives = M.fromList $ fmap addLokiPrefix $ fmap encodeID'
        [("+", "plus"),("-", "minus"),("*", "mult"),("/", "div"),("=", "eq")
        ,("!=", "neq"),("<", "lt"),("<=", "lte"),(">", "gt"),(">=", "gte")
        ,("print", "printf"),("and", "and_"),("or", "or_"),("sc","sc")
        ,("dc","dc"),("in", "in_"), ("dcm", "dcm"),("not","not_")]
        ++ (dupl <$> ["mod","assoc","set","range","get"])
    where
        encodeID' (s,_q) = (encodeID s,_q)
        addLokiPrefix (q,s) = (q,"Loki." ++ s)
        dupl x = (x,x)

aliases :: M.Map String String
aliases = M.fromList [("this", "self")]

-- Contains that will expand special forms from lisp to PY
-- for usage temporarily in place of macros
--      (ie where functions would not suffice)
type SpecialForm = [PyVal] -> String
specialForms :: Int -> M.Map String SpecialForm
specialForms n = M.fromList [("if", if_),("set", set),("setp", setp)
                            ,("for", for_ n),("import", import_)]
    where
        import_ :: SpecialForm
        import_ [PyStr importMe] = printf "import %s" importMe
        import_ [PyStr importMe, PyStr "from", PyStr fromMe] =
            printf "from %s import %s" fromMe importMe
        import_ x = error $ (show x ?> "import_") ++ "wrong args to import_"
        setp :: SpecialForm
        setp [PyId var, PyId prop, val] = let val' = toPY 0 val
                                              var' = lookupID var
                                          in printf "%s.%s = %s" var' prop val'
        setp _ = error "wrong args to setp"
        set :: SpecialForm
        set [PyId var, val] = let val' = toPY 0 val
                              in printf "%s = %s" var val'
        set x = error $ (show x ?> "set-x") ++ "wrong args to set"
        if_ :: SpecialForm
        if_ [cond_, then_, else_] = do
            let cond_' = toPY 0 cond_
                then_' = toPY 0 then_
                else_' = toPY 0 else_
            printf "(%s if %s else %s)" then_' cond_' else_'
        if_ [cond_, then_] = if_ [cond_, then_, PyId "None"]
        if_ _ = error "wrong args to if"
        for_ :: Int -> SpecialForm
        for_ n' (PyList [id_, expr_] : body_) = do
            let id_'   = toPY 0 id_
                expr_' = toPY 0 expr_
                body_' = L.intercalate ("\n" ++ addSpacing (n' + 2)) $ toPY (n' + 1) <$> body_
            printf "for %s in %s:\n%s%s" id_' expr_' (addSpacing (n' + 2)) body_'
        for_ _ x = error $ (show x ?> "for-x") ++ "wrong args to for"

lookupFn :: String -> String
lookupFn f = fromMaybe f $ M.lookup f primitives

lookupID :: String -> String
lookupID k = fromMaybe k $ M.lookup k aliases

lookupSpecForm :: Int -> String -> Maybe SpecialForm
lookupSpecForm n s = M.lookup s (specialForms n)

data PyVal = PyVar String PyVal
           | PyFn [String] [PyVal]
           | PyStr String
           | PyBool Bool
           | PyNum String
           | PyTuple [PyVal]
           | PyId String
           | PyList [PyVal]
           | PyMap [String] [PyVal]
           | PyProp String String
           | PyObjCall String PyVal [PyVal]
           | PyFnCall String [PyVal]
           | PyNewObj String [PyVal]
           | PyDefClass String [String] PyVal [PyVal] [PyVal]
           | PyConst [String] [(String, PyVal)]
           | PyClassSuper String [PyVal]
           | PyClassFn String [String] [PyVal]
           | PyClassVar String PyVal
           | PyPleaseIgnore
           | PyThing String
           deriving (Eq, Show)

translate :: LokiVal -> PyVal
translate v = if read (fromJust (M.lookup "fileType" (getMeta v))) /= PY
                  then PyPleaseIgnore
                  else case v of
                      (Atom _ a)               -> PyId a
                      (Keyword _ k)            -> PyStr k
                      (Tuple {getTuple=t})     -> PyTuple (translate <$> t)
                      (Number _ n)             -> PyNum n
                      (String _ s)             -> PyStr s
                      (Bool _ b)               -> PyBool b
                      (Def _ n (LkiNothing{})) -> PyVar n (PyId "None")
                      (Def _ n b)              -> PyVar n (translate b)
                      (Fn _ xs b)              -> PyFn xs (translate <$> b)
                      (New _ s l)              -> PyNewObj s (translate <$> l)
                      (DefClass _ n s c lf lv) -> PyDefClass n s (maybe PyPleaseIgnore translate c) (translate <$> lf) (translate <$> lv)
                      (Constr _ s b)           -> PyConst s (translateProp <$> b)
                      (ClassSuper _ n as)      -> PyClassSuper n (translate <$> as)
                      (Classfn _ s p b)        -> PyClassFn s p (translate <$> b)
                      (Classvar _ s b)         -> PyClassVar s (translate b)
                      l@(List{})               -> list2pyVal l
                      (Array {getArray=a})     -> PyList (translate <$> a)
                      (Prop _ prop obj) -> PyProp prop obj
                      (Dot _ fnProp objName args) -> PyObjCall fnProp (translate objName) (translate <$> args)
                      (Map _ ks vs)            -> PyMap ks (translate <$> vs)
                      (Thing _ x)              -> PyThing x
                      (LkiNothing _)           -> PyPleaseIgnore
    where
        translateProp :: (String, LokiVal) -> (String, PyVal)
        translateProp (s, l) = (s, translate l)
        list2pyVal :: LokiVal -> PyVal
        list2pyVal l = case l of
                           (List _ (Atom _ a:args)) -> PyFnCall a $ translate <$> args
                           (List _ (f@(Fn{}):args)) -> PyFnCall (toPY 0 (translate f)) $ translate <$> args
                           (List _ xs) -> PyList (translate <$> xs)
                           x -> catch . throwError . TypeMismatch "List" $ show x

toPY :: Int -> PyVal -> String
toPY n pv = case pv of
              a@(PyId{})            -> id2py n a
              (PyNum n')            -> n'
              (PyStr s)             -> "\"" ++ s ++ "\""
              (PyBool b)            -> show b
              (PyTuple t)           -> "(" ++ L.intercalate "," (toPY 0 <$> t) ++ ")"
              l@(PyList{})          -> list2py n l
              (PyVar n1 b@(PyFn{})) -> fn2py n n1 b
              (PyVar n1 b)          -> n1 ++ " = " ++ toPY n b
              f@(PyFn{})            -> lfn2py n f
              o@(PyNewObj{})        -> new2py n o
              d@(PyProp{})          -> dot2py n d
              d@(PyObjCall{})       -> dot2py n d
              d@(PyDefClass{})      -> defclass2py n d
              m@(PyMap{})           -> map2py n m
              PyPleaseIgnore        -> ""
              f@(PyFnCall{})        -> fnCall2py n f
              (PyThing x)           -> x
              x -> error $ "PyVal=(" ++ show x ++ ") should not be toPY'ed"

fnCall2py :: Int -> PyVal -> String
fnCall2py n (PyFnCall fn args)
          | isJust specForm = fromJust $ specForm <*> Just args
          | otherwise       = printf "%s(%s)" (lookupFn fn) args'
    where args' = L.intercalate ", " . filter (/= "") $ toPY n <$> args
          specForm = lookupSpecForm n fn
fnCall2py _ x = catch . throwError . TypeMismatch "PyFnCall" $ show x

map2py :: Int -> PyVal -> String
map2py n (PyMap ks vs) = printf "{%s}" kvs
    where kvs = L.intercalate ", " $ zipWith (\k v -> k ++ " : " ++ toPY n v) ks vs
map2py _ x = catch . throwError . TypeMismatch "PyMap" $ show x

new2py :: Int -> PyVal -> String
new2py n (PyNewObj className args) = printf "%s(%s)" className args'
  where args' = L.intercalate ", " $ toPY n <$> args
new2py _ x = catch . throwError . TypeMismatch "PyNewObj" $ show x

defclass2py :: Int -> PyVal -> String
defclass2py n (PyDefClass name superClasses constr fs vars) =
                printf "class %s(%s):\n%s%s%s"
                name superClasses' constr' addVars (fns2py (n + 1) fs)
    where
        superClasses' = L.intercalate ", " superClasses
        constr' = case constr of
                      PyPleaseIgnore -> ""
                      (PyConst args cbody) -> printf "%sdef __init__(%s):\n%s" (addSpacing (n + 1)) (addArgs args) (addCons n cbody)
                      x -> catch . throwError . TypeMismatch "PyConst" $ show x
        addArgs args = L.intercalate ", " ("self":args)
        addCons n' body = (++ "\n") . concat $ body2py (n' + 2) body
        body2py :: Int -> [(String, PyVal)] -> [String]
        body2py n' = fmap (propVal2js n')
        propVal2js :: Int -> (String, PyVal) -> String
        propVal2js n' ("eval",PyList evalMe) =
            (addSpacing n' ++) . L.intercalate ("\n" ++ addSpacing n')
            $ toPY n' <$> evalMe
        propVal2js n' (_,PyClassSuper superName superArgs) =
            let superArgs' = L.intercalate "," $ toPY 0 <$> superArgs
                superArgs'' = if null superArgs' then "" else "," ++ superArgs'
            in printf "%s%s.__init__(self%s)\n" (addSpacing n') superName superArgs''
        propVal2js n' (p,v) = printf "%sself.%s = %s\n" (addSpacing n') p (toPY 0 v)

        addVars = vars2py (n + 1) vars
        vars2py :: Int -> [PyVal] -> String
        vars2py n' = concat . fmap (\(PyClassVar varName x) ->
            printf (addSpacing n' ++ "%s = %s\n") varName (toPY 0 x))

        fn2py_ :: Int -> PyVal -> String
        fn2py_ n' (PyClassFn fn pms body) =
            printf "%sdef %s (%s):\n"
            (addSpacing n') fn (L.intercalate ", " ("self":pms))
            ++ (if null (init body)
                    then ""
                    else addSpacing (n'+1)
                         ++ L.intercalate ("\n" ++ (addSpacing (n'+1)))
                                     (toPY n' <$> (init body))
                         ++ "\n")
            ++ printf "%sreturn %s\n" (addSpacing (n'+1)) (toPY n' (last body))
        fn2py_ _ x = catch . throwError . TypeMismatch "PyClassFn" $ show x
        fns2py :: Int -> [PyVal] -> String
        fns2py _ [] = []
        fns2py n' l = (++ "\n") . L.intercalate "\n" $ map (fn2py_ n') l
defclass2py _ x = catch . throwError . TypeMismatch "PyDefClass" $ show x

list2py :: Int -> PyVal -> String
list2py n l = case l of
              (PyList [PyId "quote", ql]) -> toPY n ql
              (PyList xs) -> printf "[%s]" (L.intercalate ", " (fmap (toPY n) xs))
              x -> catch . throwError . TypeMismatch "PyList" $ show x

id2py :: Int -> PyVal -> String
id2py _ (PyId pv) = lookupID pv
id2py _ x = catch . throwError . TypeMismatch "PyId" $ show x

fn2py :: Int -> String -> PyVal -> String
fn2py n n1 (PyFn params body) = printf "def %s (%s):\n%s" n1 params' body'
    where
        params' = L.intercalate ", " params
        body' = addSpacing (n + 1) ++ showBody body
        showBody [] = []
        showBody (b:q:bs) = let b' = toPY n b
                                b'' = showBody (q:bs)
                            in b' ++ "\n" ++ addSpacing (n + 1) ++ b''
        showBody [b] = "return " ++ toPY n b
fn2py _ _ x = catch . throwError . TypeMismatch "PyFn" $ show x

lfn2py :: Int -> PyVal -> String
lfn2py _ (PyFn params body) = printf "(lambda %s : [%s])" params' body'
    where
        params' = L.intercalate ", " params
        body' = L.intercalate ", " $ toPY 0 <$> body
lfn2py _ x = catch .throwError . TypeMismatch "PyFn" $ show x

dot2py :: Int -> PyVal -> String
dot2py n (PyProp prop obj) = printf "%s%s.%s" (addSpacing n) obj prop
dot2py n (PyObjCall fnProp objName args) =
        printf "(%s.%s(%s) if callable(%s.%s) else %s.%s)"
        (toPY n objName) fnProp params' (toPY n objName) fnProp (toPY n objName) fnProp
    where
        params' = L.intercalate ", " $ toPY n <$> args
dot2py _ x = catch . throwError . TypeMismatch "PyObjCall" $ show x

addSpacing :: Int -> String
addSpacing weight = replicate (weight * 4) ' '
