theory Code_Generation
  imports 
   "HOL-Library.Code_Target_Numeral"
   Inference SelectionStrategies
   Type_Inference
   "heuristics/Store_Reuse_Subsumption"
   "heuristics/Increment_Reset"
   "heuristics/Same_Register"
   "heuristics/Ignore_Inputs"
   EFSM_Dot
   Code_Target_FSet
   Code_Target_Set
   Can_Take
 efsm2sal
begin

declare One_nat_def [simp del]

code_printing
  constant HOL.conj \<rightharpoonup> (Scala) "_ && _" |
  constant HOL.disj \<rightharpoonup> (Scala) "_ || _" |
  constant "HOL.equal :: bool \<Rightarrow> bool \<Rightarrow> bool" \<rightharpoonup> (Scala) infix 4 "==" |
  constant "fst" \<rightharpoonup> (Scala) "_.'_1" |
  constant "snd" \<rightharpoonup> (Scala) "_.'_2"

(* This gives us a speedup because we can check this before we have to call out to z3 *)
fun mutex :: "gexp \<Rightarrow>  gexp \<Rightarrow> bool" where
  "mutex (Eq (V v) (L l)) (Eq (V v') (L l')) = (if v = v' then l \<noteq> l' else False)" |
  "mutex _ _ = False"

lemma mutex_not_gval: "mutex x y \<Longrightarrow> gval (gAnd y x) s \<noteq> true"
  apply (induct x y rule: mutex.induct)
  apply simp
                      apply (metis option.inject)
  by auto

definition choice_cases :: "transition \<Rightarrow> transition \<Rightarrow> bool" where
  "choice_cases t1 t2 = (
     if Guard t1 = Guard t2 then
       satisfiable (fold gAnd (rev (Guard t1)) (gexp.Bc True))
     else if \<exists>(x, y) \<in> set (List.product (Guard t1) (Guard t2)). mutex x y then
       False
     else
       satisfiable ((fold gAnd (rev (Guard t1@Guard t2)) (gexp.Bc True)))
   )"

lemma existing_mutex_not_true: "\<exists>x\<in>set G. \<exists>y\<in>set G. mutex x y \<Longrightarrow> \<not> apply_guards G s"
  apply clarify
  apply (simp add: apply_guards_rearrange)
  apply (case_tac "y \<in> set (x#G)")
   defer
   apply simp
  apply (simp only: apply_guards_rearrange)
  apply simp
  apply (simp only: apply_guards_double_cons)
  using mutex_not_gval
  by simp

lemma [code]: "choice t t' = choice_cases t t'"
  apply (simp only: choice_alt choice_cases_def)
  apply (case_tac "Guard t = Guard t'")
   apply (simp add: choice_alt_def apply_guards_append)
   apply (simp add: apply_guards_foldr fold_conv_foldr satisfiable_def)
  apply (case_tac "\<exists>x\<in>set (map (\<lambda>(x, y). mutex x y) (List.product (Guard t) (Guard t'))). x")
   apply (simp add: choice_alt_def)
  using existing_mutex_not_true
   apply (metis Un_iff set_append)
  by (simp add: apply_guards_foldr choice_alt_def fold_conv_foldr satisfiable_def)

declare ListMem_iff [code]

fun guardMatch_alt :: "gexp list \<Rightarrow> gexp list \<Rightarrow> bool" where
  "guardMatch_alt [(gexp.Eq (V (vname.I i)) (L (Num n)))] [(gexp.Eq (V (vname.I i')) (L (Num n')))] = (i = 0 \<and> i' = 0)" |
  "guardMatch_alt _ _ = False"

lemma [code]: "guardMatch t1 t2 = guardMatch_alt (Guard t1) (Guard t2)"
  apply (simp add: guardMatch_def)
  using guardMatch_alt.elims(2) by fastforce

fun outputMatch_alt :: "output_function list \<Rightarrow> output_function list \<Rightarrow> bool" where
  "outputMatch_alt [L (Num n)] [L (Num n')] = True" |
  "outputMatch_alt _ _ = False"

