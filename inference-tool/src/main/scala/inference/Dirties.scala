import com.microsoft.z3
import exceptions.SatisfiabilityUnknownException
import java.io._
import scala.util.Random
import sys.process._

//for last line of file deletion
import scala.io.Source


object Dirties {
  type iEFSM = FSet.fset[(Nat.nat, ((Nat.nat, Nat.nat), Transition.transition_ext[Unit]))]

  def R(i: BigInt): VName.vname = {
    VName.R(Nat.Nata(i))
  }
  def I(i: BigInt): VName.vname = {
    VName.I(Nat.Nata(i))
  }

  def writeDot(e: FSet.fset[(
                               ((Nat.nat, Nat.nat),
                                 Transition.transition_ext[Unit]))], f: String): Unit = {
                                   val pw = new PrintWriter(new File(f))
                                   pw.write(EFSM_Dot.efsm2dot(e))
                                   pw.close
                                 }

  def writeiDot(e: FSet.fset[(Nat.nat,
                               ((Nat.nat, Nat.nat),
                                 Transition.transition_ext[Unit]))], f: String): Unit = {
                                   val pw = new PrintWriter(new File(f))
                                   pw.write(EFSM_Dot.iefsm2dot(e))
                                   pw.close
                                 }

  type Set[A] = scala.collection.immutable.Set[A]

  def valueOf(i: Int.int): Int =  i match {
    case Int.int_of_integer(i1) => i1.intValue()
  }

  def valueOf(i: Nat.nat): Int =  i match {
    case Nat.Nata(i1) => i1.intValue()
  }

  def toZ3(v: Value.value, ctx: z3.Context): z3.Expr = v match {
    case Value.Numa(n) => ctx.mkInt(valueOf(n))
    case Value.Str(s) => ctx.mkString(s)
  }

  def toZ3(v: VName.vname, ctx: z3.Context, datatype: z3.Sort): z3.Expr = v match {
    case VName.I(n) => ctx.mkConst("i"+valueOf(n), datatype)
    case VName.R(n) => ctx.mkConst("r"+valueOf(n), datatype)
  }

  def toZ3(a: AExp.aexp, ctx: z3.Context, types: FinFun.finfun[VName.vname, Type_Inference.typea]): z3.Expr =  a match {
    case AExp.L(v) => toZ3(v, ctx)
    case AExp.V(v) => {
      FinFun.finfun_apply(types, v) match {
        case Type_Inference.NUM()     => toZ3(v, ctx, ctx.mkIntSort())
        case Type_Inference.STRING()  => toZ3(v, ctx, ctx.mkStringSort())
        case Type_Inference.UNBOUND() => toZ3(v, ctx, ctx.mkUninterpretedSort("UNBOUND"))
        case Type_Inference.NULL()    => toZ3(v, ctx, ctx.mkUninterpretedSort("NULL"))
      }
    }
    case AExp.Plus(a1, a2) => ctx.mkAdd(toZ3(a1, ctx, types).asInstanceOf[z3.ArithExpr], toZ3(a2, ctx, types).asInstanceOf[z3.ArithExpr])
    case AExp.Minus(a1, a2) => ctx.mkSub(toZ3(a1, ctx, types).asInstanceOf[z3.ArithExpr],toZ3(a2, ctx, types).asInstanceOf[z3.ArithExpr])
  }

  def toZ3(g: GExp.gexp, ctx: z3.Context, variables: FinFun.finfun[VName.vname, Type_Inference.typea]): z3.BoolExpr =  g match {
    case GExp.Bc(a) => ctx.mkBool(a)
    case GExp.Eq(a1, a2) => ctx.mkEq(toZ3(a1, ctx, variables), toZ3(a2, ctx, variables))
    case GExp.Gt(a1, a2) => ctx.mkGt(toZ3(a1, ctx, variables).asInstanceOf[z3.ArithExpr], toZ3(a2, ctx, variables).asInstanceOf[z3.ArithExpr])
    case GExp.Nor(g1, g2) => ctx.mkNot(ctx.mkOr(toZ3(g1, ctx, variables), toZ3(g2, ctx, variables)))
    case GExp.Null(v) => null
  }

