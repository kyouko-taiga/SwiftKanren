//
//  main.swift
//  LogicKit
//
//  Created by Dimitri Racordon on 07.02.17.
//  Copyright © 2017 University of Geneva. All rights reserved.
//

let x = Variable(name: "x")
let y = Variable(name: "y")


let g = x === y && fresh { z in (x === z || x === y) && z === Value(4) }
let stream = g(State())


for substitution in stream.prefix(5) {
    for (variable, value) in substitution.reified() {
        print(variable.name, value)
    }

    print(" ")
}
