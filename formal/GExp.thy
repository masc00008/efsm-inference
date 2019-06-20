subsection \<open>Guard Expressions\<close>
text\<open>
This theory defines the guard language of EFSMs which can be translated directly to and from
contexts. This is similar to boolean expressions from IMP \cite{fixme}. Boolean values true and
false respectively represent the guards which are always and never satisfied. Guards may test
for (in)equivalence of two arithmetic expressions or be connected using nor logic into compound
expressions. Additionally, a guard may also test to see if a particular variable is null. This is
useful if an EFSM transition is intended only to initialise a register.  We also define syntax hacks
for the relations less than, less than or equal to, greater than or equal to, and not equal to as
well as the expression of logical conjunction, disjunction, and negation in terms of nor logic.
\<close>

theory GExp
imports AExp Trilean
begin

(* type_synonym gexp = "(aexp \<times> cexp)" *)

(* abbreviation Eq :: "aexp \<Rightarrow> aexp \<Rightarrow> gexp" where *)
  (* "Eq a b = (a, cexp.Eq b) *)

text_raw{*\snip{gexptype}{1}{2}{%*}
datatype gexp = Bc bool | Eq aexp aexp | Gt aexp aexp | Nor gexp gexp | Null aexp
text_raw{*}%endsnip*}

syntax (xsymbols)
  Eq :: "aexp \<Rightarrow> aexp \<Rightarrow> gexp" (*infix "=" 60*)
  Gt :: "aexp \<Rightarrow> aexp \<Rightarrow> gexp" (*infix ">" 60*)

fun gval :: "gexp \<Rightarrow> datastate \<Rightarrow> trilean" where
  "gval (Bc True) _ = true" |
  "gval (Bc False) _ = false" |
  "gval (Gt a\<^sub>1 a\<^sub>2) s = ValueGt (aval a\<^sub>1 s) (aval a\<^sub>2 s)" |
  "gval (Eq a\<^sub>1 a\<^sub>2) s = ValueEq (aval a\<^sub>1 s) (aval a\<^sub>2 s)" |
  "gval (Nor a\<^sub>1 a\<^sub>2) s = \<not>\<^sub>? ((gval a\<^sub>1 s) \<or>\<^sub>? (gval a\<^sub>2 s))" |
  "gval (Null v) s = ValueEq (aval v s) None"

abbreviation gNot :: "gexp \<Rightarrow> gexp"  where
  "gNot g \<equiv> Nor g g"

abbreviation gOr :: "gexp \<Rightarrow> gexp \<Rightarrow> gexp" (*infix "\<or>" 60*) where
  "gOr v va \<equiv> Nor (Nor v va) (Nor v va)"

abbreviation gAnd :: "gexp \<Rightarrow> gexp \<Rightarrow> gexp" (*infix "\<and>" 60*) where
  "gAnd v va \<equiv> Nor (Nor v v) (Nor va va)"

lemma inj_gAnd: "inj gAnd"
  apply (simp add: inj_def)
  apply clarify
  by (metis  gexp.inject(4))

lemma gAnd_determinism: "(gAnd x y = gAnd x' y') = (x = x' \<and> y = y')"
proof
  show "gAnd x y = gAnd x' y' \<Longrightarrow> x = x' \<and> y = y'"
    by (simp)
next
  show "x = x' \<and> y = y' \<Longrightarrow> gAnd x y = gAnd x' y' "
    by simp
qed

abbreviation Lt :: "aexp \<Rightarrow> aexp \<Rightarrow> gexp" (*infix "<" 60*) where
  "Lt a b \<equiv> Gt b a"

abbreviation Le :: "aexp \<Rightarrow> aexp \<Rightarrow> gexp" (*infix "\<le>" 60*) where
  "Le v va \<equiv> gNot (Gt v va)"

abbreviation Ge :: "aexp \<Rightarrow> aexp \<Rightarrow> gexp" (*infix "\<ge>" 60*) where
  "Ge v va \<equiv> gNot (Lt v va)"

abbreviation Ne :: "aexp \<Rightarrow> aexp \<Rightarrow> gexp" (*infix "\<noteq>" 60*) where
  "Ne v va \<equiv> gNot (Eq v va)"

lemma or_equiv: "gval (gOr x y) r = (gval x r) \<or>\<^sub>? (gval y r)"
  by (simp add: maybe_double_negation maybe_or_idempotent)

lemma not_equiv: "gval (gNot x) s = \<not>\<^sub>? (gval x s)"
  by (simp add: maybe_or_idempotent)

lemma nor_equiv: "gval (gNot (gOr a b)) s = gval (Nor a b) s"
  by (metis maybe_double_negation not_equiv)

definition satisfiable :: "gexp \<Rightarrow> bool" where
  "satisfiable g \<equiv> (\<exists>s. gval g s = true)"

lemma satisfiable_true: "satisfiable (Bc True)"
  by (simp add: satisfiable_def)

definition gexp_valid :: "gexp \<Rightarrow> bool" where
  "gexp_valid g \<equiv> (\<forall>s. gval g s = true)"

definition gexp_equiv :: "gexp \<Rightarrow> gexp \<Rightarrow> bool" where
  "gexp_equiv a b \<equiv> \<forall>s. gval a s = gval b s"

lemma gexp_equiv_reflexive: "gexp_equiv x x"
  by (simp add: gexp_equiv_def)

lemma gexp_equiv_symmetric: "gexp_equiv x y \<Longrightarrow> gexp_equiv y x"
  by (simp add: gexp_equiv_def)

lemma gexp_equiv_transitive: "gexp_equiv x y \<and> gexp_equiv y z \<Longrightarrow> gexp_equiv x z"
  by (simp add: gexp_equiv_def)

lemma gval_subst: "gexp_equiv x y \<Longrightarrow> P (gval x s) \<Longrightarrow> P (gval y s)"
  by (simp add: gexp_equiv_def)

lemma gexp_equiv_satisfiable: "gexp_equiv x y \<Longrightarrow> satisfiable x = satisfiable y"
  by (simp add: gexp_equiv_def satisfiable_def)

lemma gAnd_reflexivity: "gexp_equiv (gAnd x x) x"
  by (simp add: gexp_equiv_def maybe_double_negation maybe_or_idempotent)

lemma gAnd_zero: "gexp_equiv (gAnd (Bc True) x) x"
  apply (simp add: gexp_equiv_def)
  apply (rule allI)
  apply (case_tac "gval x s")
  by simp_all

lemma gAnd_symmetry: "gexp_equiv (gAnd x y) (gAnd y x)"
  by (simp add: add.commute gexp_equiv_def)

lemma satisfiable_gAnd_self: "satisfiable (gAnd x x) = satisfiable x"
  by (simp add: gAnd_reflexivity gexp_equiv_satisfiable)

definition mutually_exclusive :: "gexp \<Rightarrow> gexp \<Rightarrow> bool" where
  "mutually_exclusive x y = (\<forall>i. (gval x i = true \<longrightarrow> gval y i \<noteq> true) \<and>
                                 (gval y i = true \<longrightarrow> gval x i \<noteq> true))"