  def satisfiable(g: GExp.gexp): Boolean = {
    val maybe_types = Type_Inference.infer_types(g)
    maybe_types match {
      case None => false
      case Some(types) => {
        // println(FinFun.finfun_apply(types, I(1)))
        val ctx = new z3.Context
        val solver = ctx.mkSimpleSolver()
        solver.add(toZ3(g, ctx, types))
        // print(solver)
        solver.check() match {
          case z3.Status.SATISFIABLE => true
          case z3.Status.UNSATISFIABLE => false
          case z3.Status.UNKNOWN => throw new SatisfiabilityUnknownException(g.toString())
        }
      }
    }
  }

  def randomMember[A](f: FSet.fset[A]): Option[A] = f match {
    case FSet.Abs_fset(s) => s match {
      case Set.seta(l) => {
        if (l == List()) {
          None
        }
        else {
          Some(Random.shuffle(l).head)
        }
      }
    }
  }

  def addLTL(f: String, e: String) = {
    val lines = Source.fromFile(f).getLines().toList.dropRight(1)

    val pw = new PrintWriter(new File(f))

    (lines :+ (e + "\nEND")).foreach(pw.println)

    pw.close()
  }

  def initiallyUndefinedContextCheck(e: iEFSM, r: Nat.nat, s: Nat.nat): Boolean = {
    // val f = "intermediate_"+System.currentTimeMillis()
    // TypeConversion.efsmToSALTranslator(Inference.tm(e), f)
    //
    // addLTL("salfiles/" + f + ".sal", s"  initiallyUndefined: THEOREM MichaelsEFSM |- G(cfstate = State_${valueOf(s)} => r_${valueOf(r)} = ValueOption ! None);")
    //
    // val output = Seq("bash", "-c", "cd salfiles; sal-smc --assertion='" + f + "{100}!initiallyUndefined'").!!
    // if (output.toString != "proved.\n") {
    //   print(output)
    // }
    // return (output.toString == "proved.\n")
    return true
  }

  def salValue(v: Value.value): String = v match {
    case Value.Str(s) => s"STR(String_$s)"
    case Value.Numa(n) => s"NUM(${valueOf(n)})"
  }

  def generaliseOutputContextCheck(e: iEFSM, r: Nat.nat, v: Value.value, s: Nat.nat): Boolean = {
    val f = "intermediate_"+System.currentTimeMillis()
    TypeConversion.efsmToSALTranslator(Inference.tm(e), f)

    addLTL("salfiles/" + f + ".sal", s"  generaliseOutput: THEOREM MichaelsEFSM |- G(cfstate = State_${valueOf(s)} => r_${valueOf(r)} = Some(${salValue(v)}));")

    val output = Seq("bash", "-c", "cd salfiles; sal-smc --assertion='" + f + "{100}!generaliseOutput'").!!
    println("sal-smc --assertion='" + f + "{100}!generaliseOutput'")
    if (output.toString != "proved.\n") {
      print(output)
    }
    return (output.toString == "proved.\n")
  }

  def scalaDirectlySubsumes(a: iEFSM,
                            b: iEFSM,
                            s: Nat.nat,
                            s_prime: Nat.nat,
                            t1: Transition.transition_ext[Unit],
                            t2: Transition.transition_ext[Unit]): Boolean = {
                              if (HOL.equal(t1, t2)) {
                                return true
                              }
                              println(f"\nDoes ${PrettyPrinter.transitionToString(t1)} directly subsume ${PrettyPrinter.transitionToString(t2)}? y/n")
                              if (Code_Generation.always_different_outputs(Transition.Outputs(t1), Transition.Outputs(t2))) {
                                println("n")
                                return false
                              }
                              else if (Store_Reuse_Subsumption.drop_guard_add_update_direct_subsumption(t1, t2, b, s_prime)) {
                                // This needs modifying to model check but it should be OK for now
                                println("y")
                                return true
                              }
                              else if (Store_Reuse_Subsumption.drop_guard_add_update_direct_subsumption(t2, t1, b, s_prime)) {
                                // This needs modifying to model check but it should be OK for now
                                println("n")
                                return false
                              }
                              else if (Store_Reuse_Subsumption.generalise_output_direct_subsumption(t1, t2, b, s_prime)) {
                                // This needs modifying to model check but it should be OK for now
                                println("y")
                                return true
                              }
                              else if (Store_Reuse_Subsumption.generalise_output_direct_subsumption(t2, t1, b, s_prime)) {
                                // This needs modifying to model check but it should be OK for now
                                println("n")
                                return false
                              }
                              else {
                                val subsumes = readLine("") == "y"
                                subsumes
                              }
                            }
  }
