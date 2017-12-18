//
//  A SwiftKanren usage example that showcases the use of predicates.
//
//  Created by Dimitri Racordon on 12.02.17.
//  Copyright © 2017 University of Geneva. All rights reserved.
//

import SwiftKanren


// First, we create an enumeration to represent the different Pokemon.

enum Pokemon: Term {

    case Bulbasaur, Oddish
    case Charmander, Vulpix
    case Squirtle, Psyduck

    func equals(_ other: Term) -> Bool {
        return (other is Pokemon) && (other as! Pokemon == self)
    }

}

// We then define a set of predicates on the type of the pokemons.

func grass(_ pokemon: Term) -> Goal {
    return  (pokemon === Pokemon.Bulbasaur) ||
            (pokemon === Pokemon.Oddish)
}

func fire(_ pokemon: Term) -> Goal {
    return  (pokemon ≡ Pokemon.Charmander) ||
            (pokemon ≡ Pokemon.Vulpix)
}

func water(_ pokemon: Term) -> Goal {
    return  (pokemon ≡ Pokemon.Squirtle) ||
            (pokemon ≡ Pokemon.Psyduck)
}

// We define another predicate that takes two Pokemon and holds when the first
// is stronger that ther second (solely based on their type).

func stronger(_ lhs: Term, _ rhs: Term) -> Goal {
    return  grass(lhs) && water(rhs) ||
            fire(lhs) && grass(rhs) ||
            grass(lhs) && water(rhs)
}

// We ask for all Pokemon that are stronger than Bulbasaur, according to our
// `stronger` predicate.

let x = Variable(named: "x")
let q = stronger(x, Pokemon.Bulbasaur)

print("Which Pokemon are stronger than Bulbasaur?")
let results = q(State())
for substitution in results {
    for (_, value) in substitution.reified() {
        print("* \(value)")
    }
}
