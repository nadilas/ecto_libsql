/// Global constants and atom declarations for EctoLibSql
///
/// This module holds all static configuration, global registries, and atom definitions
/// used throughout the codebase.
use lazy_static::lazy_static;
use once_cell::sync::Lazy;
use rustler::atoms;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use tokio::runtime::Runtime;

use crate::models::{CursorData, LibSQLConn, TransactionEntry};

/// Global Tokio runtime for async operations
pub static TOKIO_RUNTIME: Lazy<Runtime> =
    Lazy::new(|| Runtime::new().expect("Failed to create Tokio runtime"));

/// Default timeout for sync operations (in seconds)
pub const DEFAULT_SYNC_TIMEOUT_SECS: u64 = 30;

// Global registry for active database connections - Maps connection ID to LibSQLConn state
lazy_static! {
    pub static ref CONNECTION_REGISTRY: Mutex<HashMap<String, Arc<Mutex<LibSQLConn>>>> =
        Mutex::new(HashMap::new());
}

// Global registry for active transactions - Maps transaction ID to TransactionEntry
lazy_static! {
    pub static ref TXN_REGISTRY: Mutex<HashMap<String, TransactionEntry>> =
        Mutex::new(HashMap::new());
}

// Global registry for prepared statements - Maps statement ID to (connection_id, cached_statement)
lazy_static! {
    pub static ref STMT_REGISTRY: Mutex<HashMap<String, (String, Arc<Mutex<libsql::Statement>>)>> =
        Mutex::new(HashMap::new());
}

// Global registry for active cursors - Maps cursor ID to CursorData
lazy_static! {
    pub static ref CURSOR_REGISTRY: Mutex<HashMap<String, CursorData>> = Mutex::new(HashMap::new());
}

// Atom declarations for EctoLibSql - used as return values and option identifiers in the NIF interface
atoms! {
    local,
    remote_primary,
    remote_replica,
    ok,
    conn_id,
    trx_id,
    stmt_id,
    cursor_id,
    disable_sync,
    enable_sync,
    deferred,
    immediate,
    exclusive,
    read_only,
    transaction,
    connection,
    blob
}
