theory GExp
imports AExp
begin
datatype gexp = Bc bool | Eq aexp aexp | Gt aexp aexp | Lt aexp aexp | Nor gexp gexp

abbreviation gNot :: "gexp \<Rightarrow> gexp" where
  "gNot g \<equiv> Nor g g"

abbreviation
  Le :: "aexp \<Rightarrow> aexp \<Rightarrow> gexp" where
  "Le v va \<equiv> gNot (Gt v va)"

abbreviation
  Ge :: "aexp \<Rightarrow> aexp \<Rightarrow> gexp" where
  "Ge v va \<equiv> gNot (Lt v va)"

abbreviation
  Ne :: "aexp \<Rightarrow> aexp \<Rightarrow> gexp" where
  "Ne v va \<equiv> gNot (Eq v va)"

abbreviation gOr :: "gexp \<Rightarrow> gexp \<Rightarrow> gexp" where
  "gOr v va \<equiv> gNot (Nor v va)"

abbreviation gAnd :: "gexp \<Rightarrow> gexp \<Rightarrow> gexp" where
  "gAnd v va \<equiv> Nor (Nor v v) (Nor va va)"

fun gval :: "gexp \<Rightarrow> state \<Rightarrow> bool" where
  "gval (Bc b) _ = b" |
  "gval (Lt a\<^sub>1 a\<^sub>2) s = (aval a\<^sub>1 s < aval a\<^sub>2 s)" |
  "gval (Gt a\<^sub>1 a\<^sub>2) s = (aval a\<^sub>1 s > aval a\<^sub>2 s)" |
  "gval (Eq a\<^sub>1 a\<^sub>2) s = (aval a\<^sub>1 s = aval a\<^sub>2 s)" |
  "gval (Nor a\<^sub>1 a\<^sub>2) s = (\<not> (gval a\<^sub>1 s \<or> gval a\<^sub>2 s))"

lemma "gval (gNot (gOr a b)) = gval (Nor a b)"
  by auto

abbreviation gexp_satisfiable :: "gexp \<Rightarrow> bool" where
  "gexp_satisfiable g \<equiv> (\<exists>s. gval g s)"

abbreviation gexp_equiv :: "gexp \<Rightarrow> gexp \<Rightarrow> bool" where
  "gexp_equiv v va \<equiv> \<forall>s. gval v s = gval va s"
end