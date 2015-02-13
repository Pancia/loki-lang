module LispJs where

import Control.Applicative hiding (many, (<|>), Const)
import Control.Monad.Except

import qualified Data.List as L
import qualified Data.Map as M
import Data.Maybe
import Data.Char (toLower)

import Utils

primitives :: M.Map String String
primitives = M.fromList [("log", "print")
                        ,("+", "plus")
                        ,("-", "minus")
                        ,("*", "mult")
                        ,("/", "div")
                        ,("=", "eq")
                        ,("!=", "neq")
                        ,("<", "lt")
                        ,("<=", "lte")
                        ,(">", "gt")
                        ,(">=", "gte")]

type SpecialForm = [JsVal] -> String
specialForms :: M.Map String SpecialForm
specialForms = M.fromList [("if", if_)]
    where
        if_ :: SpecialForm
        if_ [cond_, then_, else_] = "(" ++ toJS cond_ ++ " ? " ++ toJS then_ ++ " : " ++ toJS else_ ++ ")"
        if_ [cond_, then_] = if_ [cond_, then_, JsId "null"]
        if_ _ = error "wrong args to if"

lookupFn :: String -> String
lookupFn f = fromMaybe f $ M.lookup f primitives

lookupSpecForm :: String -> Maybe SpecialForm
lookupSpecForm s = M.lookup s specialForms

formatJs :: [String] -> IO String
formatJs js = do helperFns <- readFile "helperFunctions.js"
                 let js' = (++ ";") . L.intercalate ";\n" $ js
                 return $ helperFns ++ js'

data JsVal = JsVar String JsVal                      -- var x = ..
           | JsFn [String] [JsVal]                   -- function(..){..}
           | JsStr String                            -- ".."
           | JsBool Bool                             -- true|false
           | JsNum Integer                           -- ..-1,0,1..
           | JsId String                             -- x, foo, ..
           | JsObjCall String [String] [JsVal]       -- x.foo.bar(..)
           | JsFnCall String [JsVal]                 -- foo(..)
           | JsNewObj String [JsVal]                 -- new Foo (..)
           | JsDefClass String JsVal [JsVal] [JsVal] -- function Class(..) {..}
           | JsConst [String] JsVal                  -- Class(..) {..}
           | JsClassFn String [String] JsVal         -- Class.prototype.fn = function(..){..}
           | JsClassVar String JsVal                 -- Class(..) {this.var = val}
           | JsDotThing String String [JsVal]        -- .function objname parameters*
           | JsList [JsVal]                          -- [] | [x,..]
           deriving (Eq, Show)

translate :: LispVal -> JsVal
translate v = case v of
                  (Atom a) -> JsId a
                  (Bool b) -> JsBool b
                  (Def n b) -> JsVar n (translate b)
                  (Fn xs b) -> JsFn xs (translate <$> b)
                  l@(List _) -> list2jsVal l
                  (Number n) -> JsNum n
                  (String s) -> JsStr s
                  (New s l) -> JsNewObj s (translate <$> l)
                  (DefClass n c lf lv) -> JsDefClass n (translate c) (translate <$> lf) (translate <$> lv)
                  (Const s b) -> JsConst s (translate b)
                  (Classfn s p b) -> JsClassFn s p (translate b)
                  (Classvar s b) -> JsClassVar s (translate b)
                  (Dot fp on ps) -> JsDotThing fp on (translate <$> ps)

    where
        list2jsVal :: LispVal -> JsVal
        list2jsVal l = case l of
                        (List [Atom "quote", ql]) -> translate ql
                        (List [Atom a]) -> JsFnCall a []
                        (List (Atom a:(arg:args)))
                            | last a == '.' -> JsObjCall a [show $ translate arg] $ translate <$> args
                            | otherwise     -> JsFnCall a $ translate <$> (arg:args)
                        (List xs) -> JsList $ translate <$> xs
                        x -> catch . throwError $ TypeMismatch "List" $ show x

toJS :: JsVal -> String
toJS jv = case jv of
              a@(JsId{})       -> id2js a
              (JsNum n)        -> show n
              (JsStr s)        -> "\"" ++ s ++ "\""
              (JsBool x)       -> toLower <$> show x
              l@(JsList{})     -> list2js l
              v@(JsVar{})      -> var2js v
              f@(JsFn{})       -> fn2js f
              x@(JsObjCall{})  -> objCall2js x
              f@(JsFnCall{})   -> fnCall2js f
              d@(JsDotThing{}) -> dot2js d
              d@(JsDefClass{}) -> defclass2js d
              x -> error "JsVal=(" ++ show x ++ ") should not be toJS'ed"

defclass2js :: JsVal -> String
defclass2js (JsDefClass name (JsConst args _) _ vars) =
        "function " ++ name ++ "(" ++  params ++ ") {\n" ++
        classVars2js vars ++ "\n}"
    where params = L.intercalate ", " args
          classVars2js :: [JsVal] -> String
          classVars2js = L.intercalate ";\n" . map (\(JsClassVar s b)  -> "this." ++ s ++ " = " ++ toJS b)
defclass2js x = catch . throwError . TypeMismatch "JsDefClass" $ show x

objCall2js :: JsVal -> String
objCall2js (JsObjCall _obj _props _args) = undefined
objCall2js x = catch . throwError . TypeMismatch "JsObjCall" $ show x

fnCall2js :: JsVal -> String
fnCall2js (JsFnCall fn args)
        | isJust specForm = fromJust specForm args
        | otherwise = lookupFn fn ++ "(" ++ args' ++ ")"
    where args' = L.intercalate ", " $ toJS <$> args
          specForm = lookupSpecForm fn
fnCall2js x = catch . throwError . TypeMismatch "JsFnCall" $ show x

dot2js :: JsVal -> String
dot2js (JsDotThing fp on ps)
        | ps /= [] = on ++ "." ++ fp ++ "(" ++ args' ++ ")"
		| otherwise = on ++ "." ++ fp
     where args' = L.intercalate ", " $ toJS <$> ps
dot2js x = catch . throwError . TypeMismatch "JsDotThing" $ show x

id2js :: JsVal -> String
id2js (JsId a) = a
id2js x = catch . throwError . TypeMismatch "JsId" $ show x

fn2js :: JsVal -> String
fn2js (JsFn params body) = "function (" ++ params' ++ ") {\n" ++ showBody body ++ "\n}"
    where params' = L.intercalate ", " params
          showBody [] = []
          showBody (b:q:bs) = toJS b ++ ";\n" ++ showBody (q:bs)
          showBody [b] = "return " ++ toJS b
fn2js x = catch . throwError . TypeMismatch "JsFn" $ show x

var2js :: JsVal -> String
var2js (JsVar name body) = "var " ++ name ++ " = " ++ toJS body
var2js x = catch . throwError . TypeMismatch "JsVar" $ show x

list2js :: JsVal -> String
list2js l = case l of
               (JsList [JsId "quote", ql]) -> toJS ql
               (JsList xs) -> "[" ++ L.intercalate ", " (fmap toJS xs) ++ "]"
               x -> catch . throwError . TypeMismatch "JsList" $ show x
