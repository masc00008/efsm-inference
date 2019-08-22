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
imports AExp Trilean Option_Lexorder
begin

definition I :: "nat \<Rightarrow> vname" where
  "I n = vname.I (n-1)"
declare I_def [simp]
hide_const I

text_raw\<open>\snip{gexptype}{1}{2}{%\<close>
datatype gexp = Bc bool | Eq aexp aexp | Gt aexp aexp | Nor gexp gexp | Null aexp
text_raw\<open>}%endsnip\<close>

syntax (xsymbols)
  Eq :: "aexp \<Rightarrow> aexp \<Rightarrow> gexp" (*infix "=" 60*)
  Gt :: "aexp \<Rightarrow> aexp \<Rightarrow> gexp" (*infix ">" 60*)

fun gval :: "gexp \<Rightarrow> datastate \<Rightarrow> trilean" where
  "gval (Bc True) _ = true" |
  "gval (Bc False) _ = false" |
  "gval (Gt a\<^sub>1 a\<^sub>2) s = value_gt (aval a\<^sub>1 s) (aval a\<^sub>2 s)" |
  "gval (Eq a\<^sub>1 a\<^sub>2) s = value_eq (aval a\<^sub>1 s) (aval a\<^sub>2 s)" |
  "gval (Nor a\<^sub>1 a\<^sub>2) s = \<not>\<^sub>? ((gval a\<^sub>1 s) \<or>\<^sub>? (gval a\<^sub>2 s))" |
  "gval (Null v) s = value_eq (aval v s) None"

abbreviation gNot :: "gexp \<Rightarrow> gexp"  where
  "gNot g \<equiv> Nor g g"

abbreviation gOr :: "gexp \<Rightarrow> gexp \<Rightarrow> gexp" (*infix "\<or>" 60*) where
  "gOr v va \<equiv> Nor (Nor v va) (Nor v va)"

abbreviation gAnd :: "gexp \<Rightarrow> gexp \<Rightarrow> gexp" (*infix "\<and>" 60*) where
  "gAnd v va \<equiv> Nor (Nor v v) (Nor va va)"

abbreviation Lt :: "aexp \<Rightarrow> aexp \<Rightarrow> gexp" (*infix "<" 60*) where
  "Lt a b \<equiv> Gt b a"

abbreviation Le :: "aexp \<Rightarrow> aexp \<Rightarrow> gexp" (*infix "\<le>" 60*) where
  "Le v va \<equiv> gNot (Gt v va)"

abbreviation Ge :: "aexp \<Rightarrow> aexp \<Rightarrow> gexp" (*infix "\<ge>" 60*) where
  "Ge v va \<equiv> gNot (Lt v va)"

abbreviation Ne :: "aexp \<Rightarrow> aexp \<Rightarrow> gexp" (*infix "\<noteq>" 60*) where
  "Ne v va \<equiv> gNot (Eq v va)"

fun In :: "vname \<Rightarrow> value list \<Rightarrow> gexp" where
  "In a [] = Bc False" |
  "In a [v] = Eq (V a) (L v)" |
  "In a (v1#t) = gOr (Eq (V a) (L v1)) (In a t)"

lemma gval_gOr: "gval (gOr x y) r = (gval x r) \<or>\<^sub>? (gval y r)"
  by (simp add: maybe_double_negation maybe_or_idempotent)

lemma gval_gNot: "gval (gNot x) s = \<not>\<^sub>? (gval x s)"
  by (simp add: maybe_or_idempotent)

lemma gval_gAnd: "gval (gAnd g1 g2) s = (gval g1 s) \<and>\<^sub>? (gval g2 s)"
  by (simp add: de_morgans_1 maybe_double_negation maybe_or_idempotent)

lemma gAnd_commute: "gval (gAnd a b) s = gval (gAnd b a) s"
  using gval_gAnd times_trilean_commutative by auto

lemma gOr_commute: "gval (gOr a b) s = gval (gOr b a) s"
  by (simp add: plus_trilean_commutative)

lemma gval_gAnd_True: "(gval (gAnd g1 g2) s = true) = ((gval g1 s = true) \<and> gval g2 s = true)"
  using gval_gAnd maybe_and_not_true by fastforce

