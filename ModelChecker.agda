module ModelChecker where

open import Data.Product hiding (map)
open import Coinduction
open import Data.List as L hiding (all; any; and; or)
open import Data.List.All as All hiding (map; all)
open import Data.List.Any as Any hiding (map; any)
open import Data.Nat
open import Relation.Binary.PropositionalEquality hiding ([_])
open import Data.Unit hiding (_≟_)
open import Function

open import Data.Maybe as M hiding (map; All; Any)
open import Category.Monad
import Level
open RawMonad (M.monad {Level.zero})
open import Properties

open IsProp ⦃ ... ⦄

record Diagram (L : Set)(Σ : Set) : Set₁ where
  constructor td
  field
      δ : L × Σ → List (L × Σ)
      I : L

_∥_ : ∀{L₁ L₂ : Set}{Σ}
    → Diagram L₁ Σ → Diagram L₂ Σ
    → Diagram (L₁ × L₂) Σ
(td δ₁ i₁) ∥ (td δ₂ i₂) = td δ (i₁ , i₂)
  where
    δ = (λ { ((ℓ₁ , ℓ₂) , σ) →
       map (λ { (ℓ₁′ , σ′) → (ℓ₁′ , ℓ₂ ) , σ′ }) (δ₁ (ℓ₁ , σ)) ++
       map (λ { (ℓ₂′ , σ′) → (ℓ₁  , ℓ₂′) , σ′ }) (δ₂ (ℓ₂ , σ)) })

