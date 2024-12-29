//
// Copyright 2019 Signal Messenger, LLC
// SPDX-License-Identifier: AGPL-3.0-only
//

import Foundation
public import GRDB
public import LibSignalClient

// MARK: - Any*Transaction

@objc
public class GRDBReadTransaction: NSObject {

    public let database: Database

    public let startDate = Date()

    init(database: Database) {
        self.database = database
    }

    @objc
    public var asAnyRead: SDSAnyReadTransaction {
        return SDSAnyReadTransaction(.grdbRead(self))
    }
}

// MARK: -

@objc
public class GRDBWriteTransaction: GRDBReadTransaction {

    private enum TransactionState {
        case open
        case finalizing
        case finalized
    }
    private var transactionState: TransactionState = .open

    override init(database: Database) {
        super.init(database: database)
    }

    deinit {
        if transactionState != .finalized {
            owsFailDebug("Write transaction not finalized.")
        }
    }

    // This method must be called before the transaction is deallocated.
    @objc
    public func finalizeTransaction() {
        guard transactionState == .open else {
            owsFailDebug("Write transaction finalized more than once.")
            return
        }
        transactionState = .finalizing
        performTransactionFinalizationBlocks()
        transactionState = .finalized
    }

    @objc
    public var asAnyWrite: SDSAnyWriteTransaction {
        return SDSAnyWriteTransaction(.grdbWrite(self))
    }

    public typealias CompletionBlock = () -> Void
    internal var syncCompletions: [CompletionBlock] = []
    public struct AsyncCompletion {
        let scheduler: Scheduler
        let block: CompletionBlock
    }
    internal var asyncCompletions: [AsyncCompletion] = []

    @objc
    public func addSyncCompletion(block: @escaping CompletionBlock) {
        syncCompletions.append(block)
    }

    @objc
    public func addAsyncCompletion(queue: DispatchQueue, block: @escaping CompletionBlock) {
        addAsyncCompletion(on: queue, block: block)
    }

    public func addAsyncCompletion(on scheduler: Scheduler, block: @escaping CompletionBlock) {
        asyncCompletions.append(AsyncCompletion(scheduler: scheduler, block: block))
    }

    fileprivate typealias TransactionFinalizationBlock = (_ transaction: GRDBWriteTransaction) -> Void
    private var transactionFinalizationBlocks = [String: TransactionFinalizationBlock]()
    private var removedFinalizationKeys = Set<String>()

    private func performTransactionFinalizationBlocks() {
        assert(transactionState == .finalizing)

        let blocksCopy = transactionFinalizationBlocks
        transactionFinalizationBlocks.removeAll()
        for (key, block) in blocksCopy {
            guard !removedFinalizationKeys.contains(key) else {
                continue
            }
            block(self)
        }
        assert(transactionFinalizationBlocks.isEmpty)
    }

    fileprivate func addTransactionFinalizationBlock(forKey key: String,
                                                     block: @escaping TransactionFinalizationBlock) {
        guard !removedFinalizationKeys.contains(key) else {
            // We shouldn't be adding finalizations for removed keys,
            // e.g. touching removed entities.
            owsFailDebug("Finalization unexpectedly added for removed key.")
            return
        }
        guard transactionState == .open else {
            // We're already finalizing; run the block immediately.
            block(self)
            return
        }
        // Always overwrite; we want to use the _last_ block.
        // For example, in the case of touching thread, a given
        // transaction might use multiple copies of a thread.
        // We want to touch the last copy of the thread that was
        // written to the database.
        transactionFinalizationBlocks[key] = block
    }

    fileprivate func addRemovedFinalizationKey(_ key: String) {
        guard !removedFinalizationKeys.contains(key) else {
            owsFailDebug("Finalization key removed twice.")
            return
        }
        removedFinalizationKeys.insert(key)
    }
}

// MARK: -

@objc
public class SDSAnyReadTransaction: NSObject {
    public enum ReadTransactionType {
        case grdbRead(_ transaction: GRDBReadTransaction)
    }

    public let readTransaction: ReadTransactionType
    public var startDate: Date {
        switch readTransaction {
        case .grdbRead(let grdbRead):
            return grdbRead.startDate
        }
    }

    init(_ readTransaction: ReadTransactionType) {
        self.readTransaction = readTransaction
    }
}

@objc
public class SDSAnyWriteTransaction: SDSAnyReadTransaction, StoreContext {
    public enum WriteTransactionType {
        case grdbWrite(_ transaction: GRDBWriteTransaction)
    }

    public let writeTransaction: WriteTransactionType