lemma nor_equiv: "gval (gNot (gOr a b)) s = gval (Nor a b) s"
  by (metis maybe_double_negation gval_gNot)

definition satisfiable :: "gexp \<Rightarrow> bool" where
  "satisfiable g \<equiv> (\<exists>i r. gval g (join_ir i r) = true)"

lemma unsatisfiable_false: "\<not> satisfiable (Bc False)"
  by (simp add: satisfiable_def)

lemma satisfiable_true: "satisfiable (Bc True)"
  by (simp add: satisfiable_def)

definition valid :: "gexp \<Rightarrow> bool" where
  "valid g \<equiv> (\<forall>s. gval g s = true)"

lemma valid_true: "valid (Bc True)"
  by (simp add: valid_def)

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
    by simp
next
  case (Cons a G)
  then show ?case
    apply (simp only: foldr.simps comp_def gval_gAnd maybe_and_true)
    by simp
qed

fun enumerate_gexp_inputs :: "gexp \<Rightarrow> nat set" where
  "enumerate_gexp_inputs (Bc _) = {}" |
  "enumerate_gexp_inputs (Null v) = enumerate_aexp_inputs v" |
  "enumerate_gexp_inputs (Eq v va) = enumerate_aexp_inputs v \<union> enumerate_aexp_inputs va" |
  "enumerate_gexp_inputs (Lt v va) = enumerate_aexp_inputs v \<union> enumerate_aexp_inputs va" |
  "enumerate_gexp_inputs (Nor v va) = enumerate_gexp_inputs v \<union> enumerate_gexp_inputs va"

lemma enumerate_gexp_inputs_list: "\<exists>l. enumerate_gexp_inputs g = set l"
proof(induct g)
case (Bc x)
  then show ?case
    by simp
next
  case (Eq x1a x2)
  then show ?case
    by (metis enumerate_aexp_inputs_list enumerate_gexp_inputs.simps(3) set_union)
next
  case (Gt x1a x2)
  then show ?case
    by (metis enumerate_aexp_inputs_list enumerate_gexp_inputs.simps(4) set_union)
next
  case (Nor l1 l2)
  then show ?case
    by (metis enumerate_gexp_inputs.simps(5) set_union_append)
next
  case (Null x)
  then show ?case
    by (simp add: enumerate_aexp_inputs_list)
qed

definition max_input :: "gexp \<Rightarrow> nat option" where
  "max_input g = (let inputs = (enumerate_gexp_inputs g) in if inputs = {} then None else Some (Max inputs))"

definition max_input_list :: "gexp list \<Rightarrow> nat option" where
  "max_input_list g = (fold max (map (\<lambda>g. max_input g) g) None)"

lemma max_input_list_cons: "max_input_list (a # G) = max (max_input a) (max_input_list G)"
  apply (simp add: max_input_list_def)
proof -
  have "foldr max (max_input a # rev (map_tailrec max_input G)) None = foldr max (rev (None # map_tailrec max_input G)) (max_input a)"
    by (metis (no_types) Max.set_eq_fold comp_def fold.simps(2) fold_conv_foldr foldr_conv_fold list.set(2) max.commute set_rev)
  then show "fold max (map max_input G) (max (max_input a) None) = max (max_input a) (fold max (map max_input G) None)"
    by (simp add: fold_conv_foldr map_eq_map_tailrec max.commute)
qed

fun enumerate_gexp_regs :: "gexp \<Rightarrow> nat set" where
  "enumerate_gexp_regs (Bc _) = {}" |
  "enumerate_gexp_regs (Null v) = enumerate_aexp_regs v" |
  "enumerate_gexp_regs (Eq v va) = enumerate_aexp_regs v \<union> enumerate_aexp_regs va" |
  "enumerate_gexp_regs (Lt v va) = enumerate_aexp_regs v \<union> enumerate_aexp_regs va" |
  "enumerate_gexp_regs (Nor v va) = enumerate_gexp_regs v \<union> enumerate_gexp_regs va"

lemma enumerate_gexp_regs_list: "\<exists>l. enumerate_gexp_regs g = set l"
proof(induct g)
case (Bc x)
  then show ?case
    by simp