lemma mutually_exclusive_unsatisfiable_conj: "mutually_exclusive x y = (\<not> satisfiable (gAnd x y))"
  apply (simp add: mutually_exclusive_def satisfiable_def)
  by (metis (no_types, lifting) add.assoc add.commute maybe_double_negation maybe_negate_true maybe_or_idempotent maybe_or_zero)

lemma unsatisfiable_conj_mutually_exclusive: "\<not> satisfiable (gAnd x y) = mutually_exclusive x y"
  by (simp add: mutually_exclusive_unsatisfiable_conj)

lemma mutually_exclusive_reflexive: "satisfiable x \<Longrightarrow> \<not> mutually_exclusive x x"
  by (simp add: mutually_exclusive_def satisfiable_def)

lemma mutually_exclusive_symmetric: "mutually_exclusive x y \<Longrightarrow> mutually_exclusive y x"
  by (simp add: mutually_exclusive_def)

lemma not_mutually_exclusive_true: "satisfiable x = (\<not> mutually_exclusive x (Bc True))"
  by (simp add: mutually_exclusive_def satisfiable_def)

lemma gval_gAnd: "gval (gAnd g1 g2) s = (gval g1 s) \<and>\<^sub>? (gval g2 s)"
proof(induct "gval g1 s" "gval g2 s" rule: times_trilean.induct)
case 1
  then show ?case
    by (metis gval.simps(5) maybe_and_valid maybe_not.simps(3) maybe_or_valid)
