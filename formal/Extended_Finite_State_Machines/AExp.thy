section \<open>Arithmetic Expressions\<close>
text\<open>
This theory defines a language of arithmetic expressions over variables and literal values. Here,
values are limited to integers and strings. Variables may be either inputs or registers. We also
limit ourselves to a simple arithmetic of addition, subtraction, and multiplication as a proof of
concept.
\<close>

theory AExp
  imports Value_Lexorder VName Registers "HOL-Library.Option_ord"
begin

declare One_nat_def [simp del]

type_synonym 'a datastate = "'a \<Rightarrow> value option"

text_raw\<open>\snip{aexptype}{1}{2}{%\<close>
datatype 'a aexp = L "value" | V 'a |
                   Plus "'a aexp" "'a aexp" | Minus "'a aexp" "'a aexp" |
                   Times "'a aexp" "'a aexp" | Divide "'a aexp" "'a aexp"
text_raw\<open>}%endsnip\<close>

fun is_lit :: "'a aexp \<Rightarrow> bool" where
  "is_lit (L x) = True" |
  "is_lit (V x) = False" |
  "is_lit (Plus a1 a2) = ((is_lit a1) \<and> (is_lit a2))" |
  "is_lit (Minus a1 a2) = ((is_lit a1) \<and> (is_lit a2))" |
  "is_lit (Times a1 a2) = ((is_lit a1) \<and> (is_lit a2))" |
  "is_lit (Divide a1 a2) = ((is_lit a1) \<and> (is_lit a2))"

lemma aexp_induct_separate_V_cases  [case_names L I R Plus Minus Times Divide]:
  "(\<And>x. P (L x)) \<Longrightarrow>
   (\<And>x. P (V (I x))) \<Longrightarrow>
   (\<And>x. P (V (R x))) \<Longrightarrow>
   (\<And>x1a x2a. P x1a \<Longrightarrow> P x2a \<Longrightarrow> P (Plus x1a x2a)) \<Longrightarrow>
   (\<And>x1a x2a. P x1a \<Longrightarrow> P x2a \<Longrightarrow> P (Minus x1a x2a)) \<Longrightarrow>
   (\<And>x1a x2a. P x1a \<Longrightarrow> P x2a \<Longrightarrow> P (Times x1a x2a)) \<Longrightarrow>
   (\<And>x1a x2a. P x1a \<Longrightarrow> P x2a \<Longrightarrow> P (Divide x1a x2a)) \<Longrightarrow>
   P a"
  apply (induction)
       apply simp
      apply (metis vname.exhaust)
  by auto

fun aval :: "'a aexp \<Rightarrow> 'a datastate \<Rightarrow> value option" where
  "aval (L x) s = Some x" |
  "aval (V x) s = s x" |
  "aval (Plus a1 a2) s = value_plus (aval a1 s)(aval a2 s)" |
  "aval (Minus a1 a2) s = value_minus (aval a1 s) (aval a2 s)" |
  "aval (Times a1 a2) s = value_times (aval a1 s) (aval a2 s)" |
  "aval (Divide a1 a2) s = value_divide (aval a1 s) (aval a2 s)"

lemma aval_plus_symmetry: "aval (Plus x y) s = aval (Plus y x) s"
  by (simp add: value_plus_symmetry)

definition input2state :: "value list \<Rightarrow> registers" where
  "input2state n = fold (\<lambda>(k, v) f. f(k $r:= Some v)) (enumerate 0 n) <>"

primrec input2state_prim :: "value list \<Rightarrow> nat \<Rightarrow> registers" where
  "input2state_prim [] _ = <>" |
  "input2state_prim (v#t) k = (input2state_prim t (k+1))(k $r:= Some v)"

lemma input2state_append:
  "input2state (i @ [a]) = (input2state i)(length i $r:= Some a)"
  by (simp add: input2state_def enumerate_eq_zip)

lemma input2state_out_of_bounds:
  "i \<ge> length ia \<Longrightarrow> input2state ia $r i = None"
proof(induct ia rule: rev_induct)
  case Nil
  then show ?case
    by (simp add: input2state_def)
