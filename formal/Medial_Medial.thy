theory Medial_Medial
imports Contexts
begin

lemma make_lt_expand:  "make_lt |`| (cp |\<union>| ca2) = (make_lt |`| cp) |\<union>| (make_lt |`| ca2)"
  by (simp add: fimage_funion)

lemma make_gt_expand:  "make_gt |`| (cp |\<union>| ca2) = (make_gt |`| cp) |\<union>| (make_gt |`| ca2)"
  by (simp add: fimage_funion)

lemma make_gt_twice: "make_gt (make_gt x) = make_gt x"
  apply (induct x)
  by auto

lemma make_lt_twice: "make_lt (make_lt x) = make_lt x"
  apply(induct x)
  by auto

lemma fimage_make_lt_twice: "make_lt |`| make_lt |`| cp = make_lt |`| cp"
proof(induct cp)
  case empty
  then show ?case
    by simp
next
  case (insert x cp)
  then show ?case
    by (simp add: make_lt_twice)
qed

lemma union_make_lt: "ca2 |\<union>| make_lt |`| (cp |\<union>| ca2) |\<union>|
         make_lt |`| (cp |\<union>| (ca2 |\<union>| make_lt |`| (cp |\<union>| ca2))) =
         ca2 |\<union>| make_lt |`| (cp |\<union>| ca2)"
  apply (simp only: make_lt_expand)
  apply (simp only: fimage_make_lt_twice)
  by auto

lemma make_gt_make_lt: "make_gt (make_lt xb) = make_lt (make_gt xb)"
proof(induct xb)
case Undef
  then show ?case by simp
next
  case (Bc x)
  then show ?case by simp
next
  case (Eq x)
  then show ?case by simp
next
  case (Lt x)
  then show ?case by simp
next
  case (Gt x)
  then show ?case by simp
next
  case (Not xb)
  then show ?case by simp
next
  case (And xb1 xb2)
  then show ?case by simp
qed

lemma aux: "(\<lambda>r. c r |\<union>| fold (|\<union>|) (map snd (filter (\<lambda>(a, uu). a = r) (guard2pairs c G))) {||} |\<union>|
         fold (|\<union>|)
          (map snd
            (filter (\<lambda>(a, uu). a = r)
              (guard2pairs (\<lambda>r. c r |\<union>| fold (|\<union>|) (map snd (filter (\<lambda>(a, uu). a = r) (guard2pairs c G))) {||})
                G)))
          {||}) =
    (\<lambda>r. c r |\<union>| fold (|\<union>|) (map snd (filter (\<lambda>(a, uu). a = r) (guard2pairs c G))) {||})"
proof(induct G)
case (Bc x)
  then show ?case
    apply (case_tac x)
    by auto
next
case (Eq a1 a2)
  then show ?case
  proof(induct a1)
    case (L x)
    then show ?case
      apply (induct a2)
      by auto
  next
    case (V x)
    then show ?case
    proof(induct a2)
      case (L x)
      then show ?case by simp
    next
      case (V v)
      then show ?case
        apply simp
        apply (case_tac "v = x")
         apply simp
         apply (rule ext)
         apply auto[1]
        apply simp
        apply (rule ext)
        by auto
    next
      case (Plus a21 a22)
      then show ?case
        apply (case_tac "a21 = a22")
         apply simp
         apply (rule ext)
         apply auto[1]
        apply simp
        apply (rule ext)
        by auto
    next
      case (Minus a21 a22)
      then show ?case
        apply simp
        apply (rule ext)
        by auto
    qed
  next
    case (Plus a11 a12)
    then show ?case
    proof(induct a2)
      case (L x)
      then show ?case
        apply (case_tac "a11 = a12")
         apply simp
        apply (rule ext)
        by auto
    next
      case (V x)
      then show ?case
        apply (case_tac "a11 = a12")
         apply simp
         apply (rule ext)
         apply auto[1]
        apply simp
        apply (rule ext)
        by auto
    next
      case (Plus a21 a22)
      then show ?case
        apply (case_tac "a11 = a12")
         apply (case_tac "a21 = a22")
          apply simp
          apply (case_tac "a22 = a12")
           apply simp
           apply (rule ext)
           apply auto[1]
          apply simp
        apply (rule ext)
          apply auto[1]
         apply simp
        apply (case_tac "a12 = a22")
        apply simp
        apply (rule ext)
        apply auto[1]
        apply simp
        apply (rule ext)
         apply auto[1]
         apply (case_tac "a21 = a22")
         apply simp
         apply (case_tac "a22 = a12")
          apply simp
          apply (rule ext)
          apply auto[1]
        apply simp
        apply (rule ext)
         apply auto[1]
        apply simp
        apply (case_tac "a22 = a12")
        apply simp
        apply (case_tac "a21 = a11")
        apply simp
          apply (rule ext)
          apply auto[1]
        apply simp
        apply (rule ext)
        apply auto[1]
        apply simp
        apply (case_tac "a22 = a11")
        apply simp
        apply (case_tac "a21 = a12")
        apply simp
        apply (rule ext)
        apply auto[1]
        apply simp
         apply (rule ext)
         apply auto[1]
        apply simp
        apply (rule ext)
        by auto
    next
      case (Minus a21 a22)
      then show ?case
        apply (case_tac "a11 = a12")
         apply simp
         apply (rule ext)
         apply auto[1]
        apply simp
        apply (rule ext)
        by auto
    qed
  next
    case (Minus a11 a12)
    then show ?case
    proof(induct a2)
      case (L x)
      then show ?case
        by simp
    next
      case (V x)
      then show ?case
        apply simp
        apply (rule ext)
        by auto
    next
      case (Plus a21 a22)
      then show ?case
        apply (case_tac "a21 = a22")
         apply simp
         apply (rule ext)
         apply auto[1]
        apply simp
        apply (rule ext)
        by auto
    next
      case (Minus a21 a22)
      then show ?case
        apply simp
        apply (case_tac "a21 = a11")
         apply simp
         apply (case_tac "a22 = a12")
          apply simp
          apply (rule ext)
          apply simp
         apply simp
        apply (rule ext)
         apply auto[1]
        apply simp
        apply (rule ext)
        by auto
    qed
  qed
next
case (Gt a1 a2)
  then show ?case
  proof(induct a1)
    case (L x)
    then show ?case
    proof(induct a2)
      case (L v)
      then show ?case
        by simp
    next
      case (V v)
      then show ?case
        by simp
    next
      case (Plus a21 a22)
      then show ?case
        by simp
    next
      case (Minus a21 a22)
      then show ?case
        by simp
    qed
  next
    case (V x)
    then show ?case
    proof(induct a2)
      case (L x)
      then show ?case
        by simp
    next
      case (V v)
      then show ?case
        by simp
    next
      case (Plus a21 a22)
      then show ?case
        by simp
    next
      case (Minus a21 a22)
      then show ?case
        by simp
    qed
  next
    case (Plus a11 a12)
    then show ?case
    proof(induct a2)
      case (L x)
      then show ?case
        by simp
    next
      case (V x)
      then show ?case
        by simp
    next
      case (Plus a21 a22)
      then show ?case
        apply (case_tac "a11 = a12")
         apply (case_tac "a21 = a22")
          apply simp
         apply simp
        apply (case_tac "a12 = a21")
          apply simp
          apply (rule ext)
          apply simp
         apply simp
         apply (rule ext)
         apply simp
        apply (case_tac "a21 = a22")
         apply simp
         apply (case_tac "a11 = a22")
          apply simp
          apply (rule ext)
          apply simp
         apply simp
         apply (rule ext)
         apply simp
        apply simp
        apply (case_tac "a11 = a21")
         apply simp
         apply clarify
         apply (rule ext)
         apply simp
        apply simp
        apply (case_tac "a11 = a22")
         apply simp
         apply (case_tac "a12 = a21")
          apply simp
        apply (rule ext)
        apply simp
        apply clarify
          apply (simp add: fimage_funion)
          apply (simp add: comp_def make_gt_twice)
          apply auto[1]
         apply simp
         apply (rule ext)
         apply simp
        apply simp
        apply (rule ext)
        by simp
    next
      case (Minus a21 a22)
      then show ?case
        by simp
    qed
  next
    case (Minus a11 a12)
    then show ?case
    proof(induct a2)
      case (L x)
      then show ?case by simp
    next
      case (V x)
      then show ?case by simp
    next
      case (Plus a21 a22)
      then show ?case by simp
    next
      case (Minus a21 a22)
      then show ?case
        apply simp
        apply (case_tac "a11 = a21")
        apply simp
         apply clarify
         apply (rule ext)
         apply simp
        apply simp
        apply (rule ext)
        by simp
    qed
  qed
next
case (Nor G1 G2)
  then show ?case
    apply simp
    apply (rule ext)
    sorry
next
  case (Null x)
  then show ?case
    by simp
qed

lemma medial_medial: "medial (medial c t) t = medial c t"
  apply (simp add: medial_def)
  by (simp add: aux)

lemma anterior_subset_medial: "c r |\<subseteq>| (medial c G r)"
proof(induct G)
  case Nil
  then show ?case
    by (simp add: medial_def)
next
  case (Cons a G)
  then show ?case
    by (simp add: medial_def)
qed

lemma apply_updates: "\<forall>r. fBall (medial c G r) (\<lambda>c. cval c r s = true) \<Longrightarrow>
       \<not> constrains_an_input r \<Longrightarrow>
       fBall (Contexts.apply_updates (medial c G) (medial c G) U r) (\<lambda>c. cval c r i = true) \<Longrightarrow>
       Contexts.apply_updates (medial c G) c U r \<noteq> {|Undef|} \<Longrightarrow>
       x |\<in>| Contexts.apply_updates (medial c G) c U r \<Longrightarrow> cval x r i = true"
proof(induct U)
  case Nil
  then show ?case
    apply simp
    using anterior_subset_medial
    by blast
next
  case (Cons a U)
  then show ?case
    apply simp
    apply (case_tac a)
    apply simp
    apply (case_tac b)
       apply simp
       apply (case_tac "r = V aa")
        apply simp+
       apply (case_tac "r = V aa")
       apply auto[1]
      apply simp+
     apply (case_tac "r = V aa")
      apply simp+
     apply (case_tac "r = V aa")
    by auto
qed

(* If we can prove that medial (medial c t) t = medial t which it really should do *)
lemma "subsumes c t t"
  apply (simp add: subsumes_def medial_medial)
  apply (simp add: posterior_def medial_medial)
  apply (case_tac "consistent (medial c (Guard t))")
   apply (simp add: Let_def)
   defer
   apply simp
  apply (simp add: consistent_def remove_input_constraints_def)
  apply clarify
  using apply_updates by blast
end