next
  case "2_1"
  then show ?case
    by simp
next
  case "2_2"
  then show ?case
    by simp
next
  case 3
  then show ?case
    by simp
next
  case "4_1"
  then show ?case
    by simp
next
  case "4_2"
  then show ?case
    by simp
next
  case 5
  then show ?case
    by simp
qed

lemma gval_gAnd_True: "(gval (gAnd g1 g2) s = true) = ((gval g1 s = true) \<and> gval g2 s = true)"
  using gval_gAnd maybe_and_not_true by fastforce

declare gval.simps [simp del]

fun gexp_constrains :: "gexp \<Rightarrow> aexp \<Rightarrow> bool" where
  "gexp_constrains (gexp.Bc _) _ = False" |
  "gexp_constrains (Null a) v = aexp_constrains a v" |
  "gexp_constrains (gexp.Eq a1 a2) v = (aexp_constrains a1 v \<or> aexp_constrains a2 v)" |
  "gexp_constrains (gexp.Gt a1 a2) v = (aexp_constrains a1 v \<or> aexp_constrains a2 v)" |
  "gexp_constrains (gexp.Nor g1 g2) v = (gexp_constrains g1 v \<or> gexp_constrains g2 v)"

fun contains_bool :: "gexp \<Rightarrow> bool" where
  "contains_bool (Bc _) = True" |
  "contains_bool (Nor g1 g2) = (contains_bool g1 \<or> contains_bool g2)" |
  "contains_bool _ = False"

fun gexp_same_structure :: "gexp \<Rightarrow> gexp \<Rightarrow> bool" where
  "gexp_same_structure (gexp.Bc b) (gexp.Bc b') = (b = b')" |
  "gexp_same_structure (gexp.Eq a1 a2) (gexp.Eq a1' a2') = (aexp_same_structure a1 a1' \<and> aexp_same_structure a2 a2')" |
  "gexp_same_structure (gexp.Gt a1 a2) (gexp.Gt a1' a2') = (aexp_same_structure a1 a1' \<and> aexp_same_structure a2 a2')" |
  "gexp_same_structure (gexp.Nor g1 g2) (gexp.Nor g1' g2') = (gexp_same_structure g1 g1' \<and> gexp_same_structure g2 g2')" |
  "gexp_same_structure (gexp.Null a1) (gexp.Null a2) = aexp_same_structure a1 a2" |
  "gexp_same_structure _ _ = False"

lemma gval_foldr_true: "(gval (foldr gAnd G (Bc True)) s = true) = (\<forall>g \<in> set G. gval g s = true)"
proof(induct G)
  case Nil
  then show ?case
    by (simp add: gval.simps)
next
  case (Cons a G)
  then show ?case
    apply (simp only: foldr.simps comp_def gval_gAnd maybe_and_true)
    by simp
qed

fun enumerate_gexp_inputs :: "gexp \<Rightarrow> nat set" where
  "enumerate_gexp_inputs (GExp.Bc _) = {}" |
  "enumerate_gexp_inputs (GExp.Null v) = enumerate_aexp_inputs v" |
  "enumerate_gexp_inputs (GExp.Eq v va) = enumerate_aexp_inputs v \<union> enumerate_aexp_inputs va" |
  "enumerate_gexp_inputs (GExp.Lt v va) = enumerate_aexp_inputs v \<union> enumerate_aexp_inputs va" |
  "enumerate_gexp_inputs (GExp.Nor v va) = enumerate_gexp_inputs v \<union> enumerate_gexp_inputs va"

fun enumerate_gexp_regs :: "gexp \<Rightarrow> nat set" where
  "enumerate_gexp_regs (GExp.Bc _) = {}" |
  "enumerate_gexp_regs (GExp.Null v) = enumerate_aexp_regs v" |
  "enumerate_gexp_regs (GExp.Eq v va) = enumerate_aexp_regs v \<union> enumerate_aexp_regs va" |
  "enumerate_gexp_regs (GExp.Lt v va) = enumerate_aexp_regs v \<union> enumerate_aexp_regs va" |
  "enumerate_gexp_regs (GExp.Nor v va) = enumerate_gexp_regs v \<union> enumerate_gexp_regs va"

