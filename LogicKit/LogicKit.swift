//
//  LogicKit.swift
//  LogicKit
//
//  Created by Dimitri Racordon on 07.02.17.
//  Copyright © 2017 University of Geneva. All rights reserved.
//

public protocol Term {

    func equals(other: Term) -> Bool

}


public struct Variable: Term {

    public let name: String

    public func equals(other: Term) -> Bool {
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


public struct Value<T: Equatable>: Term {

    private let value: T

    public init(_ val: T) {
        self.value = val
    }

    public func equals(other: Term) -> Bool {
        if other is Variable {
            return true
        }

        if let rhs = (other as? Value<T>) {
            return rhs.value == self.value
        }

        return false
    }

}


public struct Unassigned: Term {

    public func equals(other: Term) -> Bool {
        return false
    }

}


struct Substitution {

    fileprivate var storage = [Variable: Term]()

    subscript(_ key: Term) -> Term {
        // If the the given key isn't a variable, we should just give it back.
        guard let k = key as? Variable else {
            return key
        }

        if let rhs = self.storage[k] {
            switch rhs {
            case let variable as Variable:
                // If the rhs of the substitution is a variable, we should
                // search for this variable's substitution.
                return self[variable]

            default:
                return rhs
            }
        }

        // We give back the variabe if is not associated.
        return key
    }

    func extended(with association: (key: Variable, term: Term)) -> Substitution {
        // TODO: Check for introduced circularity.
        var result = self
        result.storage[association.key] = association.term
        return result
    }

    func unifying(_ u: Term, _ v: Term) -> Substitution? {
        let walkedU = self[u]
        let walkedV = self[v]

        // Terms that walk to equal values always unify, but add nothing
        // to the substitution.
        if walkedU.equals(other: walkedV) {
            return self
        }

        // Unifying an lvar term with some other value creates a new entry in
        // the substitution.
        if walkedU is Variable {
            return self.extended(with: (key: walkedU as! Variable, term: walkedV))
        } else if walkedV is Variable {
            return self.extended(with: (key: walkedV as! Variable, term: walkedU))
        }

        return nil
    }

    func reifying(_ term: Term) -> Substitution? {
        let walked = self[term]

        if walked is Variable {
            return self.extended(with: (key: walked as! Variable, term: Unassigned()))
        }

        return self
    }

    func reified() -> Substitution {
        var result = self
        for variable in self.storage.keys {
            result = result.reifying(variable) ?? result
        }
        return result
    }

}


extension Substitution: Sequence {

    typealias Iterator = DictionaryIterator<Variable, Term>

    func makeIterator() -> Iterator {
        return self.storage.makeIterator()
    }

}


/// A struct containing a substitution and the name of the next unused logic
/// variable.
public struct State {

    let substitution: Substitution
    var nextUnusedName: String {
        return "_" + String(describing: self.nextId)
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
            return thunk()
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
