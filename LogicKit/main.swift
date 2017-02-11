//
//  main.swift
//  LogicKit
//
//  Created by Dimitri Racordon on 07.02.17.
//  Copyright © 2017 University of Geneva. All rights reserved.
//

let x = Variable(name: "x")
let y = Variable(name: "y")


//let g = x === y && fresh { z in (x === z || x === y) && z === Value(4) }
//let stream = g(State())
//
//
//for substitution in stream.prefix(5) {
//    for (variable, value) in substitution.reified() {
//        print(variable.name, value)
//    }
//
//    print(" ")
//}


struct Polygon: Superterm {

    let sides: Term

    func equals(_ other: Term) -> Bool {
        if let rhs = other as? Polygon {
            return self.sides.equals(rhs.sides)
        }
        return false
    }

    static func build(fromProperties properties: [(label: String?, value: Any)]) -> Polygon {
        guard let sides = properties.first(where: { $0.label == "sides" })?.value as? Term else {
            fatalError("missing or invalid property 'sides'")
        }
        return Polygon.init(sides: sides)
    }

}


// let program = y === Polygon(sides: x) && (x === Value(4) || x === Value(5))
let program = y === Polygon(sides: x) && x === Value(4)
let ss = program(State())

for substitution in ss.prefix(5) {
    for (variable, value) in substitution.reified() {
        print(variable.name, value)
    }

    print(" ")
}
