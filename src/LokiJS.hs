module LokiJS where

import Control.Applicative hiding (many, (<|>))
import Control.Monad.Except

import qualified Data.List as L
import qualified Data.Map as M
import Data.Maybe
import Data.Char (toLower)
import Text.Printf (printf)

import Utils

-- Contains code that converts symbols from their lisp form
-- to their equivalent name in helperFunctions.js
primitives :: M.Map String String
primitives = M.fromList $ fmap addLokiPrefix $ fmap encodeID'
        [("+", "plus"),("-", "minus"),("*", "mult"),("/", "div"),("=", "eq")
        ,("!=", "neq"),("<", "lt"),("<=", "lte"),(">", "gt"),(">=", "gte")]
        ++ (dupl <$> ["print","mod","assoc","range","get","and","or"])
    where
        encodeID' (s,_q) = (encodeID s,_q)
        addLokiPrefix (_q,s) = (_q,"loki." ++ s)
        dupl x = (x,x)

lookupFn :: String -> String
lookupFn f = fromMaybe f $ M.lookup f primitives

-- Contains that will expand special forms from lisp to JS
-- for usage temporarily in place of macros
--      (ie where functions would not suffice)
type SpecialForm = [JsVal] -> String
specialForms :: M.Map String SpecialForm
specialForms = M.fromList [("if", if_),("set", set),("setp", setp)
                          ,("import", import_),("for", for_)]
    where
        import_ :: SpecialForm
        import_ [JsStr importMe] = printf "import %s" importMe
        import_ [JsStr importMe, JsStr "from", JsStr fromMe] =
            printf "var %s = require('%s')" fromMe importMe
        import_ x = error $ (show x ?> "import_") ++ "wrong args to import_"
        setp :: SpecialForm
        setp [JsId var, JsId prop, val] = let val' = fromJust $ toJS val
                                          in printf "%s.%s = %s" var prop val'
        setp _ = error "wrong args to setp"
        set :: SpecialForm
        set [JsId var, val] = let val' = fromJust $ toJS val
                              in printf "%s = %s" var val'
        set x = error $ (show x ?> "set: ") ++ "wrong args to set"
        if_ :: SpecialForm
        if_ [cond_, then_, else_] = do
            let cond_' = fromJust $ toJS cond_
                then_' = fromJust $ toJS then_
                else_' = fromJust $ toJS else_
            printf "(%s?%s:%s)" cond_' then_' else_'
        if_ [cond_, then_] = if_ [cond_, then_, JsId "null"]
        if_ _ = error "wrong args to if"
        for_ :: SpecialForm
        for_ (JsList [id_, expr_] : body_) = do
            let id_'   = fromJust $ toJS id_
                expr_' = fromJust $ toJS expr_
                body_' = fromJust . liftM (L.intercalate ";\n") . sequence $ toJS <$> body_
            printf "for (%s in %s){\n%s\n}" id_' expr_' body_'
        for_ x = error $ (show x ?> "for-x") ++ "wrong args to for"

lookupSpecForm :: String -> Maybe SpecialForm
lookupSpecForm s = M.lookup s specialForms

-- Adds helper functions,
-- and converts from [Maybe String] to just one String separed by ;'s and \n's
formatJs :: [Maybe String] -> IO String
formatJs js = do helperFns <- readFile "src/helperFunctions.js"
                 let js' = (++ ";") . L.intercalate ";\n" $ catMaybes js
                 return $ helperFns ++ js'

data JsVal = JsVar String JsVal
           | JsFn [String] [JsVal]
           | JsStr String
           | JsBool Bool
           | JsNum String
           | JsId String
           | JsProp String String
           | JsObjCall String JsVal [JsVal]
           | JsMap [String] [JsVal]
           | JsFnCall String [JsVal]
           | JsNewObj String [JsVal]
           | JsDefClass String [String] JsVal [JsVal] [JsVal]
           | JsConst [String] [(String, JsVal)]
           | JsClassSuper String [JsVal]
           | JsClassFn String [String] [JsVal]
           | JsClassVar String JsVal
           | JsList [JsVal]
           | JsThing String
           | JsNothing
           deriving (Eq, Show)

