theory Simple_Drinks_Machine
imports "../Contexts" "../examples/Drinks_Machine_2" Inference
begin
definition t1 :: "transition" where
"t1 \<equiv> \<lparr>
        Label = ''select'',
        Arity = 1,
        Guard = [],
        Outputs = [],
        Updates = [(R 1, (V (I 1))), (R 2, (L (Num 0)))]
      \<rparr>"

definition coin50 :: "transition" where
"coin50 \<equiv> \<lparr>
        Label = ''coin'',
        Arity = 1,
        Guard = [(gexp.Eq (V (I 1)) (L (Num 50)))],
        Outputs = [(Plus (V (R 2)) (V (I 1)))],
        Updates = [(R 1, (V (R 1))),  (R 2, Plus (V (R 2)) (L (Num 50)))]
      \<rparr>"

lemma updates_coin50: "Updates coin50 = [(R 1, (V (R 1))),  (R 2, Plus (V (R 2)) (L (Num 50)))]"
  by (simp add: coin50_def)

definition coin :: "transition" where
"coin \<equiv> \<lparr>
        Label = ''coin'',
        Arity = 1,
        Guard = [],
        Outputs = [(Plus (V (R 2)) (V (I 1)))],
        Updates = [
                  (R 1, (V (R 1))),
                  (R 2, (Plus (V (R 2)) (V (I 1))))
                ]
      \<rparr>"

lemma guard_coin: "Guard coin = []"
  by (simp add: coin_def)

definition t3 :: "transition" where
"t3 \<equiv> \<lparr>
        Label = ''vend'',
        Arity = 0,
        Guard = [(Ge (V (R 2)) (L (Num 100)))],
        Outputs =  [(V (R 1))],
        Updates = [(R 1, (V (R 1))), (R 2, (V (R 2)))]
      \<rparr>"

definition vend :: "statename efsm" where
"vend \<equiv> \<lparr>
          s0 = q1,
          T = \<lambda> (a,b) .
                   if (a,b) = (q1,q2) then {|t1|} \<comment> \<open> If we want to go from state 1 to state 2 then t1 will do that \<close>
              else if (a,b) = (q2,q2) then {|coin50|} \<comment> \<open> If we want to go from state 2 to state 2 then coin50 will do that \<close>
              else if (a,b) = (q2,q3) then {|t3|} \<comment> \<open> If we want to go from state 2 to state 3 then t3 will do that \<close>
              else {||} \<comment> \<open> There are no other transitions \<close>
         \<rparr>"

definition vend_equiv :: "statename efsm" where
"vend_equiv \<equiv> \<lparr>
          s0 = q1,
          T = \<lambda> (a,b) .
                   if (a,b) = (q1,q2) then {|t1|} \<comment> \<open> If we want to go from state 1 to state 2 then t1 will do that \<close>
              else if (a,b) = (q2,q2) then {|coin|} \<comment> \<open> If we want to go from state 2 to state 2 then coin will do that \<close>
              else if (a,b) = (q2,q3) then {|t3|} \<comment> \<open> If we want to go from state 2 to state 3 then t3 will do that \<close>
              else {||} \<comment> \<open> There are no other transitions \<close>
         \<rparr>"


definition drinks2 :: "statename efsm" where
"drinks2 \<equiv> \<lparr>
          s0 = q0,
          T = \<lambda> (a,b) .
              if (a,b) = (q0,q1) then {|select|}
              else if (a,b) = (q1,q1) then {|vend_nothing|}
              else if (a,b) = (q1,q2) then {|coin50|}
              else if (a,b) = (q2,q2) then {|coin, vend_fail|}
              else if (a,b) = (q2,q3) then {|Drinks_Machine.vend|}
              else {||}
         \<rparr>"

lemma medial_coin50: "medial \<lbrakk>V (R 1) \<mapsto> cexp.Bc True, V (R 2) \<mapsto> cexp.Eq (Num n)\<rbrakk> (Guard coin50) = \<lbrakk>V (R 1) \<mapsto> cexp.Bc True, V (R 2) \<mapsto> cexp.Eq (Num n), V (I 1) \<mapsto> Eq (Num 50)\<rbrakk>"
  apply (simp add: coin50_def)
  apply (rule ext)
  by simp

