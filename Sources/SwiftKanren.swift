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

extension Term where Self: Equatable {

    public func equals(_ other: Term) -> Bool {
        if other is Self {
            return (other as! Self) == self
        }

        return false
    }

}



public struct Variable: Term {

    public let name: String

    public init(named name: String) {
        self.name = name
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


public class VariableFactory {

    fileprivate var state: State
    private var variables = [String: Variable]()

    fileprivate init(_ state: State) {
        self.state = state
    }

    subscript(name: String) -> Variable {
        if let variable = self.variables[name] {
            return variable
        }

        self.variables[name] = Variable(named: self.state.nextUnusedName)
        self.state = self.state.withNextNewName()
        return self.variables[name]!
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

    public static func ==(lhs: Value, rhs: Value) -> Bool {
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


public struct Map: Term {

    public typealias StorageType = [String: Term]

    fileprivate let storage: StorageType

    public init() {
        self.storage = [:]
    }

    public init<S: Sequence>(_ items: S) where S.Iterator.Element == (key: String, value: Term) {
        var storage = StorageType()
        for (key, value) in items {
            storage[key] = value
        }
        self.storage = storage
    }

    public var keys: LazyMapCollection<StorageType, String> {
        return self.storage.keys
    }

    public var values: LazyMapCollection<StorageType, Term> {
        return self.storage.values
    }

    public subscript(key: String) -> Term? {
        return self.storage[key]
    }

    public func with(key: String, value: Term) -> Map {
        var newStorage = self.storage
        newStorage[key] = value
        return Map(newStorage)
    }

}

extension Map: Equatable {

    public static func == (left: Map, right: Map) -> Bool {
        let leftKeys = left.storage.keys.sorted()
        let rightKeys = right.storage.keys.sorted()

        guard leftKeys == rightKeys else {
            return false
        }

        for (leftKey, rightKey) in zip(leftKeys, rightKeys) {
            guard left.storage[leftKey]!.equals(right.storage[rightKey]!) else {
                return false
            }
        }

        return true
    }

}

extension Map: Sequence {

    public func makeIterator() -> StorageType.Iterator {
        return self.storage.makeIterator()
    }

}

extension Map: Collection {

    public var startIndex: StorageType.Index {
        return self.storage.startIndex
    }

    public var endIndex: StorageType.Index {
        return self.storage.endIndex
    }

    public func index(after: StorageType.Index) -> StorageType.Index {
        return self.storage.index(after: after)
    }

    public subscript(index: StorageType.Index) -> StorageType.Element {
        return self.storage[index]
    }

}

extension Map: ExpressibleByDictionaryLiteral {

    public init(dictionaryLiteral elements: (String, Term)...) {
        self.init(elements.map { (key: $0.0, value: $0.1) })
    }

}

extension Map: CustomStringConvertible {

    public var description: String {
        return String(describing: self.storage)
    }

}


public struct Substitution {

    fileprivate var storage = [Variable: Term]()

    public typealias Association = (variable: Variable, term: Term)

    public subscript(_ key: Term) -> Term {
        // If the the given key isn't a variable, we can just give it back.
        guard let k = key as? Variable else {
            return key
        }

        if let rhs = self.storage[k] {
            // Continue walking in case the rhs is another variable.
            return self[rhs]
        }

        // We give back the variable if is not associated.
        return key
    }

    public func extended(with association: Association) -> Substitution {

        // NOTE: William Byrd's PhD thesis doesn't specify what is the
        // expected behaviour when extending a substitution map with an
        // already existing key.

        // TODO: Check for introduced circularity.

        var result = self
        result.storage[association.variable] = association.term
        return result
    }

    public func unifying(_ u: Term, _ v: Term) -> Substitution? {
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

        // If the walked values of u and of v are maps, then unifying them
        // boils down to unifying their elements.
        if (walkedU is Map) && (walkedV is Map) {
            return self.unifyingMaps(walkedU as! Map, walkedV as! Map)
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

    private func unifyingMaps(_ u: Map, _ v: Map) -> Substitution? {
        let leftKeys = u.keys.sorted()
        let rightKeys = v.keys.sorted()

        // Unifying dictionaries with different keys always fail.
        guard leftKeys == rightKeys else {
            return nil
        }

        // Unifying dictionaires boils down to unifying the values associated,
        // with each of their respective keys.
        var result: Substitution? = self
        for (leftKey, rightKey) in zip(leftKeys, rightKeys) {
            result = result?.unifying(u[leftKey]!, v[rightKey]!)
        }
        return result
    }

    public func reified() -> Substitution {
        var result = Substitution()
        for variable in self.storage.keys {
            let walked = self.deepWalk(variable)
            if let v = walked as? Variable {
                result = result.extended(with: (variable: variable, term: Unassigned(v)))
            } else {
                result = result.extended(with: (variable: variable, term: walked))
            }
        }
        return result
    }

    private func deepWalk(_ value: Term) -> Term {
        // If the given value is a list, we have to "deep" walk its elements.
        if let l = value as? List {
            switch l {
            case .empty:
                return l
            case .cons(let h, let t):
                return List.cons(self.deepWalk(h), self.deepWalk(t))
            }
        }

        // If the given value is a map, we have to "deep" walk its values.
        if let m = value as? Map {
            var reifiedMap = Map()
            for item in m {
                reifiedMap = reifiedMap.with(key: item.key, value: self.deepWalk(item.value))
            }
            return reifiedMap
        }

        // If the the given value isn't a variable, we can just give it back.
        guard let key = value as? Variable else {
            return value
        }

        if let rhs = self.storage[key] {
            // Continue walking in case the rhs is another variable.
            return self.deepWalk(rhs)
        }

        // We give back the variable if is not associated.
        return value
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

    fileprivate let substitution: Substitution
    fileprivate var nextUnusedName: String {
        return "$" + String(describing: self.nextId)
    }

    private let nextId: Int

    public init(substitution: Substitution = Substitution(), nextId: Int = 0) {
        self.substitution = substitution
        self.nextId = nextId
    }

    fileprivate func with(newSubstitution: Substitution) -> State {
        return State(substitution: newSubstitution, nextId: self.nextId)
    }

    fileprivate func withNextNewName() -> State {
        return State(substitution: self.substitution, nextId: self.nextId + 1)
    }

}


public enum Stream {

    case empty
    indirect case mature(head: State, next: Stream)
    case immature(thunk: () -> Stream)

    // mplus
    fileprivate func merge(_ other: Stream) -> Stream {
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
    fileprivate func map(_ goal: @escaping Goal) -> Stream {
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
    fileprivate func realize() -> Stream {
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
public func ≡ (u: Term, v: Term) -> Goal {
    return { state in
        if let s = state.substitution.unifying(u, v) {
            return .mature(head: state.with(newSubstitution: s), next: .empty)
        }

        return .empty
    }
}

/// Alternative for ≡(_:_:)
public func === (u: Term, v: Term) -> Goal {
    return u ≡ v
}


/// Takes a goal constructor and returns a goal with fresh variables.
///
/// This function takes a *goal constructor* (i.e. a function), which accepts
/// a single variable as parameter, and returns a new goal for which the
/// variable is fresh.
public func fresh(_ constructor: @escaping (Variable) -> Goal) -> Goal {
    return { state in
        constructor(Variable(named: state.nextUnusedName))(state.withNextNewName())
    }
}


/// Takes a goal constructor and returns a goal with fresh variables.
///
/// This function takes a *goal constructor* (i.e. a function), which accepts
/// a variable factory as parameter, and returns a new goal for which all the
/// variables generated by the factory are fresh.
public func freshn(_ constructor: @escaping (VariableFactory) -> Goal) -> Goal {
    return { state in
        let factory = VariableFactory(state)
        return constructor(factory)(factory.state)
    }
}


/// Constructs a disjunction of goals.
public func || (left: @escaping Goal, right: @escaping Goal) -> Goal {
    return { state in
        left(state).merge(right(state))
    }
}


/// Constructs a conjunction of goals.
public func && (left: @escaping Goal, right: @escaping Goal) -> Goal {
    return { state in
        left(state).map(right)
    }
}


/// Takes a goal constructor and returns a goal with substitution.
///
/// This function takes a *goal constructor* (i.e. a function), which accepts
/// a substitution as parameter, and returns a new goal.
public func inEnvironment (_ constructor: @escaping (Substitution) -> Goal) -> Goal {
    return { state in
        let reified = state.substitution.reified()
        return constructor(reified)(state)
    }
}


/// Takes a goal and returns a thunk that wraps it.
public func delayed(_ goal: @escaping Goal) -> Goal {
    return { state in
        .immature { goal(state) }
    }
}


/// Executes a logic program (i.e. a goal) with an optional initial state.
public func solve(withInitialState state: State? = nil, _ program: Goal) -> Stream {
    return program(state ?? State())
}


/// A goal that always succeeds.
public let success = (Value(true) === Value(true))


/// A goal that always fails.
public let failure = (Value(false) === Value(true))


/// Creates a goal that tests if a term is an instance of a `Value<T>`
/// in the current substitution.
public func isValue<T : Equatable>(_ term: Term, _ type: T.Type) -> Goal {
    return inEnvironment { substitution in
        if substitution [term] is Value<T> {
          return success
        } else {
          return failure
        }
    }
}


/// Creates a goal that tests if a term is an instance of a `Variable`
/// in the current substitution.
public func isVariable(_ term: Term) -> Goal {
    return inEnvironment { substitution in
        if substitution [term] is Variable {
          return success
        } else {
          return failure
        }
    }
}


/// Creates a goal that tests if a term is an instance of a `List`
/// in the current substitution.
public func isList(_ term: Term) -> Goal {
    return inEnvironment { substitution in
        if substitution [term] is List {
          return success
        } else {
          return failure
        }
    }
}


/// Creates a goal that tests if a term is an instance of a `Map`
/// in the current substitution.
public func isMap(_ term: Term) -> Goal {
    return inEnvironment { substitution in
        if substitution [term] is Map {
          return success
        } else {
          return failure
        }
    }
}
