theory InferenceTestEFSMs
imports Learn_EFSM
begin

abbreviation "coin_general r \<equiv> \<lparr>Label = STR ''coin'', Arity = 1, Guard = [], Outputs = [Plus (V (R r)) (V (I 1))], Updates = [(R r, Plus (V (R r)) (V (I 1)))]\<rparr>"
abbreviation "vend_initialise \<equiv> \<lparr>Label = STR ''vend'', Arity = 0, Guard = [], Outputs = [L (value.Str STR ''pepsi'')], Updates = [(R 1, L (Num 0))]\<rparr>"
abbreviation "coin50_initialise \<equiv> \<lparr>Label = STR ''coin'', Arity = 1, Guard = [gexp.Eq (V (I 1)) (L (Num 50))], Outputs = [L (Num 100)], Updates = [(R 1, L (Num 0))]\<rparr>"
abbreviation "select_initialise d r  \<equiv> \<lparr>Label = STR ''select'', Arity = 1, Guard = [gexp.Eq (V (I 1)) (L (value.Str d))], Outputs = [], Updates = [(R r, L (Num 0))]\<rparr>"
abbreviation "select_general_initialise \<equiv> \<lparr>Label = STR ''select'', Arity = 1, Guard = [], Outputs = [], Updates = [(R 3, V (I 1)), (R 1, L (Num 0))]\<rparr>"
abbreviation "general_vend r \<equiv> \<lparr>Label = STR ''vend'', Arity = 0, Guard = [], Outputs = [V (R r)], Updates = []\<rparr>"

definition "first_branch = {|(0, (0, 1), select coke), (1, (1, 2), coin 50 50), (2, (2, 3), coin 50 100), (3, (3, 4), vend coke)|}"
definition "merge_1_2 =    {|(0, (0, 1), select coke), (1, (1, 1), coin 50 50), (2, (1, 3), coin 50 100), (3, (3, 4), vend coke)|}"
definition "merge_3_1 =    {|(0, (0, 1), select coke), (1, (1, 1), coin 50 50), (2, (1, 1), coin 50 100), (3, (1, 4), vend coke)|}"
definition "first_branch_initialise = {|(0, (0, 1), select_initialise coke 1), (1, (1, 1), coin_general 1), (2, (1, 1), coin_general 1), (3, (1, 4), vend coke)|}"
definition "completed_first_branch = {|(3, (1, 4), vend coke), (0, (0, 1), select_initialise coke 1), (2, (1, 1), coin_general 1)|}"

definition "third_branch = {|(0, (0, 1), select_initialise coke 1), (1, (0, 5), select pepsi),              (2, (1, 1), coin_general 1), (3, (1, 4), vend coke), (4, (5, 6), coin 50 50),     (5, (6, 7), coin 50 100),    (6, (7, 8), vend pepsi)|}"
definition    "merge_5_6 = {|(0, (0, 1), select_initialise coke 1), (1, (0, 5), select pepsi),              (2, (1, 1), coin_general 1), (3, (1, 4), vend coke), (4, (5, 5), coin 50 50),     (5, (5, 7), coin 50 100),    (6, (7, 8), vend pepsi)|}"
definition    "merge_7_5 = {|(0, (0, 1), select_initialise coke 1), (1, (0, 5), select pepsi),              (2, (1, 1), coin_general 1), (3, (1, 4), vend coke), (4, (5, 5), coin 50 50),     (5, (5, 5), coin 50 100),    (6, (5, 8), vend pepsi)|}"
definition  "h_merge_7_5 = {|(0, (0, 1), select_initialise coke 1), (1, (0, 5), select_initialise pepsi 2), (2, (1, 1), coin_general 1), (3, (1, 4), vend coke), (4, (5, 5), coin_general 2), (5, (5, 5), coin_general 2), (6, (5, 8), vend pepsi)|}"
definition     "one_coin = {|(0, (0, 1), select_initialise coke 1), (1, (0, 5), select_initialise pepsi 2), (2, (1, 1), coin_general 1), (3, (1, 4), vend coke), (5, (5, 5), coin_general 2), (6, (5, 8), vend pepsi)|}"

definition "merge_1_5 = {|(0, (0, 1), select_initialise coke 1), (1, (0, 1), select_initialise pepsi 2), (2, (1, 1), coin_general 1), (3, (1, 4), vend coke), (5, (1, 1), coin_general 2), (6, (1, 8), vend pepsi)|}"
definition "merge_8_4 = {|(0, (0, 1), select_initialise coke 1), (1, (0, 1), select_initialise pepsi 2), (2, (1, 1), coin_general 1), (3, (1, 4), vend coke), (5, (1, 1), coin_general 2), (6, (1, 4), vend pepsi)|}"
definition "h_merge_8_4 = {|(0, (0, 1), select_general_initialise), (1, (0, 1), select_initialise pepsi 2), (2, (1, 1), coin_general 1), (3, (1, 1), coin_general 2), (4, (1, 4), vend pepsi), (5, (1, 4), general_vend 3)|}"
end
