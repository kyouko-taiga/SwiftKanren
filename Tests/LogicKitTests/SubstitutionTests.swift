//
//  SubstitutionTests.swift
//  LogicKit
//
//  Created by Dimitri Racordon on 12.02.17.
//  Copyright © 2017 University of Geneva. All rights reserved.
//

@testable import LogicKit
import XCTest


class SubstitutionTests: XCTestCase {

    func testExtended() {

        // Note that the internal storage of substitution map is private. As
        // a result, we can't directly observe the effect of extending a map.
        // Instead, we can query their Sequence API, but should remind that
        // the latter also relies on the walk and deep-walk operations.

        var sub = Substitution()
        let x   = Variable(named: "x")
        let y   = Variable(named: "y")
        let z   = Variable(named: "z")

        sub = sub.extended(with: (variable: x, term: Value(0)))
        XCTAssertTrue(sub.contains { ($0 == x) && ($1 as? Value<Int> == Value(0)) })

        sub = sub.extended(with: (variable: y, term: Value(1)))
        XCTAssertTrue(sub.contains { ($0 == x) && ($1 as? Value == Value(0)) })
        XCTAssertTrue(sub.contains { ($0 == y) && ($1 as? Value == Value(1)) })

        sub = sub.extended(with: (variable: z, term: x))
        XCTAssertTrue(sub.contains { ($0 == x) && ($1 as? Value == Value(0)) })
        XCTAssertTrue(sub.contains { ($0 == y) && ($1 as? Value == Value(1)) })

        sub = Substitution().extended(with: (variable: x, term: y))
        XCTAssertTrue(sub.contains { ($0 == x) && ($1 as? Variable == y) })
    }

    func testWalk() {
        var sub = Substitution()
        let x   = Variable(named: "x")
        let y   = Variable(named: "y")
        let z   = Variable(named: "z")

        sub = sub.extended(with: (variable: x, term: Value(0)))
        XCTAssertEqual(sub[x] as? Value, Value(0))

        sub = sub.extended(with: (variable: y, term: Value(1)))
        XCTAssertEqual(sub[x] as? Value, Value(0))
        XCTAssertEqual(sub[y] as? Value, Value(1))

        sub = sub.extended(with: (variable: z, term: x))
        XCTAssertEqual(sub[x] as? Value, Value(0))
        XCTAssertEqual(sub[y] as? Value, Value(1))
        XCTAssertEqual(sub[z] as? Value, Value(0))

        sub = Substitution().extended(with: (variable: x, term: y))
                            .extended(with: (variable: y, term: z))
        XCTAssertEqual(sub[x] as? Variable, z)

        // The subscript (a.k.a. "walk" in kanren) should return the given
        // value as is if it isn't a variable, or if it isn't in the map yet.

        sub = Substitution()
        XCTAssertEqual(sub[z] as? Variable, z)
        XCTAssertEqual(sub[Value(3)] as? Value, Value(3))
    }

    func testUnify() {
        XCTAssertNil(Substitution().unifying(Value(0), Value(1)))

        var sub: Substitution! = nil
        let x = Variable(named: "x")
        let y = Variable(named: "y")

        sub = Substitution().unifying(Value(1), Value(1))
        XCTAssertEqual(sub.map({ _, _ in 0 }).count, 0)

        sub = Substitution().unifying(x, Value(0))
        XCTAssertEqual(sub[x] as? Value, Value(0))
        sub = Substitution().unifying(Value(0), x)
        XCTAssertEqual(sub[x] as? Value, Value(0))

        sub = Substitution().unifying(x, y)
        XCTAssertTrue((sub[x] as? Variable == y) || (sub[y] as? Variable == x))

        sub = Substitution().extended(with: (variable: y, term: Value(0)))
                            .unifying(x, y)
        XCTAssertEqual(sub[x] as? Value, Value(0))

        sub = Substitution().unifying(List.empty, List.empty)
        XCTAssertEqual(sub.map({ _, _ in 0 }).count, 0)

        XCTAssertNil(Substitution().unifying(List.cons(Value(0), List.empty), List.empty))
        XCTAssertNil(Substitution().unifying(List.empty, List.cons(Value(0), List.empty)))

        sub = Substitution().unifying(
            List.cons(Value(0), List.empty), List.cons(Value(0), List.empty))
        XCTAssertEqual(sub.map({ _, _ in 0 }).count, 0)

        sub = Substitution().unifying(
            List.cons(x, List.empty), List.cons(Value(0), List.empty))
        XCTAssertEqual(sub[x] as? Value, Value(0))
    }

    func testReify() {
        var sub: Substitution! = nil
        let x = Variable(named: "x")
        let y = Variable(named: "y")

        sub = Substitution().extended(with: (variable: x, term: Value(0)))
                            .reified()
        XCTAssertEqual(sub[x] as? Value, Value(0))

        sub = Substitution().extended(with: (variable: x, term: Value(0)))
                            .extended(with: (variable: y, term: x))
                            .reified()
        XCTAssertEqual(sub[y] as? Value, Value(0))

        sub = Substitution().extended(with: (variable: x, term: y))
                            .reified()
        XCTAssertTrue(sub[x] is Unassigned)

        let l1 = List.cons(Value(0), List.cons(Value(1), List.empty))
        sub = Substitution().extended(with: (variable: x, term: l1))
                            .extended(with: (variable: y, term: x))
                            .reified()
        XCTAssertTrue(sub[y].equals(l1))

        let l2 = List.cons(y, List.cons(Value(1), List.empty))
        sub = Substitution().extended(with: (variable: x, term: l2))
                            .extended(with: (variable: y, term: Value(0)))
                            .reified()
        XCTAssertTrue(sub[x].equals(List.cons(Value(0), List.cons(Value(1), List.empty))))

        let l3 = List.cons(Value(0), List.cons(y, List.empty))
        sub = Substitution().extended(with: (variable: x, term: l3))
                            .extended(with: (variable: y, term: Value(1)))
                            .reified()
        XCTAssertTrue(sub[x].equals(List.cons(Value(0), List.cons(Value(1), List.empty))))
    }

}
