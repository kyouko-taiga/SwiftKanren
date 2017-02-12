//
//  LogicKit.swift
//  LogicKit
//
//  Created by Dimitri Racordon on 07.02.17.
//  Copyright © 2017 University of Geneva. All rights reserved.
//

public protocol Term {

    // We can't make the Term conform to Equatable, as we need to use within
    // heterogeneous collections. Hence we can't have a safe requirements
    // (see WWDC 2015 - session 408). Similarly, we can't require conforming
    // types to implement the global equality operator (==), as the various
    // overloads would become ambiguous without a self requirement.
    func equals(_ other: Term) -> Bool

}


public struct Variable: Term {

    public let name: String

    public func equals(_ other: Term) -> Bool {
        if other is Variable {
            return (other as! Variable).name == self.name
        }

        return false
    }

}

extension Variable: Hashable {

    public var hashValue: Int {
        return self.name.hashValue
    }

    public static func == (left: Variable, right: Variable) -> Bool {
        return left.name == right.name
    }

}

extension Variable: CustomStringConvertible {

    public var description: String {
        return self.name
    }
    
}



public struct Value<T: Equatable>: Term {

    fileprivate let wrapped: T

    public init(_ val: T) {
        self.wrapped = val
    }

    public func equals(_ other: Term) -> Bool {
        if let rhs = (other as? Value<T>) {
            return rhs.wrapped == self.wrapped
        }

        return false
    }

}

extension Value: Equatable {

    public static func == <T: Equatable>(lhs: Value<T>, rhs: Value<T>) -> Bool {
        return lhs.wrapped == rhs.wrapped
    }

}

extension Value: CustomStringConvertible {

    public var description: String {
        return String(describing: self.wrapped)
    }

}


public struct Unassigned: Term, CustomStringConvertible {

    private static var variables = [Variable: Int]()
    private static let unicodeSubscripts = [
        "\u{2080}", "\u{2081}", "\u{2082}", "\u{2083}", "\u{2084}",
        "\u{2085}", "\u{2086}", "\u{2087}", "\u{2088}", "\u{2089}"]

    private var id: Int

    fileprivate init(_ variable: Variable) {
        if Unassigned.variables[variable] == nil {
            Unassigned.variables[variable] = Unassigned.variables.count
        }
        self.id = Unassigned.variables[variable]!
    }

    public func equals(_ other: Term) -> Bool {
        return false
    }

    public var description: String {
        var suffix = ""
        if self.id == 0 {
            suffix = Unassigned.unicodeSubscripts[0]
        } else {
            var number = self.id
            while number > 0 {
                suffix = Unassigned.unicodeSubscripts[number % 10] + suffix
                number /= 10
            }
        }

        return "_" + suffix
    }

}


public enum List: Term {

    case empty, cons(Term, Term)

    public func equals(_ other: Term) -> Bool {
        guard let rhs = other as? List else {
            return false
        }

        switch (self, rhs) {
        case (.empty, .empty):
            return true
        case (.cons(let lh, let lt), .cons(let rh, let rt)):
            return lh.equals(rh) && lt.equals(rt)
        default:
            return false
        }
    }
    
}


public struct Substitution {

    fileprivate var storage = [Variable: Term]()

    public typealias Association = (variable: Variable, term: Term)

    subscript(_ key: Term) -> Term {
        // If the given key is a list, we have to walk its elements.
        if let l = key as? List {
            switch l {
            case .empty:
                return l
            case .cons(let h, let t):
                return List.cons(self[h], self[t])
            }
        }

        // If the the given key isn't a variable, we can just give it back.
        guard let k = key as? Variable else {
            return key
        }

        if let rhs = self.storage[k] {
            // Continue walking in case the rhs is another variable, or a
            // superterm whose subterms should also be walked.
            return self[rhs]
        }

        // We give back the variable if is not associated.
        return key
    }

    func extended(with association: Association) -> Substitution {
        // TODO: Check for introduced circularity.
        var result = self
        result.storage[association.variable] = association.term
        return result
    }

    func unifying(_ u: Term, _ v: Term) -> Substitution? {
        let walkedU = self[u]
        let walkedV = self[v]

        // Terms that walk to equal values always unify, but add nothing to
        // the substitution.
        if walkedU.equals(walkedV) {
            return self
        }

        // Unifying a logic variable with some other term creates a new entry
        // in the substitution.
        if walkedU is Variable {
            return self.extended(with: (variable: walkedU as! Variable, term: walkedV))
        } else if walkedV is Variable {
            return self.extended(with: (variable: walkedV as! Variable, term: walkedU))
        }

        // If the walked values of u and of v are lists, then unifying them
        // boils down to unifying their elements.
        if (walkedU is List) && (walkedV is List) {
            return self.unifyingLists(walkedU as! List, walkedV as! List)
        }

        return nil
    }