module CTL(L Σ : Set) where

  data CT : Set where
    At : (L × Σ) → ∞ (List CT) → CT

  follow    : (δ : (L × Σ) → List (L × Σ)) → (L × Σ) → CT
  followAll : (δ : (L × Σ) → List (L × Σ)) → List (L × Σ) → List CT
  follow    δ σ        = At σ (♯ followAll δ (δ σ))
  followAll δ (σ ∷ σs) = follow δ σ ∷ followAll δ σs
  followAll δ []       = []

  model : Diagram L Σ → Σ → CT
  model (td δ I) σ = follow δ (I , σ)

  Formula = (ℕ → CT → Set)

  data _⊧_ (m : CT)(φ : Formula) : Set where
    models : ∀ d₀ → (∀ { d } → d₀ ≤′ d → φ d m) → m ⊧ φ

  Depth-Invariant : (φ : Formula) → Set
  Depth-Invariant φ = (∀{n}{m} → φ n m → φ (suc n) m)

  data A[_U_] (φ ψ : Formula) : Formula where
    here  : ∀{t}{n} → ψ n t → A[ φ U ψ ] (suc n) t
    there : ∀{σ}{ms}{n}
          → φ n (At σ ms)
          → All (A[ φ U ψ ] n) (♭ ms)
          → A[ φ U ψ ] (suc n) (At σ ms)

  data Completed : Formula where
    completed : ∀{σ}{n}{ms}
              → ♭ ms ≡ []
              → Completed n (At σ ms)

  data _∧′_ (φ ψ : Formula ) : Formula where
    _,_ : ∀{n}{m} → φ n m → ψ n m → (φ ∧′ ψ) n m

  infixr 100 _∧′_
  data True : Formula where
    tt : ∀{n}{m} → True n m
  data False : Formula where


  instance
    Completed-di : Depth-Invariant Completed
    Completed-di (completed x) = completed x

  AF : Formula → Formula
  AF φ = A[ True U φ ]

  AG : Formula → Formula
  AG φ = A[ φ U φ ∧′ Completed ]

  instance
    A-di : ∀{φ ψ}
         → ⦃ p : Depth-Invariant φ ⦄
         → ⦃ q : Depth-Invariant ψ ⦄
         → Depth-Invariant A[ φ U ψ ]
    A-di ⦃ p ⦄ ⦃ q ⦄ (here x) = here (q x)
    A-di ⦃ p ⦄ ⦃ q ⦄ (there x ys) = there (p x) (All.map (A-di ⦃ p ⦄ ⦃ q ⦄) ys)

  data E[_U_] (φ ψ : Formula) : Formula where
    here  : ∀{t}{n} → ψ n t → E[ φ U ψ ] (suc n) t
    there : ∀{σ}{ms}{n} → φ n (At σ ms) → Any (E[ φ U ψ ] n) (♭ ms) → E[ φ U ψ ] (suc n) (At σ ms)

  EF : Formula → Formula
  EF φ = E[ True U φ ]

  EG : Formula → Formula
  EG φ = E[ φ U φ ∧′ Completed ]


  instance
    E-di : ∀{φ ψ}
         → ⦃ p : Depth-Invariant φ ⦄
         → ⦃ q : Depth-Invariant ψ ⦄
         → Depth-Invariant E[ φ U ψ ]
    E-di ⦃ p ⦄ ⦃ q ⦄ (here x) = here (q x)
    E-di ⦃ p ⦄ ⦃ q ⦄ (there x y)
      = there (p x) (Any.map (E-di ⦃ p ⦄ ⦃ q ⦄) y)

    True-di : Depth-Invariant True
    True-di _ = tt

    ∧′-di : ∀{φ ψ}
          → ⦃ p : Depth-Invariant φ ⦄
          → ⦃ q : Depth-Invariant ψ ⦄
          → Depth-Invariant (φ ∧′ ψ)
    ∧′-di ⦃ p ⦄ ⦃ q ⦄ (x , y) = p x , q y

  data ⟨_⟩ (p : ⦃ σ : Σ ⦄ → ⦃ ℓ : L ⦄ → Set) : Formula where
    here : ∀{σ}{ℓ}{ms}{n} → p ⦃ σ ⦄ ⦃ ℓ ⦄ → ⟨ p ⟩ n (At (ℓ , σ) ms)

  instance
    ⟨⟩-di : ∀{p : ⦃ σ : Σ ⦄ → ⦃ ℓ : L ⦄ → Set }
          → Depth-Invariant ⟨ p ⟩
    ⟨⟩-di (here x) = here x


  di-≤ : ∀{m}{n n′} φ
       → Depth-Invariant φ
       → φ n m
       → n ≤′ n′ → φ n′ m
  di-≤ φ p q ≤′-refl = q
  di-≤ φ p q (≤′-step l) = p (di-≤ φ p q l)

  di-⊧ : ∀{n}{φ}{m} → ⦃ p : Depth-Invariant φ ⦄ → φ n m → m ⊧ φ
  di-⊧ {n}{φ} ⦃ d ⦄ p = models n (λ q → di-≤ φ d p q)


  a-u : ∀{φ ψ : Formula}
      → ( (m : CT)(n : ℕ) → Property (φ n m) )
      → ( (m : CT)(n : ℕ) → Property (ψ n m) )
      → (m : CT)(n : ℕ)
      → Property (A[ φ U ψ ] n m)
  a-u _ _ _ zero = nothing
  a-u p₁ p₂ (At σ ms) (suc n) with p₂ (At σ ms) n
  ... | just p  = just (here p)
  ... | nothing = p₁ (At σ ms) n
              >>= λ p → there p ⟨$⟩ all (♭ ms) (λ m → a-u p₁ p₂ m n)

  af : ∀{φ : Formula}
     → ( (m : CT)(n : ℕ) → Property (φ n m) )
     → (m : CT)(n : ℕ)
     → Property (AF φ n m)
  af p m n = a-u (λ _ _ → just tt) p m n


  and′ : ∀ {φ ψ  : Formula}
     → ( (m : CT)(n : ℕ) → Property (φ n m) )
     → ( (m : CT)(n : ℕ) → Property (ψ n m) )
     → (m : CT)(n : ℕ)
     → Property ((φ ∧′ ψ) n m)
  and′ a b m n = pure _,_ ⊛ a m n ⊛ b m n


  completed? : ∀ m n → Property (Completed n m)
  completed? (At σ ms) _ = completed ⟨$⟩ empty? (♭ ms)
    where
      empty? : ∀{X}(n : List X) → Property (n ≡ [])
      empty? []      = just refl
      empty? (_ ∷ _) = nothing

  ag : ∀{φ : Formula}
     → ( (m : CT)(n : ℕ) → Property (φ n m) )
     → (m : CT)(n : ℕ)
     → Property (AG φ n m)
  ag p = a-u p (and′ p completed?)


  e-u : ∀{φ ψ : Formula}
      → ( (m : CT)(n : ℕ) → Property (φ n m) )
      → ( (m : CT)(n : ℕ) → Property (ψ n m) )
      → (m : CT)(n : ℕ)
      → Property (E[ φ U ψ ] n m)
  e-u _ _ _ zero = nothing
  e-u p₁ p₂ (At σ ms) (suc n) with p₂ (At σ ms) n
  ... | just p  = just (here p)
  ... | nothing = p₁ (At σ ms) n
              >>= λ p → there p ⟨$⟩ any (♭ ms) (λ m → e-u p₁ p₂ m n)

  ef : ∀{φ : Formula}
     → ( (m : CT)(n : ℕ) → Property (φ n m) )
     → (m : CT)(n : ℕ)
     → Property (EF φ n m)
  ef p m n = e-u (λ _ _ → just tt) p m n

  eg : ∀{φ : Formula}
     → ( (m : CT)(n : ℕ) → Property (φ n m) )
     → (m : CT)(n : ℕ)
     → Property (EG φ n m)
  eg p = e-u p (and′ p completed?)


  now : ∀{ p : ⦃ σ : Σ ⦄ → ⦃ ℓ : L ⦄ → Set }{prop}
      → ⦃ pr : IsProp prop ⦄
      → (⦃ σ : Σ ⦄ → ⦃ ℓ : L ⦄ → prop (p ⦃ σ ⦄ ⦃ ℓ ⦄) )
      → (m : CT)(n : ℕ)
      → Property (⟨ p ⟩ n m)
  now p₁ (At (ℓ , σ) ms) _ = here ⟨$⟩ conversion (p₁ ⦃ σ ⦄ ⦃ ℓ ⦄)