lemma consistent_medial_coin50: "consistent (medial \<lbrakk>V (R 1) \<mapsto> cexp.Bc True, V (R 2) \<mapsto> cexp.Eq (Num n)\<rbrakk> (Guard coin50))"
  apply (simp add: coin50_def consistent_def del: Nat.One_nat_def)
  apply (rule_tac x="<R 1 := Num 1, R 2 := Num n, I 1 := Num 50>" in exI)
  by (simp add: consistent_empty_4)

lemma compose_plus_n_50: "(compose_plus (Eq (Num n)) (Eq (Num 50))) = Eq (Num (n+50))"
  apply (simp add: valid_def satisfiable_def)
  by auto

lemma coin50_posterior: "posterior \<lbrakk>V (R 1) \<mapsto> cexp.Bc True, V (R 2) \<mapsto> cexp.Eq (Num n)\<rbrakk> coin50 = \<lbrakk>V (R 1) \<mapsto> cexp.Bc True, V (R 2) \<mapsto> Eq (Num (n+50))\<rbrakk>"
  apply (simp add: posterior_def consistent_medial_coin50 del: Nat.One_nat_def)
  apply (simp only: medial_coin50 updates_coin50)
  apply (simp add: compose_plus_n_50 del: compose_plus.simps)
  apply (rule ext)
  by simp

lemma consistent_medial_coin: "consistent (medial \<lbrakk>V (R 1) \<mapsto> cexp.Bc True, V (R 2) \<mapsto> cexp.Eq (Num n), V (I 1) \<mapsto> cexp.Eq (Num 50)\<rbrakk> (Guard coin))"
  apply (simp add: coin_def consistent_def del: One_nat_def)
  apply (rule_tac x="<R 1 := Num 0, R 2 := Num n, I 1 := Num 50>" in exI)
  apply (simp del: One_nat_def)
  by (simp add: consistent_empty_4)

lemma consistent_medial_coin_2: "consistent (medial \<lbrakk>V (R 1) \<mapsto> cexp.Bc True, V (R 2) \<mapsto> cexp.Eq (Num n)\<rbrakk> (Guard coin))"
  apply (simp add: coin_def consistent_def del: One_nat_def)
  apply (rule_tac x="<R 1 := Num 0, R 2 := Num n, I 1 := Num 50>" in exI)
  apply (simp del: One_nat_def)
  by (simp add: consistent_empty_4)

lemma posterior_coin: "(posterior \<lbrakk>V (R 1) \<mapsto> cexp.Bc True, V (R 2) \<mapsto> cexp.Eq (Num n)\<rbrakk> coin) = \<lbrakk>V (R 1) \<mapsto> cexp.Bc True, V (R 2) \<mapsto> Bc True\<rbrakk>"
  apply (simp add: posterior_def consistent_medial_coin_2 del: Nat.One_nat_def)
  apply (simp add: coin_def compose_plus_n_50 valid_def satisfiable_def del: Nat.One_nat_def)
  apply (rule ext)
  by simp

(* Prove this to make sure that you've got "directly_subsumes" the right way round *)
lemma "directly_subsumes drinks2 q1 coin coin50"
  apply (simp add: directly_subsumes_def)
  sorry

\<comment> \<open> coin subsumes coin50 no matter how many times it is looped round \<close>
lemma "subsumes \<lbrakk>V (R 1) \<mapsto> Bc True, V (R 2) \<mapsto> Eq (Num n)\<rbrakk> coin coin50"
  apply (simp only: subsumes_def)
  apply safe
     apply (simp add: coin_def coin50_def del: One_nat_def)
     apply (case_tac "r = V (R 2)")
      apply simp
     apply (simp del: One_nat_def)
     apply (case_tac "r = V (R 1)")
      apply simp
     apply simp
     apply (case_tac "cval (\<lbrakk>\<rbrakk> r) i")
      apply simp
     apply (simp del: One_nat_def)
     apply (case_tac "r = V (I 1)")
      apply simp
     apply simp
    apply (simp add: coin50_def coin_def)
  sorry
   apply (simp only: medial_coin50 posterior_coin_2 coin50_posterior)
  apply (simp only: posterior_coin consistent_def)
  apply (rule_tac x="<>" in exI)
  apply (rule allI)
  apply simp
  using consistent_empty_4 by blast
end