    private func unifyingLists(_ u: List, _ v: List) -> Substitution? {
        switch (u, v) {
        case (.empty, .empty):
            // Empty lists always unify, but add nothing to the substitution.
            return self

        case (.cons(let uh, let ut), .cons(let vh, let vt)):
            // Unifying non-empty lists boils down to unifying their head,
            // before recursively unifying their tails.
            return self.unifying(uh, vh)?.unifying(ut, vt)

        default:
            // Unifying a non-empty list with an empty list always fail.
            return nil
        }
    }

    func reifying(_ term: Term) -> Substitution {
        let walked = self[term]

        if let v = walked as? Variable {
            return self.extended(with: (variable: v, term: Unassigned(v)))
        }

        // If the walked value of the term is a list, its elements should be
        // reified as well.
        if let l = walked as? List {
            switch l {
            case .empty:
                return self
            case .cons(let h, let t):
                return self.reifying(h).reifying(t)
            }
        }

        return self
    }

    func reified() -> Substitution {
        var result = self
        for variable in self.storage.keys {
            result = result.reifying(variable)
        }
        return result
    }

}

extension Substitution: Sequence {

    public func makeIterator() -> AnyIterator<Association> {
        var it = self.storage.makeIterator()

        return AnyIterator {
            if let (variable, term) = it.next() {
                return (variable: variable, term: self[term])
            }

            return nil
        }
    }

}


/// A struct containing a substitution and the name of the next unused logic
/// variable.
public struct State {

    let substitution: Substitution
    var nextUnusedName: String {
        return "$" + String(describing: self.nextId)
    }

    private let nextId: Int

    init(substitution: Substitution = Substitution(), nextId: Int = 0) {
        self.substitution = substitution
        self.nextId = nextId
    }

    func with(newSubstitution: Substitution) -> State {
        return State(substitution: newSubstitution, nextId: self.nextId)
    }

    func withNextNewName() -> State {
        return State(substitution: self.substitution, nextId: self.nextId + 1)
    }

}


public enum Stream {

    case empty
    indirect case mature(head: State, next: Stream)
    case immature(thunk: () -> Stream)

    // mplus
    func merge(_ other: Stream) -> Stream {
        switch self {
        case .empty:
            return other

        case .mature(head: let state, next: let next):
            return .mature(head: state, next: next.merge(other))

        case .immature(thunk: let thunk):
            return .immature {
                return other.merge(thunk())
            }
        }
    }

    // bind
    func map(_ goal: @escaping Goal) -> Stream {
        switch self {
        case .empty:
            return .empty

        case .mature(head: let head, next: let next):
            return goal(head).merge(next.map(goal))

        case .immature(thunk: let thunk):
            return .immature {
                return thunk().map(goal)
            }
        }
    }

    // pull
    func realize() -> Stream {
        switch self {
        case .empty:
            return .empty

        case .mature(head: _, next: _):
            return self

        case .immature(thunk: let thunk):
            return thunk().realize()
        }
    }

}

extension Stream: Sequence {

    public func makeIterator() -> AnyIterator<Substitution> {
        var it = self

        return AnyIterator {

            // Realize the iterated stream here, so that we its state is
            // computed as lazily as possible (i.e. when the iterator's next()
            // method is called).

            switch it.realize() {
            case .empty:
                // Return nothing for empty stream, ending the sequence.
                return nil

            case .mature(head: let state, next: let successor):
                // Return the realized substitution and advance the iterator.
                it = successor
                return state.substitution

            case .immature(thunk: _):
                assertionFailure("realize shouldn't produce immature streams")
            }

            return nil
        }
    }

}


/// Represents a function that encapsulates a logic program and which, given a
/// state, returns a stream of states for each way the program can succeed.
public typealias Goal = (State) -> Stream


infix operator ≡   : ComparisonPrecedence
infix operator === : ComparisonPrecedence

/// Creates a goal that unify two terms.
///
/// The goal takes an existing state and returns (as a lazy stream) either a
/// state with bindings for the variables in u and v (using unification), or
/// nothing at all if u and v cannot be unified.
func ≡ (u: Term, v: Term) -> Goal {
    return { state in
        if let s = state.substitution.unifying(u, v) {
            return .mature(head: state.with(newSubstitution: s), next: .empty)
        }

        return .empty
    }
}

/// Alternative for ≡(_:_:)
func === (u: Term, v: Term) -> Goal {
    return u ≡ v
}


/// Takes a goal constructor and returns a goal with fresh variables.
///
/// This function takes a *goal constructor* (i.e. a function), which accepts
/// a single variable as parameter, and returns a new goal for which the
/// variable is fresh.
func fresh(_ constructor: @escaping (Variable) -> Goal) -> Goal {
    return { state in
        constructor(Variable(name: state.nextUnusedName))(state.withNextNewName())
    }
}


/// Constructs a disjunction of goals.
func || (left: @escaping Goal, right: @escaping Goal) -> Goal {
    return { state in
        left(state).merge(right(state))
    }
}


/// Constructs a conjunction of goals.
func && (left: @escaping Goal, right: @escaping Goal) -> Goal {
    return { state in
        left(state).map(right)
    }
}


/// Takes a goal and returns a thunk that wraps it.
func delayed(_ goal: @escaping Goal) -> Goal {
    return { state in
        .immature { goal(state) }
    }
}