next
  case (Eq x1a x2)
  then show ?case
    by (metis enumerate_aexp_regs_list enumerate_gexp_regs.simps(3) set_union_append)
next
  case (Gt x1a x2)
  then show ?case
    by (metis enumerate_aexp_regs_list enumerate_gexp_regs.simps(4) set_append)
next
  case (Nor l1 l2)
  then show ?case
    by (metis enumerate_gexp_regs.simps(5) set_append)
next
  case (Null x)
  then show ?case
    by (simp add: enumerate_aexp_regs_list)
qed

lemma no_variables_list_gval:
  "enumerate_gexp_inputs g = {} \<Longrightarrow>
   enumerate_gexp_regs g = {} \<Longrightarrow>
   gval g s = gval g s'"
proof(induct g)
case (Bc x)
  then show ?case
    by (metis (full_types) gval.simps(1) gval.simps(2))
next
  case (Eq x1a x2)
  then show ?case
    by (metis Un_empty enumerate_gexp_inputs.simps(3) enumerate_gexp_regs.simps(3) gval.simps(4) no_variables_aval)
next
  case (Gt x1a x2)
  then show ?case
    by (metis Un_empty enumerate_gexp_inputs.simps(4) enumerate_gexp_regs.simps(4) gval.simps(3) no_variables_aval)
next
  case (Nor a1 a2)
  then show ?case
    by simp
next
  case (Null x)
  then show ?case
    by (metis enumerate_gexp_inputs.simps(2) enumerate_gexp_regs.simps(2) gval.simps(6) no_variables_aval)
qed

lemma no_variables_list_valid_or_unsat:
  "enumerate_gexp_inputs g = {} \<Longrightarrow>
   enumerate_gexp_regs g = {} \<Longrightarrow>
   valid g \<or> \<not> satisfiable g"
proof(induct g)
  case (Bc x)
  then show ?case
    by (metis (full_types) unsatisfiable_false valid_true)
next
  case (Eq x1a x2)
  then show ?case
    by (metis no_variables_list_gval satisfiable_def valid_def)
next
  case (Gt x1a x2)
  then show ?case
    by (metis no_variables_list_gval satisfiable_def valid_def)
next
  case (Nor g1 g2)
  then show ?case
    by (metis no_variables_list_gval satisfiable_def valid_def)
next
  case (Null x)
  then show ?case
    by (metis no_variables_list_gval satisfiable_def valid_def)
qed

definition max_reg :: "gexp \<Rightarrow> nat option" where
  "max_reg g = (let regs = (enumerate_gexp_regs g) in if regs = {} then None else Some (Max regs))"

lemma max_reg_gNot: "max_reg (gNot x) = max_reg x"
  by (simp add: max_reg_def)

lemma max_reg_Eq: "max_reg (Eq a b) = max (AExp.max_reg a) (AExp.max_reg b)"
  apply (simp add: max_reg_def AExp.max_reg_def Let_def max_None max_Some_Some)
  by (metis List.finite_set Max.union enumerate_aexp_regs_list)

lemma max_reg_Gt: "max_reg (Gt a b) = max (AExp.max_reg a) (AExp.max_reg b)"
  apply (simp add: max_reg_def AExp.max_reg_def Let_def max_None max_Some_Some)
  by (metis List.finite_set Max.union enumerate_aexp_regs_list max.commute)

lemma max_reg_Nor: "max_reg (Nor a b) = max (max_reg a) (max_reg b)"
  apply (simp add: max_reg_def Let_def max_None max_Some_Some)
  by (metis List.finite_set Max.union enumerate_gexp_regs_list)

lemma max_reg_Null: "max_reg (Null a) = AExp.max_reg a"
  by (simp add: AExp.max_reg_def max_reg_def)

lemma no_reg_gval_swap_regs: "max_reg g = None \<Longrightarrow> gval g (join_ir i r) = gval g (join_ir i r')"
proof(induct g)
case (Bc x)
  then show ?case
    by (metis (full_types) gval.simps(1) gval.simps(2))
next
  case (Eq x1a x2)
  then show ?case
    by (metis gval.simps(4) max_is_None max_reg_Eq no_reg_aval_swap_regs)
