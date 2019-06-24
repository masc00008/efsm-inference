import net.liftweb.json._
import scala.io.Source
import com.microsoft.z3
// PrintWriter
import java.io._
import org.apache.commons.io.FilenameUtils;

object FrontEnd {

  def main(args: Array[String]): Unit = {
    println("=================================================================")

    type Execution = List[(String, (List[Value.value], List[Value.value]))]
    type Log = List[Execution]


    // val filename = "sample-traces/vend1.json"
    val filename = args(0)
    val rawJson = Source.fromFile(filename).getLines.mkString
    val parsed = (parse(rawJson))

    val list = parsed.values.asInstanceOf[List[List[Map[String, Any]]]]

    val coin = list(0)(0)("inputs").asInstanceOf[List[Any]].map(x => TypeConversion.toValue(x))
    val log = list.map(run => run.map(x => TypeConversion.toEventTuple(x)))

    val heuristic = Inference.try_heuristics(List(
      (Same_Register.same_register _).curried,
      (Increment_Reset.insert_increment_2 _).curried,
      Store_Reuse.heuristic_1(log)
    ))

    println("Hello inference!")

    // iterative_learn [] naive_score (iterative_try_heuristics [(λx. insert_increment), (λx. heuristic_1 x)])
    val inferred = Inference.learn(log, (SelectionStrategies.naive_score _).curried, heuristic)

    println("The inferred machine is " +
      (if (Inference.nondeterministic(Inference.toiEFSM(inferred))) "non" else "") + "deterministic")

    val basename = FilenameUtils.getBaseName(filename)

    println("Goodbye inference!")

    TypeConversion.efsmToSALTranslator(inferred, basename)

    for (move <- TypeConversion.fset_to_list(inferred)) {
      println(PrettyPrinter.transitionToString(move._2))

    }

    println("=================================================================")
  }
}