    init(_ writeTransaction: WriteTransactionType) {
        self.writeTransaction = writeTransaction

        let readTransaction: ReadTransactionType
        switch writeTransaction {
        case .grdbWrite(let grdbWrite):
            readTransaction = ReadTransactionType.grdbRead(grdbWrite)
        }

        super.init(readTransaction)
    }

    // NOTE: These completions are performed _after_ the write
    //       transaction has completed.
    @objc
    public func addSyncCompletion(_ block: @escaping () -> Void) {
        switch writeTransaction {
        case .grdbWrite(let grdbWrite):
            grdbWrite.addSyncCompletion(block: block)
        }
    }

    // Objective-C doesn't honor default arguments.
    @objc
    public func addAsyncCompletionOnMain(_ block: @escaping () -> Void) {
        addAsyncCompletion(queue: .main, block: block)
    }

    // Objective-C doesn't honor default arguments.
    @objc
    public func addAsyncCompletionOffMain(_ block: @escaping () -> Void) {
        addAsyncCompletion(queue: .global(), block: block)
    }

    @objc
    public func addAsyncCompletion(queue: DispatchQueue, block: @escaping () -> Void) {
        switch writeTransaction {
        case .grdbWrite(let grdbWrite):
            grdbWrite.addAsyncCompletion(queue: queue, block: block)
        }
    }

    public func addAsyncCompletion(on scheduler: Scheduler, block: @escaping () -> Void) {
        switch writeTransaction {
        case .grdbWrite(let grdbWrite):
            grdbWrite.addAsyncCompletion(on: scheduler, block: block)
        }
    }

    public typealias TransactionFinalizationBlock = (SDSAnyWriteTransaction) -> Void

    @objc
    public func addTransactionFinalizationBlock(forKey key: String,
                                                block: @escaping TransactionFinalizationBlock) {
        switch writeTransaction {
        case .grdbWrite(let grdbWrite):
            grdbWrite.addTransactionFinalizationBlock(forKey: key) { (transaction: GRDBWriteTransaction) in
                block(SDSAnyWriteTransaction(.grdbWrite(transaction)))
            }
        }
    }

    @objc
    public func addRemovedFinalizationKey(_ key: String) {
        switch writeTransaction {
        case .grdbWrite(let grdbWrite):
            grdbWrite.addRemovedFinalizationKey(key)
        }
    }
}

// MARK: -

public extension StoreContext {
    var asTransaction: SDSAnyWriteTransaction {
        return self as! SDSAnyWriteTransaction
    }
}

// MARK: - Convenience Methods

public extension GRDBWriteTransaction {
    /// Execute some SQL.
    func execute(sql: String, arguments: StatementArguments = .init()) {
        database.executeHandlingErrors(sql: sql, arguments: arguments)
    }

    func executeAndCacheStatement(sql: String, arguments: StatementArguments) {
        database.executeAndCacheStatementHandlingErrors(sql: sql, arguments: arguments)
    }
}

public extension Database {
    /// Execute some SQL.
    func executeHandlingErrors(sql: String, arguments: StatementArguments) {
        do {
            let statement = try makeStatement(sql: sql)
            try statement.setArguments(arguments)
            try statement.execute()
        } catch {
            handleFatalDatabaseError(error)
        }
    }

    /// Execute some SQL and cache the statement.
    ///
    /// Caching the statement has significant performance benefits over ``execute`` for queries
    /// that are performed repeatedly.
    func executeAndCacheStatementHandlingErrors(sql: String, arguments: StatementArguments = .init()) {
        do {
            let statement = try cachedStatement(sql: sql)
            try statement.setArguments(arguments)
            try statement.execute()
        } catch {
            handleFatalDatabaseError(error)
        }
    }
}

// MARK: -

@objc
public extension SDSAnyReadTransaction {
    var unwrapGrdbRead: GRDBReadTransaction {
        switch readTransaction {
        case .grdbRead(let grdbRead):
            return grdbRead
        }
    }
}

// MARK: -

@objc
public extension SDSAnyWriteTransaction {
    var unwrapGrdbWrite: GRDBWriteTransaction {
        switch writeTransaction {
        case .grdbWrite(let grdbWrite):
            return grdbWrite
        }
    }
}

// MARK: -

public extension GRDB.Database {
    final func strictRead<T>(_ criticalSection: (_ database: GRDB.Database) throws -> T) -> T {
        do {
            return try criticalSection(self)
        } catch {
            handleFatalDatabaseError(error)
        }
    }
}

// MARK: -

private func handleFatalDatabaseError(_ error: Error) -> Never {
    DatabaseCorruptionState.flagDatabaseCorruptionIfNecessary(
        userDefaults: CurrentAppContext().appUserDefaults(),
        error: error
    )
    owsFail("Error: \(error)")
}
