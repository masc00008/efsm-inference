import com.microsoft.z3
import exceptions.SatisfiabilityUnknownException
import java.io._
import scala.io.Source
import scala.util.Random
import sys.process._

import TypeConversion.natToInt;
import TypeConversion.intToInt;

object Dirties {
  type iEFSM = FSet.fset[(Nat.nat, ((Nat.nat, Nat.nat), Transition.transition_ext[Unit]))]

  type Set[A] = scala.collection.immutable.Set[A]

  def toZ3(v: Value.value, ctx: z3.Context): z3.Expr = v match {
    case Value.Numa(n) => ctx.mkInt(intToInt(n))
    case Value.Str(s) => ctx.mkString(s)
  }

  def toZ3(v: VName.vname, ctx: z3.Context, datatype: z3.Sort): z3.Expr = v match {
    case VName.I(n) => ctx.mkConst("i"+natToInt(n), datatype)
    case VName.R(n) => ctx.mkConst("r"+natToInt(n), datatype)
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

  var sat_memo = Map[GExp.gexp, Boolean]()

  def satisfiable(g: GExp.gexp): Boolean = {
    if (sat_memo isDefinedAt g) {
      return sat_memo(g)
    }
    else {
      val maybe_types = Type_Inference.infer_types(g)
      maybe_types match {
        case None => false
        case Some(types) => {
          // println(FinFun.finfun_apply(types, I(1)))
          val ctx = new z3.Context
          val solver = ctx.mkSimpleSolver()
          solver.add(toZ3(g, ctx, types))
          // print(solver)
          val satisfiable = solver.check()
          ctx.close()
          satisfiable match {
            case z3.Status.SATISFIABLE => {
              sat_memo += (g -> true)
              true
            }
            case z3.Status.UNSATISFIABLE => {
              sat_memo += (g -> false)
              false
            }
            case z3.Status.UNKNOWN => throw new SatisfiabilityUnknownException(g.toString())
          }
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
    val f = "intermediate_"+System.currentTimeMillis()
    TypeConversion.efsmToSALTranslator(Inference.tm(e), f)

    addLTL("salfiles/" + f + ".sal", s"  initiallyUndefined: THEOREM MichaelsEFSM |- G(cfstate = State_${natToInt(s)} => r_${natToInt(r)} = value_option ! None);")

    val output = Seq("bash", "-c", "cd salfiles; sal-smc --assertion='" + f + "{100}!initiallyUndefined'").!!
    if (output.toString != "proved.\n") {
      print(output)
    }
    return (output.toString == "proved.\n")
  }

  def salValue(v: Value.value): String = v match {
    case Value.Str(s) => s"STR(String_$s)"
    case Value.Numa(n) => s"NUM(${intToInt(n)})"
  }

  def generaliseOutputContextCheck(l: String, ePrime: iEFSM, e: iEFSM, r: Nat.nat, v: Value.value, s_old: Nat.nat, s_new: Nat.nat): Boolean = {
    val f_old = "orig_"+System.currentTimeMillis()
    TypeConversion.efsmToSALTranslator(Inference.tm(e), f_old)
    val inxLabel = Code_Generation.input_updates_register(ePrime)
    addLTL("salfiles/" + f_old + s".sal", s"  inputValue: THEOREM MichaelsEFSM |-\n" +
      s"    U(cfstate /= NULL_STATE, cfstate=State_${natToInt(s_old)}) =>\n"+
      s"    U(label = ${inxLabel._2} => I(1) = ${salValue(v)}, X(cfstate = NULL_STATE));")

    val f_new = "intermediate_"+System.currentTimeMillis()
    TypeConversion.efsmToSALTranslator(Inference.tm(ePrime), f_new)
    addLTL("salfiles/" + f_new + ".sal", s"  generaliseOutput: THEOREM MichaelsEFSM |-\n"+
      s"    U(cfstate /= NULL_STATE, cfstate = State_${natToInt(s_new)}) =>\n"+
      s"    U(label = select => I(${natToInt(inxLabel._1)}) = ${salValue(v)}, cfstate = NULL_STATE) =>\n"+
      s"    U(cfstate = State_${natToInt(s_new)} => r_1 = Some(${salValue(v)}), cfstate=NULL_STATE);")


    println(s"sal-smc --assertion='${f_old}{100}!inputValue'")
    val output1 = Seq("bash", "-c", s"cd salfiles; sal-smc --assertion='${f_old}{100}!inputValue'").!!
    println(output1)

    println(s"sal-smc --assertion='${f_new}{100}!generaliseOutput'")
    val output2 = Seq("bash", "-c", s"cd salfiles; sal-smc --assertion='${f_new}{100}!generaliseOutput'").!!
    println(output2)

    return (output1.toString == "proved.\n" && output2.toString == "proved.\n")
  }

  def scalaDirectlySubsumes(a: iEFSM,
                            b: iEFSM,
                            s: Nat.nat,
                            s_prime: Nat.nat,
                            t1: Transition.transition_ext[Unit],
                            t2: Transition.transition_ext[Unit]): Boolean = {
                              if (Store_Reuse_Subsumption.drop_guard_add_update_direct_subsumption(t2, t1, b, s_prime)) {
                                // println("n")
                                return false
                              }
                              if (Store_Reuse_Subsumption.generalise_output_direct_subsumption(t2, t1, b, a, s, s_prime)) {
                                // println("n")
                                return false
                              }
                              else {
                                println(s"Does ${PrettyPrinter.transitionToString(t1)} directly subsume ${PrettyPrinter.transitionToString(t2)}? (y/N)")
                                val subsumes = readLine("") == "y"
                                subsumes
                              }
                            }
  }