lemma [code]: "outputMatch t1 t2 = outputMatch_alt (Outputs t1) (Outputs t2)"
  by (metis outputMatch_alt.elims(2) outputMatch_alt.simps(1) outputMatch_def)

fun always_different_outputs :: "aexp list \<Rightarrow> aexp list \<Rightarrow> bool" where
  "always_different_outputs [] [] = False" |
  "always_different_outputs [] (a#_) = True" |
  "always_different_outputs (a#_) [] = True" |
  "always_different_outputs ((L v)#t) ((L v')#t') = (if v = v' then always_different_outputs t t' else True)" |
  "always_different_outputs (h#t) (h'#t') = always_different_outputs t t'"

lemma always_different_outputs_outputs_never_equal: "always_different_outputs O1 O2 \<Longrightarrow> apply_outputs O1 s \<noteq> apply_outputs O2 s"
proof(induct O1 O2 rule: always_different_outputs.induct)
  case 1
  then show ?case
    by simp
next
  case (2 a uu)
  then show ?case
    by (simp add: apply_outputs_def)
next
  case (3 a uv)
  then show ?case
    by (simp add: apply_outputs_def)
next
  case (4 v t v' t')
  then show ?case
    by (simp add: apply_outputs_def)
next
  case ("5_1" v t h' t')
  then show ?case
    by (simp add: apply_outputs_def)
next
  case ("5_2" v va t h' t')
  then show ?case
    by (simp add: apply_outputs_def)
next
case ("5_3" v va t h' t')
  then show ?case
    by (simp add: apply_outputs_def)