translate :: LokiVal -> JsVal
translate v = if read (fromJust (M.lookup "fileType" (getMeta v))) /= JS
                  then JsNothing
                  else case v of
                           (LkiNothing _) -> JsNothing
                           (Thing _ x) -> JsThing x
                           (Atom _ a) -> JsId a
                           (Keyword _ k) -> JsStr k
                           (Bool _ b) -> JsBool b
                           (Def _ n b) -> JsVar n (translate b)
                           (Fn _ xs b) -> JsFn xs (translate <$> b)
                           (Array {getArray=a}) -> JsList (translate <$> a)
                           l@(List{}) -> list2jsVal l
                           (Number _ n) -> JsNum n
                           (String _ s) -> JsStr s
                           (New _ s l) -> JsNewObj s (translate <$> l)
                           (DefClass _ n s c lf lv) -> JsDefClass n s (maybe JsNothing translate c) (translate <$> lf) (translate <$> lv)
                           (Constr _ s b) -> JsConst s (translateProp <$> b)
                           (ClassSuper _ n as) -> JsClassSuper n (translate <$> as)
                           (Classfn _ s p b) -> JsClassFn s p (translate <$> b)
                           (Classvar _ s b) -> JsClassVar s (translate b)
                           (Prop _ n o) -> JsProp n o
                           (Dot _ fp on ps) -> JsObjCall fp (translate on) (translate <$> ps)
                           (Tuple{}) -> error "can't convert a tuple"
                           (Map _ ks vs) -> JsMap ks (translate <$> vs)
    where
        translateProp :: (String, LokiVal) -> (String, JsVal)
        translateProp (s, l) = (s, translate l)
        list2jsVal :: LokiVal -> JsVal
        list2jsVal l = case l of
                        (List _ [Atom _ "quote", ql]) -> translate ql
                        (List _ [Atom _ a]) -> JsFnCall a []
                        (List _ (Atom _ a:(arg:args))) -> JsFnCall a $ translate <$> (arg:args)
                        (List _ (f@(Fn{}):args)) -> JsFnCall (fromJust . toJS $ translate f) $ translate <$> args
                        (List _ xs) -> JsList $ translate <$> xs
                        x -> catch . throwError . TypeMismatch "List" $ show x

toJS :: JsVal -> Maybe String
toJS jv = case jv of
              a@(JsId{})       -> id2js a
              (JsNum n)        -> return n
              (JsStr s)        -> return $ "\"" ++ s ++ "\""
              (JsBool x)       -> return $ toLower <$> show x
              l@(JsList{})     -> list2js l
              v@(JsVar{})      -> var2js v
              f@(JsFn{})       -> fn2js f
              f@(JsFnCall{})   -> fnCall2js f
              d@(JsObjCall{})  -> dot2js d
              n@(JsNewObj{})   -> new2js n
              d@(JsDefClass{}) -> defclass2js d
              m@(JsMap{})      -> map2js m
              (JsThing x)      -> return x
              JsNothing        -> Nothing
              x -> error $ "JsVal=(" ++ show x ++ ") should not be toJS'ed"

new2js :: JsVal -> Maybe String
new2js (JsNewObj name args) = return $ printf "new %s(%s)" name args'
    where args' = L.intercalate ", " . catMaybes $ toJS <$> args
new2js x = catch . throwError . TypeMismatch "JsNewObj" $ show x

map2js :: JsVal -> Maybe String
map2js (JsMap ks vs) = do let kvs = zipWith (\k v -> liftM (printf "%s:%s" k)
                                                           (toJS v))
                                            ks vs
                              kvs' = L.intercalate "," . catMaybes $ kvs
                          return $ printf "{%s}" kvs'
map2js x = catch . throwError . TypeMismatch "JsMap" $ show x