next
  case (snoc a as)
  then show ?case
    by (simp add: input2state_append)
qed

lemma input2state_within_bounds:
  "input2state i $r x = Some a \<Longrightarrow> x < length i"
  by (metis input2state_out_of_bounds not_le_imp_less option.distinct(1))

lemma input2state_empty: "input2state [] $r x1 = None"
  by (simp add: input2state_out_of_bounds)

lemma input2state_nth:
  "i < length ia \<Longrightarrow> input2state ia $r i = Some (ia ! i)"
proof(induct ia rule: rev_induct)
  case Nil
  then show ?case
    by simp
next
  case (snoc a ia)
  then show ?case
    apply (simp add: input2state_append)
    by (metis less_Suc_eq nth_append nth_append_length update_irrelevant update_value)
qed

lemma input2state_some:
  "i < length ia \<Longrightarrow>
   ia ! i = x \<Longrightarrow>
   input2state ia $r i = Some x"
  by (simp add: input2state_nth)

lemma input2state_take: "x1 < A \<Longrightarrow>
   A \<le> length i \<Longrightarrow>
   x = vname.I x1 \<Longrightarrow>
   input2state i $r x1 = input2state (take A i) $r x1"
proof(induct i)
  case Nil
  then show ?case
    by simp
next
  case (Cons a i)
  then show ?case
    by (simp add: input2state_nth)
qed

lemma input2state_not_None:
  "(input2state i $r x \<noteq> None) \<Longrightarrow> (x < length i)"
  using input2state_within_bounds by blast

lemma input2state_Some:
  "(\<exists>v. input2state i $r x = Some v) = (x < length i)"
  apply standard
  using input2state_within_bounds apply blast
  by (simp add: input2state_nth)

lemma input2state_cons: "x1 > 0 \<Longrightarrow>
   x1 < length ia \<Longrightarrow>
   input2state (a # ia) $r x1 = input2state ia $r (x1-1)"
  by (simp add: input2state_nth)

lemma input2state_cons_shift:
  "input2state i $r x1 = Some a \<Longrightarrow> input2state (b # i) $r (Suc x1) = Some a"
proof(induct i rule: rev_induct)
  case Nil
  then show ?case
    by (simp add: input2state_def)
next
  case (snoc x xs)
  then show ?case
    by (metis Suc_less_eq input2state_nth input2state_within_bounds length_Cons nth_Cons_Suc)
qed

lemma input2state_exists: "\<exists>i. input2state i $r x1 = Some a"
proof(induct x1)
  case 0
  then show ?case
    by (metis Ex_list_of_length input2state_some length_list_update nth_list_update_eq zero_less_Suc)
next
  case (Suc x1)
  then show ?case
    apply clarify
    apply (rule_tac x="a#i" in exI)
    by (simp add: input2state_cons_shift)
qed

primrec repeat :: "nat \<Rightarrow> 'a \<Rightarrow> 'a list" where
  "repeat 0 _ = []" |
  "repeat (Suc m) a = a#(repeat m a)"

lemma length_repeat: "length (repeat n a) = n"
proof(induct n)
  case 0
  then show ?case
    by simp
next
  case (Suc a)
  then show ?case
    by simp
qed

lemma length_append_repeat: "length (i@(repeat a y)) \<ge> length i"
  by simp

lemma length_input2state_repeat:
  "input2state i $r x = Some a \<Longrightarrow> y < length (i @ repeat y a)"
  by (metis append.simps(1) append_eq_append_conv input2state_within_bounds length_append length_repeat list.size(3) neqE not_add_less2 zero_order(3))

lemma input2state_double_exists:
  "\<exists>i. input2state i $r x = Some a \<and> input2state i $r y = Some a"
  apply (insert input2state_exists[of x a])
  apply clarify
  apply (case_tac "x \<ge> y")
  apply (rule_tac x="list_update i y a" in exI)
  apply (metis (no_types, lifting) input2state_within_bounds input2state_nth input2state_out_of_bounds le_trans length_list_update not_le_imp_less nth_list_update_eq nth_list_update_neq)
  apply (rule_tac x="list_update (i@(repeat y a)) y a" in exI)
  apply (simp add: not_le)
  by (metis length_input2state_repeat input2state_nth input2state_out_of_bounds le_trans length_append_repeat length_list_update not_le_imp_less nth_append nth_list_update_eq nth_list_update_neq option.distinct(1))

lemma input2state_double_exists_2:
  "x \<noteq> y \<Longrightarrow> \<exists>i. input2state i $r x = Some a \<and> input2state i $r y = Some a'"
  apply (insert input2state_exists[of x a])
  apply clarify
  apply (case_tac "x \<ge> y")
  apply (rule_tac x="list_update i y a'" in exI)
  apply (metis (no_types, lifting) input2state_within_bounds input2state_nth input2state_out_of_bounds le_trans length_list_update not_le_imp_less nth_list_update_eq nth_list_update_neq)
  apply (rule_tac x="list_update (i@(repeat y a')) y a'" in exI)
  apply (simp add: not_le)
  apply standard
  apply (metis input2state_nth input2state_within_bounds le_trans length_append_repeat length_list_update linorder_not_le nth_append nth_list_update_neq order_refl)
  by (metis input2state_nth length_append length_input2state_repeat length_list_update length_repeat nth_list_update_eq)

definition join_ir :: "value list \<Rightarrow> registers \<Rightarrow> vname datastate" where
  "join_ir i r \<equiv> (\<lambda>x. case x of
    R n \<Rightarrow> r $r n |
    I n \<Rightarrow> (input2state i) $r n
  )"