lemma enumerate_gexp_regs_empty_reg_unconstrained: "enumerate_gexp_regs g = {} \<Longrightarrow> \<forall>r. \<not> gexp_constrains g (V (R r))"
proof(induct g)
case (Bc x)
  then show ?case
    by simp
next
  case (Eq x1a x2)
  then show ?case
    by (simp add: enumerate_aexp_regs_empty_reg_unconstrained)
next
  case (Gt x1a x2)
  then show ?case
    by (simp add: enumerate_aexp_regs_empty_reg_unconstrained)
next
  case (Nor g1 g2)
  then show ?case
    by simp
next
  case (Null x)
  then show ?case
    by (simp add: enumerate_aexp_regs_empty_reg_unconstrained)
qed

lemma enumerate_gexp_inputs_empty_input_unconstrained: "enumerate_gexp_inputs g = {} \<Longrightarrow> \<forall>r. \<not> gexp_constrains g (V (I r))"
proof(induct g)
case (Bc x)
  then show ?case
    by simp
next
  case (Eq x1a x2)
  then show ?case
    by (simp add: enumerate_aexp_inputs_empty_input_unconstrained)
next
  case (Gt x1a x2)
  then show ?case
    by (simp add: enumerate_aexp_inputs_empty_input_unconstrained)
next
  case (Nor g1 g2)
  then show ?case
    by simp
next
  case (Null x)
  then show ?case
    by (simp add: enumerate_aexp_inputs_empty_input_unconstrained)
qed

lemma input_unconstrained_gval_input_swap: "\<forall>r. \<not> gexp_constrains a (V (I r)) \<Longrightarrow> (gval a (join_ir i r) = gval a (join_ir i' r))"
proof(induct a)
  case (Bc x)
  then show ?case
    apply (cases x)
     apply (simp add: gval.simps(1))
    by (simp add: gval.simps(2))
next
  case (Eq x1a x2)
  then show ?case
    apply (simp add: gval.simps ValueEq_def)
    by (metis input_unconstrained_aval_input_swap)
next
  case (Gt x1a x2)
  then show ?case
    apply (simp add: gval.simps ValueGt_def)
    by (metis input_unconstrained_aval_input_swap)
next
  case (Nor a1 a2)
  then show ?case
    by (simp add: gval.simps(5))
next
  case (Null x)
  then show ?case
    by (metis gexp_constrains.simps(2) gval.simps(6) input_unconstrained_aval_input_swap)
qed

lemma register_unconstrained_gval_register_swap: "\<forall>r. \<not> gexp_constrains a (V (R r)) \<Longrightarrow> (gval a (join_ir i r) = gval a (join_ir i r'))"
proof(induct a)
  case (Bc x)
  then show ?case
    apply (cases x)
     apply (simp add: gval.simps(1))
    by (simp add: gval.simps(2))
next
  case (Eq x1a x2)
  then show ?case
    apply (simp add: gval.simps ValueEq_def)
    by (metis input_unconstrained_aval_register_swap)
next
  case (Gt x1a x2)
  then show ?case
    apply (simp add: gval.simps ValueGt_def)
    by (metis input_unconstrained_aval_register_swap)
next
  case (Nor a1 a2)
  then show ?case
    by (simp add: gval.simps(5))
next
  case (Null x)
  then show ?case
    by (metis gexp.distinct(13) gexp.distinct(17) gexp.distinct(19) gexp.distinct(7) gexp.inject(5) gexp_constrains.simps(2) gval.elims input_unconstrained_aval_register_swap)
qed

lemma unconstrained_variable_swap: "\<forall>r. \<forall>g\<in>set G. \<not> gexp_constrains g (V (I r)) \<Longrightarrow>
       \<forall>r. \<forall>g\<in>set G. \<not> gexp_constrains g (V (R r)) \<Longrightarrow>
       apply_guards G (join_ir i r) = apply_guards G (join_ir i' r')"
proof(induct G)
  case Nil
  then show ?case
    by (simp add: apply_guards_def)
next
  case (Cons a G)
  then show ?case
    unfolding apply_guards_def
    apply simp
    by (metis input_unconstrained_gval_input_swap register_unconstrained_gval_register_swap)
qed
end
