module LispPy where

import Control.Applicative hiding (many, (<|>), Const)
import Control.Monad.Except

import qualified Data.List as L
import qualified Data.Map as M
import Data.Maybe
import Data.Char (toLower)

import Utils

formatPy :: [String] -> IO String
formatPy py = do helperFns <- readFile "helperFunctions.py"
                 let py' = L.intercalate "\n" py
                 return $ helperFns ++ py'

primitives :: M.Map String String
primitives = M.fromList [("+", "plus")
                        ,("-", "minus")
                        ,("*", "mult")
                        ,("/", "div")
                        ,("=", "eq")
                        ,("!=", "neq")
                        ,("<", "lt")
                        ,("<=", "lte")
                        ,(">", "gt")
                        ,(">=", "gte")
                        ,("and", "and_")
                        ,("or", "or_")]

lookupFn :: String -> String
lookupFn f = fromMaybe f $ M.lookup f primitives

data PyVal = PyVar String PyVal                -- x = ...
           | PyFn [String] [PyVal]             -- function(...){...}
           | PyStr String                      -- "..."
           | PyBool Bool                       -- true|false
           | PyNum Integer                     -- ..-1,0,1..
           | PyId String                       -- x, foo, ...
           | PyObjCall String String [PyVal]   -- x.foo.bar(...)
           | PyFnCall String [PyVal]           -- foo(...)
           | PyNewObj String [PyVal]                 -- new Foo (..)
           | PyDefClass String PyVal [PyVal] [PyVal] -- function Class(..) {..}
           | PyConst [String] PyVal                  -- Class(..) {..}
           | PyClassFn String [String] PyVal         -- Class.prototype.fn = function(..){..}
           | PyClassVar String PyVal  
           | PyList [PyVal]                    -- [...]
           | PyThing String                    -- ???
           deriving (Eq, Show)

translate :: LispVal -> PyVal
translate v = case v of
                  (Atom a) -> PyId a
                  (Number n) -> PyNum n
                  (String s) -> PyStr s
                  (Bool b) -> PyBool b
                  (Def n b) -> PyVar n (translate b)
                  (Fn xs b) -> PyFn xs (translate <$> b)
                  (New s l) -> PyNewObj s (translate <$> l)
                  (DefClass n c lf lv) -> PyDefClass n (translate c) (translate <$> lf) (translate <$> lv)
                  (Const s b) -> PyConst s (translate b)
                  (Classfn s p b) -> PyClassFn s p (translate b)
                  (Classvar s b) -> PyClassVar s (translate b)
                  l@(List _) -> list2pyVal l
                  (Dot fp on ps) -> PyObjCall fp on (translate <$> ps)
                  _ -> PyThing $ show v
      where
        list2pyVal :: LispVal -> PyVal
        list2pyVal l = case l of
                           (List (Atom a:args)) -> PyFnCall a $ translate <$> args
                           x -> catch . throwError . TypeMismatch "List" $ show x

toPY :: PyVal -> String
toPY pv = case pv of
              a@(PyId{})            -> id2py a
              (PyNum n)             -> show n
              (PyStr s)             -> "\"" ++ s ++ "\""
              (PyBool b)            -> toLower <$> show b
              l@(PyList{})          -> list2py l
              (PyVar n b)           -> n ++ " = " ++ toPY b
              f@(PyFn{})            -> fn2py f
              d@(PyObjCall{})       -> dot2py d
              d@(PyDefClass{})      -> defclass2py d
              (PyFnCall n as)
                  | lookupFn n /= n -> lookupFn n ++ "([" ++ args ++ "])"
                  | otherwise       -> lookupFn n ++ "(" ++ args ++ ")"
                  where
                    args = L.intercalate ", " $ toPY <$> as
              _ -> show pv

defclass2py :: PyVal -> String
defclass2py (PyDefClass name (PyConst args body) _ vars) = "class " ++ name ++ ":\n"
                ++ addSpacing 1 ++ "def __init__(self, " ++ args' ++ "):\n" ++
                addSpacing 2 ++ "self." ++ consBody
                where
                  args' =  L.intercalate ", " args
                  consBody = (toPY body)

list2py :: PyVal -> String
list2py l = case l of
              (PyList [PyId "quote", ql]) -> toPY ql
              (PyList xs) -> "[" ++ L.intercalate ", " (fmap toPY xs) ++ "]"
              x -> catch . throwError . TypeMismatch "PyList" $ show x

id2py :: PyVal -> String
id2py (PyId pv) = pv
id2py x = catch . throwError . TypeMismatch "PyId" $ show x

fn2py :: PyVal -> String
fn2py (PyFn params body) = "(lambda " ++ params' ++ " : " ++ showBody body ++ ")"
      where
        params' = L.intercalate ", " params
        showBody [] = []
        showBody (b:q:bs) = toPY b ++ ";\n" ++ showBody (q:bs)
        showBody [b] = toPY b
fn2py x = catch . throwError . TypeMismatch "PyFn" $ show x

dot2py :: PyVal -> String
dot2py (PyObjCall fp on ps)
      | ps /= [] = on ++ "." ++ fp ++ "(" ++ params' ++ ")"
      | otherwise = on ++ "." ++ fp
      where
        params' = L.intercalate ", " $ toPY <$> ps
dot2py x = catch . throwError . TypeMismatch "PyObjCall" $ show x

--Use for: if, for, while, anything else. Make sure to pass around a weight and
--increment and decrement accordingly
addSpacing :: Int -> String
addSpacing weight = replicate (weight * 4) ' '
