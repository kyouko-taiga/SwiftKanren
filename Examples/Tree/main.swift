//
//  A SwiftKanren usage example that showcases the use of maps.
//
//  Created by Dimitri Racordon on 16.03.17.
//  Copyright © 2017 University of Geneva. All rights reserved.
//

import SwiftKanren


// First, we define the natural numbers with some operations.

let zero = Value(0)

func succ(_ n: Term) -> Map {
    return ["succ": n]
}

func add(_ lhs: Term, _ rhs: Term, _ result: Term) -> Goal {
    return (lhs ≡ zero) && (rhs ≡ result) ||
           delayed(fresh { x in (lhs ≡ succ(x)) && add(x, succ(rhs), result) })
}

func diff(_ lhs: Term, _ rhs: Term, _ result: Term) -> Goal {
    return (lhs ≡ rhs) && (result ≡ zero) ||
           (lhs ≡ zero) && (rhs ≡ result) ||
           (rhs ≡ zero) && (lhs ≡ result) ||
           delayed(fresh { x in fresh { y in
               (lhs ≡ succ(x)) && (lhs ≡ succ(y)) && diff(x, y, result)
           }})
}

// Then, we define the binary trees with some operations.

func leaf(_ value: Term) -> Map {
    return ["leaf": value]
}

func cons(_ left: Term, _ right: Term) -> Map {
    return ["left": left, "right": right]
}

func nodeCount(of tree: Term, is result: Term) -> Goal {
    return fresh { x in (tree ≡ leaf(x)) && (result ≡ succ(zero)) } ||
           delayed(fresh { x in fresh { y in fresh { i in fresh { j in
               (tree ≡ cons(x, y)) &&
               nodeCount(of: x, is: i) && nodeCount(of: y, is: j) &&
               add(i, j, result)
           }}}})
}

func isBalanced(_ tree: Term) -> Goal {
    return nodeCount(of: tree, is: succ(zero)) ||
           delayed(fresh { x in fresh { y in fresh { i in fresh { j in
               (tree ≡ cons(x, y)) &&
               nodeCount(of: x, is: i) && nodeCount(of: y, is: j) &&
               (diff(i, j, zero) || diff(i, j, succ(zero)))
           }}}})
}

func isContained(_ value: Term, in tree: Term) -> Goal {
    return (tree ≡ leaf(value)) ||
           delayed(fresh { x in fresh { y in
               (tree ≡ cons(x, y)) &&
               (isContained(value, in: x) || isContained(value, in: y))
           }})
}

// Now we can ask the list of all balanced trees that contains values 0, 1, 2.
// Note that we only display the first 10 results.

let x = Variable(named: "x")
let y = Variable(named: "y")

let three = succ(succ(succ(zero)))
let system = nodeCount(of: x, is: three) &&
             isBalanced(x) &&
             isContained(zero, in: x) &&
             isContained(succ(zero), in: x) &&
             isContained(succ(succ(zero)), in: x)

for solution in solve(system).prefix(10) {
    let results = solution.reified()
    print(results[x])
}