next
  case ("5_4" h t v t')
  then show ?case
    by (simp add: apply_outputs_def)
next
  case ("5_5" h t v va t')
  then show ?case
    by (simp add: apply_outputs_def)
next
  case ("5_6" h t v va t')
  then show ?case
    by (simp add: apply_outputs_def)
qed

fun tests_input_equality :: "nat \<Rightarrow> gexp \<Rightarrow> bool" where
  "tests_input_equality i (gexp.Eq (V (vname.I i')) (L _)) = (i = i')" |
  "tests_input_equality _ _ = False"

definition is_generalised_output_of :: "transition \<Rightarrow> transition \<Rightarrow> iEFSM \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> bool" where
  "is_generalised_output_of t' t e i r = (\<exists>to \<in> fset (S e). \<exists> from \<in> fset (S e). \<exists> uid \<in> fset (uids e). t' = generalise_output t i r \<and> (uid, (from, to), t') |\<in>| e)"

(* definition "no_illegal_updates t r i = (\<forall>i. \<forall>u \<in> set (Updates t). fst u \<noteq> (R r) \<and> fst u \<noteq> (I i))" *)
fun no_illegal_updates_code :: "update_function list \<Rightarrow> nat \<Rightarrow> bool" where
  "no_illegal_updates_code [] _ = True" |
  "no_illegal_updates_code ((r', u)#t) r = (r \<noteq> r' \<and> no_illegal_updates_code t r)"

lemma no_illegal_updates_code_aux: "(\<forall>u\<in>set u. fst u \<noteq> r) = no_illegal_updates_code u r"
proof(induct u)
case Nil
  then show ?case
    by simp
next
case (Cons a u)
  then show ?case
    apply (cases a)
    apply (case_tac aa)
    by auto
qed

lemma no_illegal_updates_code [code]: "no_illegal_updates t r = no_illegal_updates_code (Updates t) r"
  by (simp add: no_illegal_updates_def no_illegal_updates_code_aux)

definition random_member :: "'a fset \<Rightarrow> 'a option" where
  "random_member f = (if f = {||} then None else Some (Eps (\<lambda>x. x |\<in>| f)))"

definition step :: "transition_matrix \<Rightarrow> nat \<Rightarrow> registers \<Rightarrow> label \<Rightarrow> inputs \<Rightarrow> (transition \<times> nat \<times> outputs \<times> registers) option" where
"step e s r l i = (let possibilities = possible_steps e s r l i in
                   if possibilities = {||} then None
                   else
                     case random_member possibilities of
                     None \<Rightarrow> None |
                     Some (s', t) \<Rightarrow>
                     let outputs = EFSM.apply_outputs (Outputs t) (join_ir i r) in
                     Some (t, s', outputs, (EFSM.apply_updates (Updates t) (join_ir i r) r))
                  )"

lemma [code]: "EFSM.step x xa xb xc xd = step x xa xb xc xd"
  by (simp add: EFSM.step_def step_def Let_def random_member_def)

declare random_member_def [code del]

code_printing constant "random_member" \<rightharpoonup> (Scala) "Dirties.randomMember"

fun input_updates_register_aux :: "update_function list \<Rightarrow> nat option" where
  "input_updates_register_aux ((n, V (vname.I n'))#_) = Some n'" |
  "input_updates_register_aux (h#t) = input_updates_register_aux t" |
  "input_updates_register_aux [] = None"

definition input_updates_register :: "iEFSM \<Rightarrow> (nat \<times> String.literal)" where
  "input_updates_register e = (case fthe_elem (ffilter (\<lambda>(_, _, t). input_updates_register_aux (Updates t) \<noteq> None) e) of (_, _, t) \<Rightarrow> case input_updates_register_aux (Updates t) of Some n \<Rightarrow> (n, Label t))"

definition "dirty_directly_subsumes = directly_subsumes"
declare dirty_directly_subsumes_def [code del]
code_printing constant "dirty_directly_subsumes" \<rightharpoonup> (Scala) "Dirties.scalaDirectlySubsumes"

definition always_different_outputs_direct_subsumption ::"iEFSM \<Rightarrow> iEFSM \<Rightarrow> cfstate \<Rightarrow> cfstate \<Rightarrow> transition \<Rightarrow> transition \<Rightarrow> bool" where
"always_different_outputs_direct_subsumption m1 m2 s s' t1 t2 = (
   (\<exists>p. accepts (tm m1) 0 (K$ None) p \<and>
    gets_us_to s (tm m1) 0 (K$ None) p \<and>
    accepts (tm m2) 0 (K$ None) p \<and>
    gets_us_to s' (tm m2) 0 (K$ None) p \<and>
    (\<forall>c. anterior_context (tm m2) p = Some c \<longrightarrow> (\<exists>i. can_take_transition t2 i c))))"

lemma always_different_outputs_can_take_transition_not_subsumed: "always_different_outputs (Outputs t1) (Outputs t2) \<Longrightarrow>
       \<forall>c. posterior_sequence (tm m2) 0 (K$ None) p = Some c \<longrightarrow> (\<exists>i. can_take_transition t2 i c) \<longrightarrow> \<not> subsumes t1 c t2"
  apply standard
  apply standard
  apply standard
  apply (rule bad_outputs)
  using always_different_outputs_outputs_never_equal
  by metis

lemma always_different_outputs_direct_subsumption: 
  "always_different_outputs (Outputs t1) (Outputs t2) \<and> always_different_outputs_direct_subsumption m1 m2 s s' t1 t2 \<Longrightarrow> \<not> directly_subsumes m1 m2 s s' t1 t2"
  apply (simp add: directly_subsumes_def always_different_outputs_direct_subsumption_def)
  apply standard
  apply clarify
  apply (rule_tac x=p in exI)
  apply simp
  using always_different_outputs_can_take_transition_not_subsumed accepts_trace_gives_context
  by (meson accepts_gives_context)

lemma ponens: "(length i = Arity t \<and> (length i = Arity t \<longrightarrow> \<not> apply_guards (Guard t) (join_ir i c))) =
(length i = Arity t \<and> \<not> apply_guards (Guard t) (join_ir i c))"
  by auto

lemma satisfiable_negation_cant_subsume:
  "satisfiable_negation t \<Longrightarrow>
   \<not> subsumes t c (drop_guards t)"
  apply (rule bad_guards)
  apply (simp add: can_take_transition_def can_take_def drop_guards_def ponens)
  by (simp add: satisfiable_negation_def quick_negation)

definition updates_subset :: "transition \<Rightarrow> transition \<Rightarrow> iEFSM \<Rightarrow> bool" where
  "updates_subset t t' e = (
     case input_stored_in_reg t' t e of None \<Rightarrow> False | Some (i, r) \<Rightarrow>
     Arity t' = Arity t \<and>
     set (Guard t') \<subset> set (Guard t) \<and>
     r \<notin> set (map fst (removeAll (r, V (I i)) (Updates t'))) \<and>
     r \<notin> set (map fst (Updates t)) \<and>
     max_input (Guard t) < Some (Arity t) \<and>
     satisfiable_list ((Guard t) @ ensure_not_null (Arity t)) \<and>
     max_reg (Guard t) = None \<and>
     i < Arity t
  )"

lemma updates_subset_conditions: 
  "updates_subset t1 t2 e \<Longrightarrow>
   input_stored_in_reg t2 t1 e = Some (i, r) \<Longrightarrow>
   c $ r = None \<Longrightarrow>
   \<not> subsumes t1 c t2"
  apply (simp add: updates_subset_def)
  using can_take_satisfiable[of t1 c]
  apply simp
  apply (rule general_not_subsume_orig)
  using input_stored_in_reg_updates_reg
  by auto

definition "accepts_and_gets_us_to_both a b s s' = (
  \<exists>p. accepts_trace (tm a) p \<and>
      gets_us_to s (tm a) 0 <> p \<and>
      accepts_trace (tm b) p \<and>
      gets_us_to s' (tm b) 0 <> p)"

declare accepts_and_gets_us_to_both_def [code del]
code_printing constant accepts_and_gets_us_to_both \<rightharpoonup> (Scala) "Dirties.acceptsAndGetsUsToBoth"

lemma fMax_Some: "f \<noteq> {||} \<Longrightarrow> (\<exists>y. fMax f = Some y) = (\<exists>y. Some y |\<in>| f)"
  apply standard
   apply (metis fMax_in)
  using fMax_ge not_le by fastforce

lemma arg_cong_ffilter: "\<forall>e |\<in>| f. p e = p' e \<Longrightarrow> ffilter p f = ffilter p' f"
  by auto

lemma acceptance_empty_regs_args_aux: "Inference.max_reg b = None \<Longrightarrow>
       (a, bb) |\<in>| possible_steps (tm b) 0 <> ab ba \<Longrightarrow>
       accepts (tm b) a (apply_updates (Updates bb) (join_ir ba <>) <>) t = accepts (tm b) a <> t"
  using in_possible_steps[of a bb "tm b" 0 "<>" ab ba]
        max_reg_none_no_updates[of b]
       in_tm
  apply simp
  apply clarify
  by force

lemma acceptance_empty_regs_args: "Inference.max_reg b = None \<Longrightarrow>
       ffilter (\<lambda>(s', T). accepts (tm b) s' (apply_updates (Updates T) (join_ir ba <>) <>) t) (possible_steps (tm b) 0 <> ab ba) =
       ffilter (\<lambda>(s', T). accepts (tm b) s' <> t) (possible_steps (tm b) 0 <> ab ba)"
  apply (rule arg_cong_ffilter)
  apply clarify
  using in_possible_steps max_reg_none_no_updates
  by (simp add: acceptance_empty_regs_args_aux)

definition "drop_update_add_guard_direct_subsumption a b s s' t1 t2 = 
  (case input_stored_in_reg t2 t1 a of
   None \<Rightarrow> False |
   Some (i, r) \<Rightarrow>
     accepts_and_gets_us_to_both a b s s' \<and>
     initially_undefined_context_check b r s' \<and>
     updates_subset t1 t2 a
  )"

lemma drop_update_add_guard_direct_subsumption:
  "drop_update_add_guard_direct_subsumption a b s s' t1 t2 \<Longrightarrow>
  \<not>directly_subsumes a b s s' t1 t2"
  apply (simp add: drop_update_add_guard_direct_subsumption_def)
  apply (case_tac "input_stored_in_reg t2 t1 a")
   apply simp
  apply (simp add: directly_subsumes_def)
  apply (case_tac aa)
  apply (rule disjI1)
  apply (simp add: accepts_and_gets_us_to_both_def)
  apply clarify
  apply (rule_tac x=p in exI)
  apply (simp add: initially_undefined_context_check_def)
  using updates_subset_conditions by blast

definition directly_subsumes_cases :: "iEFSM \<Rightarrow> iEFSM \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> transition \<Rightarrow> transition \<Rightarrow> bool" where
  "directly_subsumes_cases a b s s' t1 t2 = (
    if t1 = t2
      then True
    else if always_different_outputs (Outputs t1) (Outputs t2) \<and> always_different_outputs_direct_subsumption a b s s' t1 t2
      then False
    else if drop_guard_add_update_direct_subsumption t1 t2 b s'
      then True
    else if drop_update_add_guard_direct_subsumption a b s s' t1 t2
      then False
    else if generalise_output_direct_subsumption t1 t2 b a s s'
      then True
    else if t1 = drop_guards t2
      then True
    else if t2 = drop_guards t1 \<and> satisfiable_negation t1
      then False
    else if simple_mutex t2 t1
      then False
    else dirty_directly_subsumes a b s s' t1 t2
  )"

definition "mprotect = \<lparr>Label = STR ''mprotect'', Arity = 3, Guard = [Eq (V (I 0)) (L (Num 140116919701504)), Eq (V (I 1)) (L (Num 2093056)), Eq (V (I 1)) (L (Str ''PROT_NONE''))], Outputs = [L (Num 0)], Updates = []\<rparr>"
definition "mprotect_dropped = \<lparr>Label = STR ''mprotect'', Arity = 3, Guard = [], Outputs = [L (Num 0)], Updates = []\<rparr>"

lemma [code]: "directly_subsumes m1 m2 s s' t1 t2 = directly_subsumes_cases m1 m2 s s' t1 t2"
  apply (simp only: directly_subsumes_cases_def)
  apply (case_tac "t1 = t2")
  apply (simp add: directly_subsumes_self)
  apply (case_tac "always_different_outputs (Outputs t1) (Outputs t2) \<and> always_different_outputs_direct_subsumption m1 m2 s s' t1 t2")
   apply (simp add: always_different_outputs_direct_subsumption)
  apply (case_tac "drop_guard_add_update_direct_subsumption t1 t2 m2 s'")
   apply (simp add: drop_guard_add_update_direct_subsumption_implies_direct_subsumption)
  apply (case_tac "drop_update_add_guard_direct_subsumption m1 m2 s s' t1 t2")
   apply (simp add: drop_update_add_guard_direct_subsumption)
  apply (case_tac "generalise_output_direct_subsumption t1 t2 m2 m1 s s'")
   apply (simp add: generalise_output_directly_subsumes_original_executable)
  apply (case_tac "t1 = drop_guards t2")
   apply (simp add: drop_inputs_subsumption subsumes_in_all_contexts_directly_subsumes)
  apply (simp add: always_different_outputs_direct_subsumption del: always_different_outputs.simps generalise_output_direct_subsumption.simps)
  apply (case_tac "t2 = drop_guards t1 \<and> satisfiable_negation t1")
   apply (simp del: always_different_outputs.simps generalise_output_direct_subsumption.simps)
  apply (simp add: cant_directly_subsume satisfiable_negation_cant_subsume)
  apply (case_tac "simple_mutex t2 t1")
  using simple_mutex_direct_subsumption apply blast
  using dirty_directly_subsumes_def by auto

definition is_generalisation_of :: "transition \<Rightarrow> transition \<Rightarrow> nat \<Rightarrow> nat \<Rightarrow> bool" where
  "is_generalisation_of t' t i r = (t' = remove_guard_add_update t i r \<and>
                                    i < Arity t \<and>
                                    r \<notin> set (map fst (Updates t)) \<and>
                                    (length (filter (tests_input_equality i) (Guard t)) \<ge> 1))"

lemma tests_input_equality: "(\<exists>v. gexp.Eq (V (vname.I xb)) (L v) \<in> set G) = (1 \<le> length (filter (tests_input_equality xb) G))"
proof(induct G)
  case Nil
  then show ?case by simp
next
  case (Cons a G)
  then show ?case
    apply (cases a)
        apply simp
       apply simp
       apply (case_tac x21)
          apply simp
         apply simp
         apply (case_tac "x2 = vname.I xb")
          apply simp
          defer
          defer
          apply simp+
     apply (case_tac x22)
        apply auto[1]
       apply simp+
    apply (case_tac x22)
    using tests_input_equality.elims(2) by auto
qed
                                                                  
lemma[code]: "Store_Reuse.is_generalisation_of x xa xb xc = is_generalisation_of x xa xb xc"
  apply (simp add: Store_Reuse.is_generalisation_of_def is_generalisation_of_def)
  using tests_input_equality by blast

definition iEFSM2dot :: "iEFSM \<Rightarrow> nat \<Rightarrow> unit" where
  "iEFSM2dot _ _ = ()"
code_printing constant iEFSM2dot \<rightharpoonup> (Scala) "PrettyPrinter.iEFSM2dot(_, _)"

definition logStates :: "nat \<Rightarrow> nat \<Rightarrow> unit" where
  "logStates _ _ = ()"
code_printing constant logStates \<rightharpoonup> (Scala) "Log.logStates(_, _)"

(* This is the infer function but with logging *)
function infer_with_log :: "nat \<Rightarrow> nat \<Rightarrow> iEFSM \<Rightarrow> strategy \<Rightarrow> update_modifier \<Rightarrow> (transition_matrix \<Rightarrow> bool) \<Rightarrow> (iEFSM \<Rightarrow> nondeterministic_pair fset) \<Rightarrow> iEFSM" where
  "infer_with_log stepNo k e r m check np = (
    case inference_step e (rev (sorted_list_of_fset (k_score k e r))) m check np of
      None \<Rightarrow> e |
      Some new \<Rightarrow> let 
        temp = iEFSM2dot e stepNo;
        temp2 = logStates (size (S new)) (size (S e)) in
        if (S new) |\<subset>| (S e) then
          infer_with_log (stepNo + 1) k new r m check np
        else e
  )"
  by auto
termination
  apply (relation "measures [\<lambda>(_, _, e, _). size (S e)]")
   apply simp
  using measures_fsubset by auto

declare GExp.satisfiable_def [code del]
declare initially_undefined_context_check_def [code del]
declare generalise_output_context_check_def [code del]
declare always_different_outputs_direct_subsumption_def [code del]

code_printing
  constant "GExp.satisfiable" \<rightharpoonup> (Scala) "Dirties.satisfiable" |
  constant "initially_undefined_context_check" \<rightharpoonup> (Scala) "Dirties.initiallyUndefinedContextCheck" |
  constant "generalise_output_context_check" \<rightharpoonup> (Scala) "Dirties.generaliseOutputContextCheck" |
  constant "always_different_outputs_direct_subsumption" \<rightharpoonup> (Scala) "Dirties.alwaysDifferentOutputsDirectSubsumption"

(* Use the native implementations of list functions *)
definition "flatmap l f = List.maps f l"

lemma [code]:"List.maps f l = flatmap l f"
  by (simp add: flatmap_def)

definition "map_code l f = List.map f l"
lemma [code]:"List.map f l = map_code l f"
  by (simp add: map_code_def)

declare map_filter_map_filter [code_unfold del]

lemma [code]: "removeAll a l = filter (\<lambda>x. x \<noteq> a) l"
  by (induct l arbitrary: a) simp_all

definition "filter_code l f = List.filter f l"
lemma [code]: "List.filter l f = filter_code f l"
  by (simp add: filter_code_def)

definition all :: "'a list \<Rightarrow> ('a \<Rightarrow> bool) \<Rightarrow> bool" where
  "all l f = list_all f l"

lemma [code]: "list_all f l = all l f"
  by (simp add: all_def)

definition ex :: "'a list \<Rightarrow> ('a \<Rightarrow> bool) \<Rightarrow> bool" where
  "ex l f = list_ex f l"

lemma [code]: "list_ex f l = ex l f"
  by (simp add: ex_def)

lemma fold_conv_foldl [code]: "fold f xs s = foldl (\<lambda>x s. f s x) s xs"
  by (simp add: foldl_conv_fold)

declare foldr_conv_foldl [code]

code_printing
  constant Cons \<rightharpoonup> (Scala) "_::_"
  | constant rev \<rightharpoonup> (Scala) "_.reverse"
  | constant List.member \<rightharpoonup> (Scala) "_ contains _"
  | constant "List.remdups" \<rightharpoonup> (Scala) "_.distinct"
  | constant "List.length" \<rightharpoonup> (Scala) "Nat.Nata(_.length)"
  | constant "zip" \<rightharpoonup> (Scala) "(_ zip _)"
  | constant "flatmap" \<rightharpoonup> (Scala) "_.par.flatMap((_)).toList"
  | constant "List.null" \<rightharpoonup> (Scala) "_.isEmpty"
  | constant "map_code" \<rightharpoonup> (Scala) "_.par.map((_)).toList"
  | constant "filter_code" \<rightharpoonup> (Scala) "_.par.filter((_)).toList"
  | constant "all" \<rightharpoonup> (Scala) "_.par.forall((_))"
  | constant "ex" \<rightharpoonup> (Scala) "_.par.exists((_))"
  | constant "nth" \<rightharpoonup> (Scala) "_(Code'_Numeral.integer'_of'_nat((_)).toInt)"
  | constant "foldl" \<rightharpoonup> (Scala) "Dirties.foldl"
  | constant "show_nat" \<rightharpoonup> (Scala) "Code'_Numeral.integer'_of'_nat((_)).toString()"
  | constant "show_int" \<rightharpoonup> (Scala) "Code'_Numeral.integer'_of'_int((_)).toString()"
  | constant "join" \<rightharpoonup> (Scala) "_.mkString((_))"
  | constant "(1::nat)" \<rightharpoonup> (Scala) "Nat.Nata((1))"

lemma [code]: "insert x (set s) = (if x \<in> set s then set s else set (x#s))"
  apply (simp)
  by auto

lemma [code]: "s |\<subset>| s' = (s |\<subseteq>| s' \<and> size s < size s')"
  apply standard
   apply (simp only: size_fsubset)
  by auto

lemma code_list_eq [code]: "HOL.equal xs ys \<longleftrightarrow> length xs = length ys \<and> (\<forall>(x,y) \<in> set (zip xs ys). x = y)"
  apply (simp add: HOL.equal_class.equal_eq)
  by (simp add: Ball_set list_eq_iff_zip_eq)

declare enumerate_eq_zip [code]

(* I'd ideally like to fix this at some point *)
lemma [code]: "infer = infer_with_log 0"
  apply (simp add: fun_eq_iff)
  apply clarify
  unfolding Let_def
  sorry

code_printing
  type_constructor finfun \<rightharpoonup> (Scala) "Map[_, _]"
  | constant "finfun_const" \<rightharpoonup> (Scala) "Map().withDefaultValue((_))"
  | constant "finfun_update" \<rightharpoonup> (Scala) "_ + (_ -> _)"
  | constant "finfun_apply" \<rightharpoonup> (Scala) "_((_))"

code_pred satisfies_trace.

export_code
  (* Essentials *)
  try_heuristics aexp_type_check learn infer_types nondeterministic input_updates_register
  (* Scoring functions *)
  naive_score naive_score_eq naive_score_outputs naive_score_comprehensive naive_score_comprehensive_eq_high
  origin_states
  (* Heuristics *)
  statewise_drop_inputs drop_inputs same_register insert_increment_2 heuristic_1 transitionwise_drop_inputs
  (* Nondeterminism metrics *)
  nondeterministic_pairs nondeterministic_pairs_labar
  (* Utilities *)
  iefsm2dot efsm2dot guards2sal
in Scala
  file "../../inference-tool/src/main/scala/inference/Inference.scala"

end