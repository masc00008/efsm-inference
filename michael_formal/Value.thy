theory Value
imports "Show.Show_Instances"
begin
datatype "value" = Num int | Str String.literal

instantiation String.literal :: "show" begin
definition shows_prec_literal :: "nat \<Rightarrow> String.literal \<Rightarrow> char list \<Rightarrow> char list" where
  "shows_prec_literal n s l = String.explode s @ l"

fun shows_list_literal :: "String.literal list \<Rightarrow> char list \<Rightarrow> char list" where
  "shows_list_literal [] l = l" |
  "shows_list_literal [h] l = shows_prec 0 h l" |
  "shows_list_literal (h#t) l = (shows_prec 0 h '''')@shows_list_literal t l"

instance proof
  fix x :: String.literal
  fix p r s
  show "shows_prec p x (r @ s) = shows_prec p x r @ s"
    using shows_prec_literal_def by auto
next
  fix xs :: "String.literal list"
  fix r s
  show "shows_list xs (r @ s) = shows_list xs r @ s"
  proof (induct xs)
    case Nil
    then show ?case
      by simp
  next
    case (Cons x xs)
    then show ?case
    proof (induct xs)
      case Nil
      then show ?case
        using shows_prec_literal_def by auto
    next
      case (Cons a xs)
      then show ?case
        by simp
    qed
  qed
qed
end

instantiation "value" :: "show" begin
fun shows_prec_value :: "nat \<Rightarrow> value \<Rightarrow> char list \<Rightarrow> char list" where
  "shows_prec_value n (Num v) l =  shows_prec n v l" |
  "shows_prec_value n (Str v) l = ''\"''@shows_prec n v ''''@''\"''@l"

fun shows_list_value :: "value list \<Rightarrow> char list \<Rightarrow> char list" where
  "shows_list_value [] l = l" |
  "shows_list_value [u] l = shows_prec 0 u l" |
  "shows_list_value (h#t) l = (shows_prec 0 h '''')@'',''@(shows_list_value t l)"

(* apply standard = proof *)
(* or just do the types in "fix" *)
instance proof
  fix p::nat
  fix x::"value"
  fix r s
  show "shows_prec p x (r @ s) = shows_prec p x r @ s"
  apply (case_tac x)
   apply (simp add: shows_prec_append)
  by (simp add: shows_prec_append)
next
  fix p::nat
  fix x::"value"
  fix xs :: "value list"
  fix r s
  show "shows_list xs (r @ s) = shows_list xs r @ s"
  proof (induction xs)
    case Nil
    then show ?case by simp
  next
    case (Cons a xs)
    then show ?case
    proof (induct xs)
      case Nil
      then show ?case
        apply (simp add: shows_prec_list_def)
        apply (cases a)
         apply (simp add: shows_prec_int_def shows_string_def shows_prec_nat_def showsp_int_def)
        apply (simp add: showsp_nat_append)
        by (simp)
    next
      case (Cons a xs)
      then show ?case by simp
    qed
  qed
qed
end

lemma show_num: "show (Num x1) = show x1"
proof (cases x1)
  case (nonneg n)
  then show ?thesis
      by (simp add: shows_prec_int_def shows_string_def)
next
  case (neg n)
  then show ?thesis
      by (simp add: shows_prec_int_def shows_string_def)
  qed

lemma show_int_deterministic: "\<forall>(x::int) (y::int). show x = show y \<longrightarrow> x = y"
  sorry

lemma show_value_deterministic: "show (v1::value) = show (v2::value) \<Longrightarrow> v1 = v2"
proof (induct v1)
  case (Num n)
  then show ?case
  proof (induct v2)
    case (Num x)
    then show ?case
      by (simp add: show_num show_int_deterministic)
  next
    case (Str x)
    then show ?case
      apply simp
      sorry
  qed
next
  case (Str s)
  then show ?case
  proof (induct v2)
    case (Num x)
    then show ?case
      apply (simp add: shows_prec_list_def shows_list_char_def shows_string_def)
      sorry
  next
  case (Str x)
  then show ?case
    sorry
qed
qed
end