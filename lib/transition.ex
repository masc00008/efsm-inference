defmodule Transition do
  def matchTransition(transitionTable, ref, label, arity, args, registers) do
    details = TransitionTable.get(transitionTable, ref)
    details["label"] == label && details["arity"] == arity && applyGuards(details["guards"], registers, args)
  end

  defp applyGuards(guards, registers, args) do
    Enum.all?(guards, fn(g) -> Guard.applyGuard(g, Map.merge(registers, args)) end)
  end

  def applyTransition(details, registers, args) do
    outputs = applyOutputs(details["outputs"], registers, args)
    updated = applyUpdates(details["updates"], registers, args)
    {outputs, updated}
  end

  defp applyOutput(output, store) do
    if Map.has_key?(store, output) do
      store[output]
    else
      output
    end
  end

  defp applyOutputs([], _registers, _args) do
    %{}
  end
  defp applyOutputs([h|t], registers, args) do
    store = Map.merge(registers, args)
    {key, ":=", value} = h
    Map.put(applyOutputs(t, registers, args), key, applyOutput(value, store))
  end

  def applyUpdates([], registers, _args) do
    registers
  end
  def applyUpdates([h|t], registers, args) do
    applyUpdates(t, Update.applyUpdate(h, registers, args), args)
  end

  defp transition_regex() do
    label = "(?<label>\\w+)"
    arity = "(:(?<arity>\\d+){0,1})"
    guard = "(~{0,1}((\\w+)|('\\w+'))(=|>|(>=)|(<=)|(!=))((\\w+)|('\\w+')))"
    guard = guard <> "((\\|" <> guard <> ")|" <> "(\\&" <> guard <> "))*"
    guards = "(\\[(?<guards>("<>guard<>"(,"<>guard<>")*"<>"))\\]){0,1}"
    output = "o\\d:=((\\w+)|('\\w+'))"
    outputs = "(?<outputs>("<>output<>"(,"<>output<>")*"<>")){0,1}"
    aexp = "(\\d+|\\w+|'\\w+')"
    aexp = aexp <> "(" <> "(\\+|-|\\*|\/)" <> aexp <> ")*"
    update = "r\\d:=" <> aexp
    update = update <> "((-" <> update <> ")|" <> "(\\+" <> update <> "))*"
    updates = "(\\[(?<updates>("<>update<>"(,"<>update<>")*"<>"))\\]){0,1}"
    rhs = "("<>"\\/"<>outputs<>updates<>"){0,1}"
    {:ok, transition} = Regex.compile(label<>arity<>guards<>rhs)
    transition
  end

  def parseTransition(transitionString, transitionTable) do
    parts = Regex.named_captures(transition_regex(), transitionString)
    parts = if parts["arity"] == "" do
      Map.put(parts, "arity", 0)
    else
      {arity, _} = Integer.parse(parts["arity"])
        Map.put(parts, "arity", arity)
    end
    parts = if parts["guards"] == "" do
      Map.put(parts, "guards", [])
    else
      guards = String.split(parts["guards"], ",")
      Map.put(parts, "guards", Enum.map(guards, fn x -> Guard.parseGuard(x) end))
    end
    parts = if parts["outputs"] == "" do
      Map.put(parts, "outputs", [])
    else
      outputs = String.split(parts["outputs"], ",")
      Map.put(parts, "outputs", Enum.map(outputs, fn x -> List.to_tuple(Regex.split(~r{(:=)} , x, include_captures: true)) end))
    end
    parts = if parts["updates"] == "" do
      Map.put(parts, "updates", [])
    else
      updates = String.split(parts["updates"], ",")
      Map.put(parts, "updates", Enum.map(updates, fn x -> Update.parseUpdate(x)  end))
    end
    ref = make_ref()
    TransitionTable.put(transitionTable, ref, parts)
    ref
  end

  def compatible(transitionTable, ref1, ref2) do
    details1 = TransitionTable.get(transitionTable,ref1)
    details2 = TransitionTable.get(transitionTable,ref2)
    if (details1["label"] == details2["label"] &&
        Guard.compatible(details1["guards"], details2["guards"])) do
      true
    else
      false
    end
  end

  def to_json(transitionTable, ref) do
    details = TransitionTable.get(transitionTable, ref)
    str = details["label"]<>":"<>Integer.to_string(details["arity"])
    str = str <> if details["guards"] == [] do
      ""
    else
      list_to_string(details["guards"], "[", "]")
    end
    str = str <> if details["outputs"] == [] and details["updates"] == [] do
      ""
    else
      "/"<>list_to_string(details["outputs"])<>list_to_string(details["updates"], "[", "]")
    end
    str
  end

    defp list_to_string(lst, pre \\ "", post \\ "") do
    str = Enum.join(Enum.map(lst, fn tuple -> Enum.join(Tuple.to_list(tuple)) end), ",")
    if str == "" do
      ""
    else
      pre <> str <> post
    end
  end
end