next
  case (Gt x1a x2)
  then show ?case
    by (metis gval.simps(3) max_is_None max_reg_Gt no_reg_aval_swap_regs)
next
  case (Nor g1 g2)
  then show ?case
    by (simp add: max_is_None max_reg_Nor)
next
  case (Null x)
  then show ?case
    by (metis gval.simps(6) max_reg_Null no_reg_aval_swap_regs)
qed

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

lemma unconstrained_variable_swap_gval:
   "\<forall>r. \<not> gexp_constrains g (V (vname.I r)) \<Longrightarrow>
    \<forall>r. \<not> gexp_constrains g (V (R r)) \<Longrightarrow>
    gval g s = gval g s'"
proof(induct g)
case (Bc x)
  then show ?case
    by (simp add: no_variables_list_gval)
next
  case (Eq x1a x2)
  then show ?case
    by (metis gexp_constrains.simps(3) gval.simps(4) unconstrained_variable_swap_aval)
next
  case (Gt x1a x2)
  then show ?case
    by (metis gexp_constrains.simps(4) gval.simps(3) unconstrained_variable_swap_aval)
next
  case (Nor g1 g2)
  then show ?case
    by simp
next
  case (Null x)
  then show ?case
    by (metis gexp_constrains.simps(2) gval.simps(6) unconstrained_variable_swap_aval)
qed

lemma gval_In_cons: "gval (In v (a # as)) s = (gval (Eq (V v) (L a)) s \<or>\<^sub>? gval (In v as) s)"
  apply (cases as)
   apply simp
  using In.simps(3) gval_gOr by presburger

lemma possible_to_be_in: "s \<noteq> [] \<Longrightarrow> satisfiable (In v s)"
proof(induct s)
case Nil
  then show ?case by simp
next
  case (Cons a s)
  then show ?case
    apply (simp add: satisfiable_def gval_In_cons)
    by (metis In.simps(1) add.commute gval.simps(2) join_ir_double_exists maybe_or_idempotent plus_trilean.simps(6))
qed

definition max_reg_list :: "gexp list \<Rightarrow> nat option" where
  "max_reg_list g = (fold max (map (\<lambda>g. max_reg g) g) None)"

lemma max_reg_list_cons: "max_reg_list (a # G) = max (max_reg a) (max_reg_list G)"
  apply (simp add: max_reg_list_def)
  by (metis (no_types, lifting) List.finite_set Max.insert Max.set_eq_fold fold.simps(1) id_apply list.simps(15) max.assoc set_empty)

lemma max_reg_list_append_singleton: "max_reg_list (as@[bs]) = max (max_reg_list as) (max_reg_list [bs])"
  apply (simp add: max_reg_list_def)
  by (metis max.commute max_None_r)

lemma max_reg_list_append: "max_reg_list (as@bs) = max (max_reg_list as) (max_reg_list bs)"
proof(induct bs rule: rev_induct)
  case Nil
  then show ?case
    by (simp add: max_reg_list_def max_None_r)
next
  case (snoc x xs)
  then show ?case
    by (metis append_assoc max.assoc max_reg_list_append_singleton)
qed

definition apply_guards :: "gexp list \<Rightarrow> datastate \<Rightarrow> bool" where
  "apply_guards G s = (\<forall>g \<in> set (map (\<lambda>g. gval g s) G). g = true)"

lemmas apply_guards = datastate apply_guards_def gval.simps value_eq_def value_gt_def

