//
//  main.swift
//  LogicKit
//
//  Created by Dimitri Racordon on 07.02.17.
//  Copyright © 2017 University of Geneva. All rights reserved.
//

let g0 = Variable(name: "y") === Variable(name: "x")
let g1 = Variable(name: "x") === Value(4) && Variable(name: "y") === Variable(name: "x")
let g2 = g0 || g1



let s = g2(State())
switch s {
case .mature(head: let h, next: let n):
    for (variable, value) in h.substitution.reified() {
        print(variable.name, value)
    }
default:
    break
}
