The DeBruijn module implements the Normal Form function by
using de Bruijn indicies.

It uses parallel substitutions and explcit substitutions stored in the term.

potential optimizations

1. smart constructor in subst s2 (DS s1 a)
2. smart constructor in lift
3. check for subst (Inc 0)
4. ! in Sub definition
5. ! in DB definition


NONE:   user	0m6.655s
1:      user	0m0.038s   (almost as fast at H, at user	0m0.030s)
1,2:    user	0m0.565s
2:      user    0m6.262s
1,3:    user	0m0.040s
1,4:    user	0m0.036s
1,4,5:  user	0m0.026s   (faster than H!)
1,2,4,5: (took too long!)
1,3,4,5: user	0m0.027s
1,3,4,5,6: user	0m0.010s
user	0m0.009s

> module DeBruijnParB(nf) where
> import Data.List(elemIndex)
> import Lambda
> import IdInt
> import Subst

> import Text.PrettyPrint.HughesPJ(Doc, renderStyle, style, text,
>            (<+>), parens)
> import qualified Text.PrettyPrint.HughesPJ as PP

Variables are represented by their binding depth, i.e., how many
$\lambda$s out the binding $\lambda$ is.  Free variables are represented
by negative numbers.

This version adds an explicit substitution to the data type that allows
the sub to be suspended (and perhaps optimized).

> -- 5 -- make fields strict
> data DB = DVar !Int | DLam !(Bind DB) | DApp !DB !DB

Alpha equivalence requires pushing delayed substitutions into the terms

> instance Eq DB where
>    DVar x == DVar y = x == y
>    DLam x == DLam y = x == y
>    DApp x1 x2 == DApp y1 y2 = x1 == x2 && y1 == y2
>    _ == _           = False


> nf :: LC IdInt -> LC IdInt
> nf = fromDB . nfd . toDB

Computing the normal form proceeds as usual. Should never return a delayed substitution anywhere in the term.

> nfd :: DB -> DB
> nfd e@(DVar _) = e
> nfd (DLam b) = DLam (bind (nfd (unbind b)))
> nfd (DApp f a) =
>     case whnf f of
>         DLam b -> nfd (instantiate b a)
>         f' -> DApp (nfd f') (nfd a)

Compute the weak head normal form. Should never return a delayed substitution at the top level.

> whnf :: DB -> DB
> whnf e@(DVar _) = e
> whnf e@(DLam _) = e
> whnf (DApp f a) =
>     case whnf f of
>         DLam b -> whnf (instantiate b a)
>         f' -> DApp f' a

Substitution needs to adjust the inserted expression
so the free variables refer to the correct binders.

> -- push the substitution in one level
> instance SubstC DB where
>   var = DVar
>
>   {-# SPECIALIZE subst :: Sub DB -> DB -> DB #-}
>   -- 3 -- subst (Inc 0) e    = e   -- can discard an identity substitution
>   subst s (DVar i)   = applySub s i
>   subst s (DLam b) = DLam (substBind s b)
>   subst s (DApp f a) = DApp (subst s f) (subst s a) 



Convert to deBruijn indicies.  Do this by keeping a list of the bound
variable so the depth can be found of all variables.  Do not touch
free variables.

> toDB :: LC IdInt -> DB
> toDB = to []
>   where to vs (Var v@(IdInt i)) = maybe (DVar i) DVar (elemIndex v vs)
>         to vs (Lam x b) = DLam (bind (to (x:vs) b))
>         to vs (App f a) = DApp (to vs f) (to vs a)

Convert back from deBruijn to the LC type.

> fromDB :: DB -> LC IdInt
> fromDB = from firstBoundId
>   where from (IdInt n) (DVar i) | i < 0 = Var (IdInt i)
>                                 | otherwise = Var (IdInt (n-i-1))
>         from n (DLam b)   = Lam n (from (succ n) (unbind b))
>         from n (DApp f a) = App (from n f) (from n a)

---------------------------------------------------------

> instance Show DB where
>     show = renderStyle style . ppLC 0


> ppLC :: Int -> DB -> Doc
> ppLC _ (DVar v)   = text $ "x" ++ show v
> ppLC p (DLam b) = pparens (p>0) $ text ("\\.") PP.<> ppLC 0 (unbind b)
> ppLC p (DApp f a) = pparens (p>1) $ ppLC 1 f <+> ppLC 2 a


> ppS :: Sub DB -> Doc
> ppS (Inc k)     = text ("+" ++ show k)
> ppS (Cons t s)  = ppLC 0 t <+> text "<|" <+> ppS s
> ppS (s1 :<> s2) = ppS s1 <+> text "<>" <+> ppS s2


> pparens :: Bool -> Doc -> Doc
> pparens True d = parens d
> pparens False d = d