import LogicKit


let x = Variable(named: "x")
let y = Variable(named: "y")

let program =   (x ≡ y) &&
                fresh{ z in (x ≡ z) && (z ≡ Value(0) || z ≡ Value(1)) }

let solutions = solve(program)
for solution in solutions {
    print("x = \(solution[x]), y = \(solution[y])")
}