lemma no_reg_apply_guards_swap_regs:
  "max_reg_list G = None \<Longrightarrow>
   apply_guards G (join_ir i r) = apply_guards G (join_ir i r')"
  apply (simp add: apply_guards_def max_reg_list_def)
  by (metis in_set_conv_decomp max_is_None max_reg_list_append max_reg_list_cons max_reg_list_def no_reg_gval_swap_regs)

lemma apply_guards_singleton: "(apply_guards [g] s) = (gval g s = true)"
  by (simp add: apply_guards_def)

lemma apply_guards_empty [simp]: "apply_guards [] s"
  by (simp add: apply_guards_def)

lemma apply_guards_cons: "apply_guards (a # G) c = (gval a c = true \<and> apply_guards G c)"
  by (simp add: apply_guards_def)

lemma apply_guards_double_cons: "apply_guards (y # x # G) s = (gval (gAnd y x) s = true \<and> apply_guards G s)"
  using apply_guards_cons gval_gAnd_True by auto

lemma apply_guards_append: "apply_guards (a@a') s = (apply_guards a s \<and> apply_guards a' s)"
  apply (simp add: apply_guards_def)
  by auto

lemma apply_guards_foldr: "apply_guards G s = (gval (foldr gAnd G (Bc True)) s = true)"
proof(induct G)
  case Nil
  then show ?case
    by (simp add: apply_guards_def)
next
  case (Cons a G)
  then show ?case
    apply (simp only: foldr.simps comp_def)
    using apply_guards_cons gval_gAnd_True by auto
qed

lemma apply_guards_rev: "apply_guards G s = apply_guards (rev G) s"
  by (simp add: apply_guards_def)

lemma rev_apply_guards: "apply_guards (rev G) s = apply_guards G s"
  by (simp add: apply_guards_def)

lemma apply_guards_fold: "apply_guards G s = (gval (fold gAnd G (Bc True)) s = true)"
  using apply_guards_rev
  by (simp add: foldr_conv_fold apply_guards_foldr)

lemma fold_apply_guards: "(gval (fold gAnd G (Bc True)) s = true) = apply_guards G s"
  by (simp add: apply_guards_fold)

lemma foldr_apply_guards: "(gval (foldr gAnd G (Bc True)) s = true) = apply_guards G s"
  by (simp add: apply_guards_foldr)

lemma apply_guards_subset: "set g' \<subseteq> set g \<Longrightarrow> apply_guards g c \<longrightarrow> apply_guards g' c"
proof(induct g)
  case Nil
  then show ?case
    by simp
next
  case (Cons a g)
  then show ?case
    apply (simp add: apply_guards_def)
    by auto
qed

lemma apply_guards_subset_append: "set G \<subseteq> set G' \<Longrightarrow> apply_guards (G @ G') s = apply_guards (G') s"
  using apply_guards_append apply_guards_subset by blast

lemma apply_guards_rearrange: "x \<in> set G \<Longrightarrow> apply_guards G s = apply_guards (x#G) s"
  apply (simp add: apply_guards_def)
  by auto

lemma max_input_Bc: "max_input (Bc x) = None"
  by (simp add: max_input_def)

lemma max_input_Eq: "max_input (Eq a1 a2) = max (AExp.max_input a1) (AExp.max_input a2)"
  apply (simp add: AExp.max_input_def max_input_def Let_def)
  apply safe
    apply (simp add: max_None_l)
   apply (simp add: max.commute max_None_l)
  by (metis List.finite_set Max.union enumerate_aexp_inputs_list max_Some_Some)

lemma max_input_Gt: "max_input (Gt a1 a2) = max (AExp.max_input a1) (AExp.max_input a2)"
  apply (simp add: AExp.max_input_def max_input_def Let_def)
  apply safe
    apply (simp add: max_None_l)
   apply (simp add: max.commute max_None_l)
  by (metis List.finite_set Max.union enumerate_aexp_inputs_list max.commute max_Some_Some)

lemma gexp_max_input_Nor: "max_input (Nor g1 g2) = max (max_input g1) (max_input g2)"
  apply (simp add: max_input_def Let_def)
  apply safe
    apply (simp add: max_None_l)
   apply (simp add: max.commute max_None_l)
  by (metis List.finite_set Max.union enumerate_gexp_inputs_list max_Some_Some)

lemma gexp_max_input_Null: "max_input (Null x) = AExp.max_input x"
  by (simp add: AExp.max_input_def max_input_def)

lemma gval_take:
  "max_input g < Some a \<Longrightarrow>
   gval g (join_ir i r) = gval g (join_ir (take a i) r)"
proof(induct g)
case (Bc x)
  then show ?case
    by (metis (full_types) gval.simps(1) gval.simps(2))
next
  case (Eq x1a x2)
  then show ?case
    by (metis aval_take gval.simps(4) max_input_Eq max_less_iff_conj)
next
  case (Gt x1a x2)
  then show ?case
    by (metis aval_take gval.simps(3) max_input_Gt max_less_iff_conj)
next
  case (Nor g1 g2)
  then show ?case
    by (simp add: maybe_not_eq gexp_max_input_Nor)
next
  case (Null x)
  then show ?case
    by (metis aval_take gexp_max_input_Null gval.simps(6))
qed

lemma gval_no_reg_swap_regs:
  "max_input g < Some a \<Longrightarrow>
   max_reg g = None \<Longrightarrow>
   gval g (join_ir i ra) = gval g (join_ir (take a i) r)"
proof(induct g)
case (Bc x)
  then show ?case
    by (metis (full_types) gval.simps(1) gval.simps(2))
next
  case (Eq x1a x2)
  then show ?case
    by (metis gval_take no_reg_gval_swap_regs)
next
  case (Gt x1a x2)
  then show ?case
    by (metis gval_take no_reg_gval_swap_regs)
next
  case (Nor g1 g2)
  then show ?case
    by (simp add: gexp_max_input_Nor max_reg_Nor max_is_None)
next
  case (Null x)
  then show ?case
    by (metis gval_take no_reg_gval_swap_regs)
qed

lemma gval_fold_gAnd_append_singleton:
  "gval (fold gAnd (a @ [G]) (Bc True)) s = gval (fold gAnd a (Bc True)) s \<and>\<^sub>? gval G s"
  apply (simp add: fold_conv_foldr del: foldr.simps)
  by (simp only: foldr.simps comp_def gval_gAnd times_trilean_commutative)

lemma gval_fold_rev_true:
  "gval (fold gAnd (rev G) (Bc True)) s = true \<Longrightarrow>
   gval (fold gAnd G (Bc True)) s = true"
  by (simp add: fold_conv_foldr gval_foldr_true)

lemma gval_fold_not_invalid_all_valid_contra:
  "\<exists>g \<in> set G. gval g s = invalid \<Longrightarrow>
   gval (fold gAnd G (Bc True)) s = invalid"
proof(induct G rule: rev_induct)
  case Nil
  then show ?case
    by simp
next
  case (snoc a G)
  then show ?case
    apply (simp only: gval_fold_gAnd_append_singleton)
    apply simp
    using maybe_and_valid by blast
qed

lemma gval_fold_not_invalid_all_valid:
  "gval (fold gAnd G (Bc True)) s \<noteq> invalid \<Longrightarrow>
   \<forall>g \<in> set G. gval g s \<noteq> invalid"
  using gval_fold_not_invalid_all_valid_contra by blast

lemma all_gval_not_false:
  "(\<forall>g \<in> set G. gval g s \<noteq> false) = (\<forall>g \<in> set G. gval g s = true) \<or> (\<exists>g \<in> set G. gval g s = invalid)"
  using trilean.exhaust by auto

lemma must_have_one_false_contra:
  "\<forall>g \<in> set G. gval g s \<noteq> false \<Longrightarrow>
   gval (fold gAnd G (Bc True)) s \<noteq> false"
  using all_gval_not_false[of G s]
  apply simp
  apply (case_tac "(\<forall>g\<in>set G. gval g s = true)")
   apply (metis (no_types, lifting) fold_apply_guards foldr_apply_guards gval_foldr_true trilean.distinct(1))
  by (simp add: gval_fold_not_invalid_all_valid_contra)

lemma must_have_one_false:
  "gval (fold gAnd G (Bc True)) s = false \<Longrightarrow>
   \<exists>g \<in> set G. gval g s = false"
  using must_have_one_false_contra by blast

lemma all_valid_fold: "\<forall>g \<in> set G. gval g s \<noteq> invalid \<Longrightarrow> gval (fold gAnd G (Bc True)) s \<noteq> invalid"
proof(induct G rule: rev_induct)
  case Nil
  then show ?case
    by simp
next
  case (snoc a G)
  then show ?case
    apply (simp add: fold_conv_foldr del: foldr.simps)
    apply (simp only: foldr.simps comp_def gval_gAnd)
    by (simp add: maybe_and_invalid)
qed

lemma one_false_all_valid_false: "\<exists>g\<in>set G. gval g s = false \<Longrightarrow> \<forall>g\<in>set G. gval g s \<noteq> invalid \<Longrightarrow> gval (fold gAnd G (Bc True)) s = false"
proof(induct G rule: rev_induct)
  case Nil
  then show ?case
    by simp
next
  case (snoc x xs)
  then show ?case
    apply (simp add: fold_conv_foldr del: foldr.simps)
    apply (simp only: foldr.simps comp_def gval_gAnd)
    apply (case_tac "gval x s = false")
     apply simp
     apply (case_tac "gval (foldr gAnd (rev xs) (Bc True)) s")
       apply simp
      apply simp
     apply simp
    using all_valid_fold
     apply (simp add: fold_conv_foldr)
    apply simp
    by (metis maybe_not.cases times_trilean.simps(5))
qed

lemma gval_fold_rev_false: "gval (fold gAnd (rev G) (Bc True)) s = false \<Longrightarrow> gval (fold gAnd G (Bc True)) s = false"
  using must_have_one_false[of "rev G" s]
        gval_fold_not_invalid_all_valid[of "rev G" s]
  by (simp add: one_false_all_valid_false)

lemma fold_invalid_means_one_invalid: "gval (fold gAnd G (Bc True)) s = invalid \<Longrightarrow> \<exists>g \<in> set G. gval g s = invalid"
  using all_valid_fold by blast

lemma gval_fold_rev_invalid: "gval (fold gAnd (rev G) (Bc True)) s = invalid \<Longrightarrow> gval (fold gAnd G (Bc True)) s = invalid"
  using fold_invalid_means_one_invalid[of "rev G" s]
  by (simp add: gval_fold_not_invalid_all_valid_contra)

lemma gval_fold_rev_equiv_fold: "gval (fold gAnd (rev G) (Bc True)) s =  gval (fold gAnd G (Bc True)) s"
  apply (cases "gval (fold gAnd (rev G) (Bc True)) s")
    apply (simp add: gval_fold_rev_true)
   apply (simp add: gval_fold_rev_false)
  by (simp add: gval_fold_rev_invalid)

lemma gval_fold_equiv_fold_rev: "gval (fold gAnd G (Bc True)) s = gval (fold gAnd (rev G) (Bc True)) s"
  by (simp add: gval_fold_rev_equiv_fold)

lemma gval_fold_equiv_gval_foldr: "gval (fold gAnd G (Bc True)) s = gval (foldr gAnd G (Bc True)) s"
proof -
  have "gval (fold gAnd G (Bc True)) s = gval (fold gAnd (rev G) (Bc True)) s"
    using gval_fold_equiv_fold_rev by force
then show ?thesis
by (simp add: foldr_conv_fold)
qed

lemma gval_foldr_equiv_gval_fold: "gval (foldr gAnd G (Bc True)) s = gval (fold gAnd G (Bc True)) s"
  by (simp add: gval_fold_equiv_gval_foldr)

lemma gval_fold_cons: "gval (fold gAnd (g # gs) (Bc True)) s = gval g s \<and>\<^sub>? gval (fold gAnd gs (Bc True)) s"
  apply (simp only: apply_guards_fold gval_fold_equiv_gval_foldr)
  by (simp only: foldr.simps comp_def gval_gAnd)

lemma gval_fold_take:
  "max_input_list G < Some a \<Longrightarrow>
   a \<le> length i \<Longrightarrow>
   max_input_list G \<le> Some (length i) \<Longrightarrow>
   gval (fold gAnd G (Bc True)) (join_ir i r) = gval (fold gAnd G (Bc True)) (join_ir (take a i) r)"
proof(induct G)
  case Nil
  then show ?case
    by simp
next
  case (Cons g gs)
  then show ?case
    apply (simp only: gval_fold_cons)
    apply (simp add: max_input_list_cons)
    using gval_take[of g a i r]
    by simp
qed

lemma gval_fold_swap_regs:
  "max_reg_list G = None \<Longrightarrow>
   gval (fold gAnd G (Bc True)) (join_ir i r) = gval (fold gAnd G (Bc True)) (join_ir i r')"
proof(induct G)
  case Nil
  then show ?case
    by simp
next
  case (Cons a G)
  then show ?case
    apply (simp only: gval_fold_equiv_gval_foldr foldr.simps comp_def gval_gAnd)
    by (metis (no_types, lifting) max_is_None max_reg_list_cons no_reg_gval_swap_regs)
qed

unbundle finfun_syntax

primrec padding :: "nat \<Rightarrow> 'a list" where
  "padding 0 = []" |
  "padding (Suc m) = (Eps (\<lambda>x. True))#(padding m)"

definition take_or_pad :: "'a list \<Rightarrow> nat \<Rightarrow> 'a list" where
  "take_or_pad a n = (if length a \<ge> n then take n a else a@(padding (n-length a)))"

lemma length_padding: "length (padding n) = n"
proof(induct n)
  case 0
  then show ?case
    by simp
next
  case (Suc n)
  then show ?case
    by simp
qed

lemma length_take_or_pad: "length (take_or_pad a n) = n"
proof(induct n)
  case 0
  then show ?case
    by (simp add: take_or_pad_def)
next
  case (Suc n)
  then show ?case
    apply (simp add: take_or_pad_def)
    apply standard
     apply auto[1]
    by (simp add: length_padding)
qed

definition ensure_not_null :: "nat \<Rightarrow> gexp list" where
  "ensure_not_null n = map (\<lambda>i. gNot (Null (V (vname.I i)))) [0..<n]"

lemma ensure_not_null_cons: "ensure_not_null (Suc a) = (ensure_not_null a)@[gNot (Null (V (I a)))]"
  by (simp add: ensure_not_null_def)

lemma not_null_length: "apply_guards (ensure_not_null a) (join_ir ia r) \<Longrightarrow> length ia \<ge> a"
proof(induct a)
  case 0
  then show ?case
    by simp
next
  case (Suc a)
  then show ?case
    apply (simp add: ensure_not_null_def apply_guards_append)
    apply (simp add: apply_guards_singleton maybe_negate_true maybe_or_false)
    apply (case_tac "join_ir ia r (vname.I a) = None")
     apply (simp add: value_eq_def)
    by (simp add: Suc_leI datastate(1) input2state_not_None)
qed

lemma apply_guards_take_or_pad:
  "max_input_list G < Some a \<Longrightarrow>
   apply_guards G (join_ir i r) \<Longrightarrow>
   apply_guards (ensure_not_null a) (join_ir i r) \<Longrightarrow>
   apply_guards G (join_ir (take_or_pad i a) r)"
proof(induct G)
  case Nil
  then show ?case
    by (simp add: max_input_def)
next
  case (Cons g gs)
  then show ?case
    apply (simp add: apply_guards_cons max_input_list_cons)
    using not_null_length[of a i r]
    apply simp
    apply (simp add: take_or_pad_def)
    by (metis gval_take)
qed

lemma apply_guards_no_reg_swap_regs:
  "max_reg_list G = None \<Longrightarrow>
   max_input_list G < Some a \<Longrightarrow>
   apply_guards G (join_ir i ra) \<Longrightarrow>
   apply_guards (ensure_not_null a) (join_ir i ra) \<Longrightarrow>
   apply_guards G (join_ir (take_or_pad i a) r)"
proof(induct G)
  case Nil
  then show ?case
    by (simp add: max_input_def)
next
  case (Cons g gs)
  then show ?case
    by (metis apply_guards_cons gval_no_reg_swap_regs max.strict_boundedE max_input_list_cons max_is_None max_reg_list_cons not_null_length take_or_pad_def)
qed

lemma apply_guards_ensure_not_null:
  "length i \<ge> a \<Longrightarrow>
   apply_guards (ensure_not_null a) (join_ir i r)"
proof(induct a)
  case 0
  then show ?case
    by (simp add: ensure_not_null_def)
next
  case (Suc a)
  then show ?case
    apply (simp add: ensure_not_null_cons apply_guards_append apply_guards_singleton value_eq_def)
    by (simp add: join_ir_def input2state_nth)
qed

lemma apply_guards_ensure_not_null_length: "apply_guards (ensure_not_null a) (join_ir i r) = (length i \<ge> a)"
  using apply_guards_ensure_not_null not_null_length by blast

end