lemmas datastate = join_ir_def input2state_def

lemma join_ir_empty [simp]: "join_ir [] <> = (\<lambda>x. None)"
  apply (rule ext)
  apply (simp add: join_ir_def)
  apply (case_tac x)
   apply (simp add: input2state_def)
  by simp

lemma join_ir_R [simp]: "(join_ir i r) (R n) = r $r n"
  by (simp add: join_ir_def)

lemma join_ir_double_exists:
  "\<exists>i r. join_ir i r v = Some a \<and> join_ir i r v' = Some a"
proof(cases v)
  case (I x1)
  then show ?thesis
    apply (simp add: join_ir_def)
    apply (cases v')
     apply (simp add: input2state_double_exists input2state_exists)
    using input2state_exists by auto
next
  case (R x2)
  then show ?thesis
    apply (simp add: join_ir_def)
    apply (cases v')
    using input2state_exists apply force
    using input2state_double_exists by fastforce
qed

lemma join_ir_double_exists_2:
  "v \<noteq> v' \<Longrightarrow> \<exists>i r. join_ir i r v = Some a \<and> join_ir i r v' = Some a'"
proof(cases v)
  case (I x1)
  assume "v \<noteq> v'"
  then show ?thesis using I input2state_exists 
    by (cases v', auto simp add: join_ir_def input2state_double_exists_2)
next
  case (R x2)
  assume "v \<noteq> v'"
  then show ?thesis
    apply (simp add: join_ir_def)
    apply (cases v')
     apply simp
    using R input2state_exists apply auto[1]
    apply (simp add: R)
    apply (rule_tac x="<x2 $r:= Some a,x2a $r:= Some a'>" in exI)
    by simp
qed

lemma exists_join_ir_ext: "\<exists>i r. join_ir i r v = s v"
  apply (simp add: join_ir_def)
  apply (case_tac "s v")
   apply (cases v)
    apply (rule_tac x="[]" in exI)
    apply (simp add: input2state_out_of_bounds)
   apply simp
   apply (rule_tac x="<>" in exI)
   apply simp
  apply simp
  apply (cases v)
   apply simp
   apply (simp add: input2state_exists)
  apply simp
  apply (rule_tac x="<x2 $r:= Some a>" in exI)
  using update_value by auto

lemma join_ir_nth [simp]:
  "i < length is \<Longrightarrow> join_ir is r (I i) = Some (is ! i)"
  by (simp add: join_ir_def input2state_nth)

fun aexp_constrains :: "'a aexp \<Rightarrow> 'a aexp \<Rightarrow> bool" where
  "aexp_constrains (L l) a = (L l = a)" |
  "aexp_constrains (V v) v' = (V v = v')" |
  "aexp_constrains (Plus a1 a2) v = ((Plus a1 a2) = v \<or> (Plus a1 a2) = v \<or> (aexp_constrains a1 v \<or> aexp_constrains a2 v))" |
  "aexp_constrains (Minus a1 a2) v = ((Minus a1 a2) = v \<or> (aexp_constrains a1 v \<or> aexp_constrains a2 v))" |
  "aexp_constrains (Times a1 a2) v = ((Times a1 a2) = v \<or> (aexp_constrains a1 v \<or> aexp_constrains a2 v))" |
  "aexp_constrains (Divide a1 a2) v = ((Times a1 a2) = v \<or> (aexp_constrains a1 v \<or> aexp_constrains a2 v))"

fun aexp_same_structure :: "'a aexp \<Rightarrow> 'a aexp \<Rightarrow> bool" where
  "aexp_same_structure (L v) (L v') = True" |
  "aexp_same_structure (V v) (V v') = True" |
  "aexp_same_structure (Plus a1 a2) (Plus a1' a2') = (aexp_same_structure a1 a1' \<and> aexp_same_structure a2 a2')" |
  "aexp_same_structure (Minus a1 a2) (Minus a1' a2') = (aexp_same_structure a1 a1' \<and> aexp_same_structure a2 a2')" |
  "aexp_same_structure _ _ = False"

fun enumerate_aexp_inputs :: "vname aexp \<Rightarrow> nat set" where
  "enumerate_aexp_inputs (L _) = {}" |
  "enumerate_aexp_inputs (V (I n)) = {n}" |
  "enumerate_aexp_inputs (V (R n)) = {}" |
  "enumerate_aexp_inputs (Plus v va) = enumerate_aexp_inputs v \<union> enumerate_aexp_inputs va" |
  "enumerate_aexp_inputs (Minus v va) = enumerate_aexp_inputs v \<union> enumerate_aexp_inputs va" |
  "enumerate_aexp_inputs (Times v va) = enumerate_aexp_inputs v \<union> enumerate_aexp_inputs va" |
  "enumerate_aexp_inputs (Divide v va) = enumerate_aexp_inputs v \<union> enumerate_aexp_inputs va"

lemma enumerate_aexp_inputs_list: "\<exists>l. enumerate_aexp_inputs a = set l"
proof(induct a)
  case (L x)
  then show ?case by simp
next
  case (V x)
  then show ?case
    apply (cases x)
     apply (metis empty_set enumerate_aexp_inputs.simps(2) list.simps(15))
    by simp
next
  case (Plus a1 a2)
  then show ?case
    by (metis enumerate_aexp_inputs.simps(4) set_union)
next
  case (Minus a1 a2)
  then show ?case
    by (metis enumerate_aexp_inputs.simps(5) set_union)
next
  case (Times a1 a2)
  then show ?case
    by (metis enumerate_aexp_inputs.simps(6) set_union)
next
  case (Divide a1 a2)
  then show ?case
    by (metis enumerate_aexp_inputs.simps(7) set_union)
qed

fun enumerate_regs :: "vname aexp \<Rightarrow> nat set" where
  "enumerate_regs (L _) = {}" |
  "enumerate_regs (V (R n)) = {n}" |
  "enumerate_regs (V (I _)) = {}" |
  "enumerate_regs (Plus v va) = enumerate_regs v \<union> enumerate_regs va" |
  "enumerate_regs (Minus v va) = enumerate_regs v \<union> enumerate_regs va" |
  "enumerate_regs (Times v va) = enumerate_regs v \<union> enumerate_regs va" |
  "enumerate_regs (Divide v va) = enumerate_regs v \<union> enumerate_regs va"

lemma finite_enumerate_regs: "finite (enumerate_regs a)"
  by(induct a rule: aexp_induct_separate_V_cases, auto)

lemma no_variables_aval: "enumerate_aexp_inputs a = {} \<Longrightarrow>
   enumerate_regs a = {} \<Longrightarrow>
   aval a s = aval a s'"
  by (induct a rule: aexp_induct_separate_V_cases, auto)

lemma enumerate_aexp_inputs_not_empty:
  "(enumerate_aexp_inputs a \<noteq> {}) = (\<exists>b c. enumerate_aexp_inputs a = set (b#c))"
  using enumerate_aexp_inputs_list by fastforce

lemma aval_ir_take: "A \<le> length i \<Longrightarrow>
  enumerate_regs a = {} \<Longrightarrow>
  enumerate_aexp_inputs a \<noteq> {} \<Longrightarrow>
  Max (enumerate_aexp_inputs a) < A \<Longrightarrow>
  aval a (join_ir (take A i) r) = aval a (join_ir i ra)"
proof(induct a)
  case (L x)
  then show ?case
    by simp
next
  case (V x)
  then show ?case
    apply (cases x)
     apply (simp add: join_ir_def input2state_nth)
    by simp
next
  case (Plus a1 a2)
  then show ?case
    apply (simp only: enumerate_aexp_inputs_not_empty[of "Plus a1 a2"])
    apply (erule exE)+
    apply (simp only: neq_Nil_conv List.linorder_class.Max.set_eq_fold)
    apply (case_tac "fold max c b \<le> length i")
     apply simp
     apply (metis List.finite_set Max.union Plus.prems(4) enumerate_aexp_inputs.simps(4) enumerate_aexp_inputs_not_empty max_less_iff_conj no_variables_aval sup_bot.left_neutral sup_bot.right_neutral)
    by simp
next
  case (Minus a1 a2)
  then show ?case
    apply (simp only: enumerate_aexp_inputs_not_empty[of "Minus a1 a2"])
    apply (erule exE)+
    apply (simp only: neq_Nil_conv List.linorder_class.Max.set_eq_fold)
    apply (case_tac "fold max c b \<le> length i")
     apply simp
    apply (metis List.finite_set Max.union Minus.prems(4) enumerate_aexp_inputs.simps(5) enumerate_aexp_inputs_not_empty max_less_iff_conj no_variables_aval sup_bot.left_neutral sup_bot.right_neutral)
    by simp
next
  case (Times a1 a2)
  then show ?case
    apply (simp only: enumerate_aexp_inputs_not_empty[of "Times a1 a2"])
    apply (erule exE)+
    apply (simp only: neq_Nil_conv List.linorder_class.Max.set_eq_fold)
    apply (case_tac "fold max c b \<le> length i")
     apply simp
    apply (metis List.finite_set Max.union Times.prems(4) enumerate_aexp_inputs.simps(6) enumerate_aexp_inputs_not_empty max_less_iff_conj no_variables_aval sup_bot.left_neutral sup_bot.right_neutral)
    by simp
next
  case (Divide a1 a2)
  then show ?case
    apply (simp only: enumerate_aexp_inputs_not_empty[of "Divide a1 a2"])
    apply (erule exE)+
    apply (simp only: neq_Nil_conv List.linorder_class.Max.set_eq_fold)
    apply (case_tac "fold max c b \<le> length i")
     apply simp
    apply (metis List.finite_set Max.union Divide.prems(4) enumerate_aexp_inputs.simps(7) enumerate_aexp_inputs_not_empty max_less_iff_conj no_variables_aval sup_bot.left_neutral sup_bot.right_neutral)
    by simp
qed

definition max_input :: "vname aexp \<Rightarrow> nat option" where
  "max_input g = (let inputs = (enumerate_aexp_inputs g) in if inputs = {} then None else Some (Max inputs))"

definition max_reg :: "vname aexp \<Rightarrow> nat option" where
  "max_reg g = (let regs = (enumerate_regs g) in if regs = {} then None else Some (Max regs))"

lemma max_reg_V_I: "max_reg (V (I n)) = None"
  by (simp add: max_reg_def)

lemma max_reg_V_R: "max_reg (V (R n)) = Some n"
  by (simp add: max_reg_def)

lemmas max_reg_V = max_reg_V_I max_reg_V_R

lemma max_reg_Plus: "max_reg (Plus a1 a2) = max (max_reg a1) (max_reg a2)"
  apply (simp add: max_reg_def Let_def max_absorb2)
  by (metis Max.union bot_option_def finite_enumerate_regs max_bot2 sup_Some sup_max)

lemma max_reg_Minus: "max_reg (Minus a1 a2) = max (max_reg a1) (max_reg a2)"
  apply (simp add: max_reg_def Let_def max_absorb2)
  by (metis Max.union bot_option_def finite_enumerate_regs max_bot2 sup_Some sup_max)

lemma max_reg_Times: "max_reg (Times a1 a2) = max (max_reg a1) (max_reg a2)"
  apply (simp add: max_reg_def Let_def max_absorb2)
  by (metis Max.union bot_option_def finite_enumerate_regs max_bot2 sup_Some sup_max)

lemma max_reg_Divide: "max_reg (Divide a1 a2) = max (max_reg a1) (max_reg a2)"
  apply (simp add: max_reg_def Let_def max_absorb2)
  by (metis Max.union bot_option_def finite_enumerate_regs max_bot2 sup_Some sup_max)

lemma no_reg_aval_swap_regs:
  "max_reg a = None \<Longrightarrow> aval a (join_ir i r) = aval a (join_ir i r')"
proof(induct a)
  case (V x)
  then show ?case
    apply (cases x)
     apply (simp add: join_ir_def)
    by (simp add: join_ir_def max_reg_def)
next
  case (Plus a1 a2)
  then show ?case
    by (metis (no_types, lifting) aval.simps(3) max.absorb2 max.cobounded2 max_reg_Plus sup_None_2 sup_max)
next
  case (Minus a1 a2)
  then show ?case
    by (metis (no_types, lifting) aval.simps(4) max.cobounded2 max_def_raw max_reg_Minus sup_None_2 sup_max)
next
  case (Times a1 a2)
  then show ?case
  proof -
    have "bot = max_reg a2"
      by (metis (no_types) Times.prems bot_option_def max.left_commute max_bot2 max_def_raw max_reg_Times)
    then show ?thesis
      by (metis Times.hyps(1) Times.hyps(2) Times.prems aval.simps(5) bot_option_def max_bot2 max_reg_Times)
  qed
next
  case (Divide a1 a2)
  then show ?case
  proof -
    have "bot = max_reg a2"
      by (metis (no_types) Divide.prems bot_option_def max.left_commute max_bot2 max_def_raw max_reg_Divide)
    then show ?thesis
      by (metis Divide.hyps(1) Divide.hyps(2) Divide.prems aval.simps(6) bot_option_def max_bot2 max_reg_Divide)
  qed
qed auto

lemma aval_reg_some_superset:
"\<forall>a. (r $r a  \<noteq> None) \<longrightarrow> r $r a = r' $r a \<Longrightarrow>
 aval a (join_ir i r) = Some v \<Longrightarrow>
 aval a (join_ir i r') = Some v"
proof(induct a arbitrary: v rule: aexp_induct_separate_V_cases)
  case (L x)
  then show ?case by simp
next
  case (I x)
  then show ?case by (metis max_reg_V_I no_reg_aval_swap_regs)
next
  case (R x)
  then show ?case by simp
next
  case (Plus x1a x2a)
  then show ?case 
    apply simp
    by (metis maybe_arith_not_None option.simps(3) value_plus_def)
next
  case (Minus x1a x2a)
  then show ?case
    apply simp 
    by (metis (full_types) maybe_arith_not_None option.simps(3) value_minus_def)
next
  case (Times x1a x2a)
  then show ?case
    apply simp
    by (metis (full_types) maybe_arith_not_None option.simps(3) value_times_def)
next
  case (Divide x1a x2a)
  then show ?case
    apply simp
    by (metis (full_types) maybe_arith_not_None option.simps(3) value_divide_def)
qed

lemma aval_reg_none_superset:
"\<forall>a. (r $r a  \<noteq> None) \<longrightarrow> r $r a = r' $r a \<Longrightarrow>
 aval a (join_ir i r') = None \<Longrightarrow>
 aval a (join_ir i r) = None"
proof(induct a)
  case (L x)
  then show ?case by simp
next
  case (V x)
  then show ?case
    apply (cases x)
     apply (simp add: join_ir_def)
    by auto
next
  case (Plus a1 a2)
  then show ?case by (metis aval_reg_some_superset not_Some_eq)
next
  case (Minus a1 a2)
  then show ?case by (metis aval_reg_some_superset not_Some_eq)
next
  case (Times a1 a2)
  then show ?case by (metis aval_reg_some_superset not_Some_eq)
next
  case (Divide a1 a2)
  then show ?case by (metis aval_reg_some_superset not_Some_eq)
qed

lemma enumerate_regs_empty_reg_unconstrained:
  "enumerate_regs a = {} \<Longrightarrow> \<forall>r. \<not> aexp_constrains a (V (R r))"
  by (induct a rule: aexp_induct_separate_V_cases, auto)

lemma enumerate_aexp_inputs_empty_input_unconstrained:
  "enumerate_aexp_inputs a = {} \<Longrightarrow> \<forall>r. \<not> aexp_constrains a (V (I r))"
  by (induct a rule: aexp_induct_separate_V_cases, auto)

lemma input_unconstrained_aval_input_swap:
  "\<forall>i. \<not> aexp_constrains a (V (I i)) \<Longrightarrow>
   aval a (join_ir i r) = aval a (join_ir i' r)"
  using join_ir_def
  by (induct a rule: aexp_induct_separate_V_cases, auto)

lemma input_unconstrained_aval_register_swap:
  "\<forall>i. \<not> aexp_constrains a (V (R i)) \<Longrightarrow>
   aval a (join_ir i r) = aval a (join_ir i r')"
  using join_ir_def
  by (induct a rule: aexp_induct_separate_V_cases, auto)

lemma unconstrained_variable_swap_aval:
  "\<forall>i. \<not> aexp_constrains a (V (I i)) \<Longrightarrow>
   \<forall>r. \<not> aexp_constrains a (V (R r)) \<Longrightarrow>
   aval a s = aval a s'"
  by (induct a rule: aexp_induct_separate_V_cases, auto)

lemma max_input_I: "max_input (V (vname.I i)) = Some i"
  by (simp add: max_input_def)

lemma max_input_Plus:
  "max_input (Plus a1 a2) = max (max_input a1) (max_input a2)"
  apply (simp add: max_input_def Let_def max.commute max_absorb2)
  by (metis List.finite_set Max.union enumerate_aexp_inputs_list sup_Some sup_max)

lemma max_input_Minus:
  "max_input (Minus a1 a2) = max (max_input a1) (max_input a2)"
  apply (simp add: max_input_def Let_def max.commute max_absorb2)
  by (metis List.finite_set Max.union enumerate_aexp_inputs_list sup_Some sup_max)

lemma max_input_Times:
  "max_input (Times a1 a2) = max (max_input a1) (max_input a2)"
  apply (simp add: max_input_def Let_def max.commute max_absorb2)
  by (metis List.finite_set Max.union enumerate_aexp_inputs_list sup_Some sup_max)

lemma max_input_Divide:
  "max_input (Divide a1 a2) = max (max_input a1) (max_input a2)"
  apply (simp add: max_input_def Let_def max.commute max_absorb2)
  by (metis List.finite_set Max.union enumerate_aexp_inputs_list sup_Some sup_max)

lemma aval_take:
  "max_input x < Some a \<Longrightarrow>
   aval x (join_ir i r) = aval x (join_ir (take a i) r)"
proof(induct x rule: aexp_induct_separate_V_cases)
  case (I x)
  then show ?case
    by (metis aval.simps(2) input2state_take join_ir_def le_cases less_option_Some max_input_I take_all vname.simps(5))
next
  case (R x)
  then show ?case
    by (simp add: join_ir_def)
next
  case (Plus x1a x2a)
  then show ?case
    by (simp add: max_input_Plus)
next
  case (Minus x1a x2a)
  then show ?case
    by (simp add: max_input_Minus)
next
  case (Times x1a x2a)
  then show ?case
    by (simp add: max_input_Times)
next
  case (Divide x1a x2a)
  then show ?case
    by (simp add: max_input_Divide)
qed auto

lemma aval_no_reg_swap_regs: "max_input x < Some a \<Longrightarrow>
   max_reg x = None \<Longrightarrow>
   aval x (join_ir i ra) = aval x (join_ir (take a i) r)"
proof(induct x)
  case (V x)
  then show ?case
    apply (cases x)
     apply (metis aval_take enumerate_regs.simps(3) enumerate_regs_empty_reg_unconstrained input_unconstrained_aval_register_swap)
    by (simp add: max_reg_def)
next
  case (Plus x1 x2)
  then show ?case
    by (metis aval_take no_reg_aval_swap_regs)
next
  case (Minus x1 x2)
  then show ?case
    by (metis aval_take no_reg_aval_swap_regs)
next
  case (Times x1 x2)
  then show ?case
    by (metis aval_take no_reg_aval_swap_regs)
next
  case (Divide x1 x2)
  then show ?case
    by (metis aval_take no_reg_aval_swap_regs)
qed auto

fun enumerate_aexp_strings :: "'a aexp \<Rightarrow> String.literal set" where
  "enumerate_aexp_strings (L (Str s)) = {s}" |
  "enumerate_aexp_strings (L _) = {}" |
  "enumerate_aexp_strings (V _) = {}" |
  "enumerate_aexp_strings (Plus a1 a2) = enumerate_aexp_strings a1 \<union> enumerate_aexp_strings a2" |
  "enumerate_aexp_strings (Minus a1 a2) = enumerate_aexp_strings a1 \<union> enumerate_aexp_strings a2" |
  "enumerate_aexp_strings (Times a1 a2) = enumerate_aexp_strings a1 \<union> enumerate_aexp_strings a2" |
  "enumerate_aexp_strings (Divide a1 a2) = enumerate_aexp_strings a1 \<union> enumerate_aexp_strings a2"

fun enumerate_aexp_ints :: "'a aexp \<Rightarrow> int set" where
  "enumerate_aexp_ints (L (value.Int s)) = {s}" |
  "enumerate_aexp_ints (L _) = {}" |
  "enumerate_aexp_ints (V _) = {}" |
  "enumerate_aexp_ints (Plus a1 a2) = enumerate_aexp_ints a1 \<union> enumerate_aexp_ints a2" |
  "enumerate_aexp_ints (Minus a1 a2) = enumerate_aexp_ints a1 \<union> enumerate_aexp_ints a2" |
  "enumerate_aexp_ints (Times a1 a2) = enumerate_aexp_ints a1 \<union> enumerate_aexp_ints a2" |
  "enumerate_aexp_ints (Divide a1 a2) = enumerate_aexp_ints a1 \<union> enumerate_aexp_ints a2"

definition enumerate_vars :: "vname aexp \<Rightarrow> vname set" where
  "enumerate_vars a = (image I (enumerate_aexp_inputs a)) \<union> (image R (enumerate_regs a))"

fun rename_regs :: "(nat \<Rightarrow> nat) \<Rightarrow> vname aexp \<Rightarrow> vname aexp" where
  "rename_regs _ (L l) = (L l)" |
  "rename_regs f (V (R r)) = (V (R (f r)))" |
  "rename_regs _ (V v) = (V v)" |
  "rename_regs f (Plus a b) = Plus (rename_regs f a) (rename_regs f b)" |
  "rename_regs f (Minus a b) = Minus (rename_regs f a) (rename_regs f b)" |
  "rename_regs f (Times a b) = Minus (rename_regs f a) (rename_regs f b)" |
  "rename_regs f (Divide a b) = Times (rename_regs f a) (rename_regs f b)"

definition eq_upto_rename :: "vname aexp \<Rightarrow> vname aexp \<Rightarrow> bool" where
  "eq_upto_rename a1 a2 = (\<exists>f. bij f \<and> rename_regs f a1 = a2)"

end