defclass2js :: JsVal -> Maybe String
defclass2js (JsDefClass cName superClasses constr fns vars) = do
        let vars' = fromMaybe "" $ classVars2js vars
            fns' = fromMaybe "" $ fns2js fns
        return $ concatMap superToExtend superClasses ++ addCons constr vars' fns'
    where
        superToExtend = printf "loki.extend(%s.prototype, %s.prototype);\n" cName
        addCons :: JsVal -> String -> String -> String
        addCons c vs fs =
           let (args, ret) = fromMaybe ([""], "") $ ret2js c
           in printf "%s.prototype.constructor = %s;\n" cName cName
              ++ printf "function %s(%s) {\n%s;\n%s\n};\n%s"
                 cName (addParams args) vs ret fs
        addParams args = L.intercalate ", " args
        propVal2js :: (String, JsVal) -> Maybe String
        propVal2js ("eval", JsList evalMe) = do
            liftM (L.intercalate ";\n") . sequence $ map toJS evalMe
        propVal2js (_,JsClassSuper superClass superArgs) = do
            superArgs' <- liftM ("," ++) . liftM (L.intercalate ",") $ (sequence $ map toJS superArgs)
            return $ printf "%s.call(this%s)" superClass superArgs'
        propVal2js (k,v) = do v' <- toJS v
                              return $ printf "this.%s = %s" k v'
        ret2js :: JsVal -> Maybe ([String], String)
        ret2js JsNothing = Nothing
        ret2js (JsConst args propVals) = do let pvs = mapMaybe propVal2js propVals
                                            return (args, L.intercalate ";\n" pvs)
        ret2js x = catch . throwError . TypeMismatch "JsConst" $ show x
        classVar2js :: JsVal -> Maybe String
        classVar2js (JsClassVar s b) = do b' <- toJS b
                                          return $ printf "this.%s = %s" s b'
        classVar2js x = catch . throwError . TypeMismatch "JsClassVar" $ show x
        classVars2js :: [JsVal] -> Maybe String
        classVars2js vs = do let vs' = mapMaybe classVar2js vs
                             return $ L.intercalate ";\n" vs'
        fn2js_ :: JsVal -> Maybe String
        fn2js_ (JsClassFn fName params body) = do
            body' <- liftM (L.intercalate "\n") . sequence . map toJS $ init body
            return $ printf "%s.prototype.%s = function(%s) {\n%s\nreturn %s"
                     cName fName (L.intercalate ", " params) body' (fromJust . toJS $ last body)
        fn2js_ x = catch . throwError . TypeMismatch "JsClassFn" $ show x
        fns2js :: [JsVal] -> Maybe String
        fns2js [] = Nothing
        fns2js l = Just $ (++ "\n};") . L.intercalate "\n};\n" . catMaybes $ map fn2js_ l
defclass2js x = catch . throwError . TypeMismatch "JsDefClass" $ show x

fnCall2js :: JsVal -> Maybe String
fnCall2js (JsFnCall fn args)
        | isJust specForm = specForm <*> Just args
        | otherwise = return $ printf "%s(%s)" (lookupFn fn) args'
    where args' = L.intercalate ", " . catMaybes $ toJS <$> args
          specForm = lookupSpecForm fn
fnCall2js x = catch . throwError . TypeMismatch "JsFnCall" $ show x

dot2js :: JsVal -> Maybe String
dot2js (JsProp prop obj) = return $ printf "%s.%s" prop obj
dot2js (JsObjCall fp on args) = do
        on' <- toJS on
        return $ printf "(typeof %s.%s === \"function\" ? %s.%s(%s) : %s.%s)"
                 on' fp on' fp args' on' fp
     where args' = L.intercalate ", " . catMaybes $ toJS <$> args
dot2js x = catch . throwError . TypeMismatch "JsDotThing" $ show x

id2js :: JsVal -> Maybe String
id2js (JsId a) = Just a
id2js x = catch . throwError . TypeMismatch "JsId" $ show x

fn2js :: JsVal -> Maybe String
fn2js (JsFn params body) = do body' <- showBody body
                              return $ printf "function (%s) {\n%s\n}" params' body'
    where params' = L.intercalate ", " params
          showBody :: [JsVal] -> Maybe String
          showBody [] = Nothing
          showBody (b:q:bs) = do b' <- toJS b
                                 b'' <- showBody (q:bs)
                                 return $ b' ++ ";\n" ++ b''
          showBody [b] = liftM ("return " ++) $ toJS b
fn2js x = catch . throwError . TypeMismatch "JsFn" $ show x

var2js :: JsVal -> Maybe String
var2js (JsVar name JsNothing) = return $ printf "var %s" name
var2js (JsVar name body) = do body' <- toJS body
                              return $ printf "var %s = %s" name body'
var2js x = catch . throwError . TypeMismatch "JsVar" $ show x

list2js :: JsVal -> Maybe String
list2js l = case l of
               (JsList [JsId "quote", ql]) -> toJS ql
               (JsList xs) -> Just $ printf "[%s]" $ L.intercalate ", " (catMaybes $ toJS <$> xs)
               x -> catch . throwError . TypeMismatch "JsList" $ show x
