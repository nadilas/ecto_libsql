//! Unit and integration tests for ecto_libsql
//!
//! This module contains all tests for the NIF implementation, organized into logical groups.

use super::*;
use std::fs;

/// Tests for query type detection
mod query_type_detection {
    use super::*;

    #[test]
    fn test_detect_select_query() {
        assert_eq!(detect_query_type("SELECT * FROM users"), QueryType::Select);
        assert_eq!(
            detect_query_type("  SELECT id FROM posts"),
            QueryType::Select
        );
        assert_eq!(
            detect_query_type("\nSELECT name FROM items"),
            QueryType::Select
        );
        assert_eq!(detect_query_type("select * from users"), QueryType::Select);
    }

    #[test]
    fn test_detect_insert_query() {
        assert_eq!(
            detect_query_type("INSERT INTO users (name) VALUES ('Alice')"),
            QueryType::Insert
        );
        assert_eq!(
            detect_query_type("  INSERT INTO posts VALUES (1, 'title')"),
            QueryType::Insert
        );
    }

    #[test]
    fn test_detect_update_query() {
        assert_eq!(
            detect_query_type("UPDATE users SET name = 'Bob' WHERE id = 1"),
            QueryType::Update
        );
        assert_eq!(
            detect_query_type("update posts set title = 'New'"),
            QueryType::Update
        );
    }

    #[test]
    fn test_detect_delete_query() {
        assert_eq!(
            detect_query_type("DELETE FROM users WHERE id = 1"),
            QueryType::Delete
        );
        assert_eq!(detect_query_type("delete from posts"), QueryType::Delete);
    }

    #[test]
    fn test_detect_ddl_queries() {
        assert_eq!(
            detect_query_type("CREATE TABLE users (id INTEGER)"),
            QueryType::Create
        );
        assert_eq!(detect_query_type("DROP TABLE users"), QueryType::Drop);
        assert_eq!(
            detect_query_type("ALTER TABLE users ADD COLUMN email TEXT"),
            QueryType::Alter
        );
    }

    #[test]
    fn test_detect_transaction_queries() {
        assert_eq!(detect_query_type("BEGIN TRANSACTION"), QueryType::Begin);
        assert_eq!(detect_query_type("COMMIT"), QueryType::Commit);
        assert_eq!(detect_query_type("ROLLBACK"), QueryType::Rollback);
    }

    #[test]
    fn test_detect_unknown_query() {
        assert_eq!(
            detect_query_type("PRAGMA table_info(users)"),
            QueryType::Other
        );
        assert_eq!(
            detect_query_type("EXPLAIN SELECT * FROM users"),
            QueryType::Other
        );
        assert_eq!(detect_query_type(""), QueryType::Other);
    }

    #[test]
    fn test_detect_with_whitespace() {
        assert_eq!(
            detect_query_type("   \n\t  SELECT * FROM users"),
            QueryType::Select
        );
        assert_eq!(
            detect_query_type("\t\tINSERT INTO users"),
            QueryType::Insert
        );
    }
}

/// Integration tests with a real SQLite database
///
/// These tests require libsql to be working and will create temporary databases.
/// They verify that the actual database operations work correctly with parameter
/// binding, transactions, and various data types.
mod integration_tests {
    use super::*;

    fn setup_test_db() -> String {
        format!("test_{}.db", Uuid::new_v4())
    }

    fn cleanup_test_db(db_path: &str) {
        let _ = fs::remove_file(db_path);
    }

    #[tokio::test]
    async fn test_create_local_database() {
        let db_path = setup_test_db();

        let result = Builder::new_local(&db_path).build().await;
        assert!(result.is_ok(), "Failed to create local database");

        let db = result.unwrap();
        let conn = db.connect().unwrap();

        // Test basic query
        let result = conn
            .execute("CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)", ())
            .await;
        assert!(result.is_ok(), "Failed to create table");

        cleanup_test_db(&db_path);
    }

    #[tokio::test]
    async fn test_parameter_binding_with_integers() {
        let db_path = setup_test_db();
        let db = Builder::new_local(&db_path).build().await.unwrap();
        let conn = db.connect().unwrap();

        conn.execute("CREATE TABLE users (id INTEGER, age INTEGER)", ())
            .await
            .unwrap();

        // Test integer parameter binding
        let result = conn
            .execute(
                "INSERT INTO users (id, age) VALUES (?1, ?2)",
                vec![Value::Integer(1), Value::Integer(30)],
            )
            .await;

        assert!(result.is_ok(), "Failed to insert with integer params");

        // Verify the data
        let mut rows = conn
            .query(
                "SELECT id, age FROM users WHERE id = ?1",
                vec![Value::Integer(1)],
            )
            .await
            .unwrap();

        let row = rows.next().await.unwrap().unwrap();
        assert_eq!(row.get::<i64>(0).unwrap(), 1);
        assert_eq!(row.get::<i64>(1).unwrap(), 30);

        cleanup_test_db(&db_path);
    }

    #[tokio::test]
    async fn test_parameter_binding_with_floats() {
        let db_path = setup_test_db();
        let db = Builder::new_local(&db_path).build().await.unwrap();
        let conn = db.connect().unwrap();

        conn.execute("CREATE TABLE products (id INTEGER, price REAL)", ())
            .await
            .unwrap();

        // Test float parameter binding
        let result = conn
            .execute(
                "INSERT INTO products (id, price) VALUES (?1, ?2)",
                vec![Value::Integer(1), Value::Real(19.99)],
            )
            .await;

        assert!(result.is_ok(), "Failed to insert with float params");

        // Verify the data
        let mut rows = conn
            .query(
                "SELECT id, price FROM products WHERE id = ?1",
                vec![Value::Integer(1)],
            )
            .await
            .unwrap();

        let row = rows.next().await.unwrap().unwrap();
        assert_eq!(row.get::<i64>(0).unwrap(), 1);
        let price = row.get::<f64>(1).unwrap();
        assert!(
            (price - 19.99).abs() < 0.01,
            "Price should be approximately 19.99"
        );

        cleanup_test_db(&db_path);
    }

    #[tokio::test]
    async fn test_parameter_binding_with_text() {
        let db_path = setup_test_db();
        let db = Builder::new_local(&db_path).build().await.unwrap();
        let conn = db.connect().unwrap();

        conn.execute("CREATE TABLE users (id INTEGER, name TEXT)", ())
            .await
            .unwrap();

        // Test text parameter binding
        let result = conn
            .execute(
                "INSERT INTO users (id, name) VALUES (?1, ?2)",
                vec![Value::Integer(1), Value::Text("Alice".to_string())],
            )
            .await;

        assert!(result.is_ok(), "Failed to insert with text params");

        // Verify the data
        let mut rows = conn
            .query(
                "SELECT name FROM users WHERE id = ?1",
                vec![Value::Integer(1)],
            )
            .await
            .unwrap();

        let row = rows.next().await.unwrap().unwrap();
        assert_eq!(row.get::<String>(0).unwrap(), "Alice");

        cleanup_test_db(&db_path);
    }

    #[tokio::test]
    async fn test_transaction_commit() {
        let db_path = setup_test_db();
        let db = Builder::new_local(&db_path).build().await.unwrap();
        let conn = db.connect().unwrap();

        conn.execute("CREATE TABLE users (id INTEGER, name TEXT)", ())
            .await
            .unwrap();

        // Test transaction
        let tx = conn.transaction().await.unwrap();
        tx.execute(
            "INSERT INTO users (id, name) VALUES (?1, ?2)",
            vec![Value::Integer(1), Value::Text("Alice".to_string())],
        )
        .await
        .unwrap();
        tx.commit().await.unwrap();

        // Verify data was committed
        let mut rows = conn.query("SELECT COUNT(*) FROM users", ()).await.unwrap();
        let row = rows.next().await.unwrap().unwrap();
        assert_eq!(row.get::<i64>(0).unwrap(), 1);

        cleanup_test_db(&db_path);
    }

    #[tokio::test]
    async fn test_transaction_rollback() {
        let db_path = setup_test_db();
        let db = Builder::new_local(&db_path).build().await.unwrap();
        let conn = db.connect().unwrap();

        conn.execute("CREATE TABLE users (id INTEGER, name TEXT)", ())
            .await
            .unwrap();

        // Test transaction rollback
        let tx = conn.transaction().await.unwrap();
        tx.execute(
            "INSERT INTO users (id, name) VALUES (?1, ?2)",
            vec![Value::Integer(1), Value::Text("Alice".to_string())],
        )
        .await
        .unwrap();
        tx.rollback().await.unwrap();

        // Verify data was NOT committed
        let mut rows = conn.query("SELECT COUNT(*) FROM users", ()).await.unwrap();
        let row = rows.next().await.unwrap().unwrap();
        assert_eq!(row.get::<i64>(0).unwrap(), 0);

        cleanup_test_db(&db_path);
    }

    #[tokio::test]
    async fn test_prepared_statement() {
        let db_path = setup_test_db();
        let db = Builder::new_local(&db_path).build().await.unwrap();
        let conn = db.connect().unwrap();

        conn.execute("CREATE TABLE users (id INTEGER, name TEXT)", ())
            .await
            .unwrap();

        // Insert test data
        conn.execute(
            "INSERT INTO users (id, name) VALUES (?1, ?2)",
            vec![Value::Integer(1), Value::Text("Alice".to_string())],
        )
        .await
        .unwrap();
        conn.execute(
            "INSERT INTO users (id, name) VALUES (?1, ?2)",
            vec![Value::Integer(2), Value::Text("Bob".to_string())],
        )
        .await
        .unwrap();

        // Test prepared statement with first parameter
        let stmt1 = conn
            .prepare("SELECT name FROM users WHERE id = ?1")
            .await
            .unwrap();
        let mut rows1 = stmt1.query(vec![Value::Integer(1)]).await.unwrap();
        let row1 = rows1.next().await.unwrap().unwrap();
        assert_eq!(row1.get::<String>(0).unwrap(), "Alice");

        // Test prepared statement with second parameter (prepare again, mimicking NIF behavior)
        let stmt2 = conn
            .prepare("SELECT name FROM users WHERE id = ?1")
            .await
            .unwrap();
        let mut rows2 = stmt2.query(vec![Value::Integer(2)]).await.unwrap();
        let row2 = rows2.next().await.unwrap().unwrap();
        assert_eq!(row2.get::<String>(0).unwrap(), "Bob");

        cleanup_test_db(&db_path);
    }

    #[tokio::test]
    async fn test_blob_storage() {
        let db_path = setup_test_db();
        let db = Builder::new_local(&db_path).build().await.unwrap();
        let conn = db.connect().unwrap();

        conn.execute("CREATE TABLE files (id INTEGER, data BLOB)", ())
            .await
            .unwrap();

        let test_data = vec![0u8, 1, 2, 3, 4, 5, 255];
        conn.execute(
            "INSERT INTO files (id, data) VALUES (?1, ?2)",
            vec![Value::Integer(1), Value::Blob(test_data.clone())],
        )
        .await
        .unwrap();

        // Verify blob data
        let mut rows = conn
            .query(
                "SELECT data FROM files WHERE id = ?1",
                vec![Value::Integer(1)],
            )
            .await
            .unwrap();

        let row = rows.next().await.unwrap().unwrap();
        let retrieved_data = row.get::<Vec<u8>>(0).unwrap();
        assert_eq!(retrieved_data, test_data);

        cleanup_test_db(&db_path);
    }

    #[tokio::test]
    async fn test_null_values() {
        let db_path = setup_test_db();
        let db = Builder::new_local(&db_path).build().await.unwrap();
        let conn = db.connect().unwrap();

        conn.execute("CREATE TABLE users (id INTEGER, email TEXT)", ())
            .await
            .unwrap();

        conn.execute(
            "INSERT INTO users (id, email) VALUES (?1, ?2)",
            vec![Value::Integer(1), Value::Null],
        )
        .await
        .unwrap();

        // Verify null handling
        let mut rows = conn
            .query(
                "SELECT email FROM users WHERE id = ?1",
                vec![Value::Integer(1)],
            )
            .await
            .unwrap();

        let row = rows.next().await.unwrap().unwrap();
        let email_value = row.get_value(0).unwrap();
        assert!(matches!(email_value, Value::Null));

        cleanup_test_db(&db_path);
    }
}

/// Tests for registry management
///
/// These tests verify that the global registries (for connections, transactions,
/// statements, and cursors) are properly initialized and accessible.
mod registry_tests {
    use super::*;

    #[test]
    fn test_uuid_generation() {
        let uuid1 = Uuid::new_v4().to_string();
        let uuid2 = Uuid::new_v4().to_string();

        assert_ne!(uuid1, uuid2, "UUIDs should be unique");
        assert_eq!(uuid1.len(), 36, "UUID should be 36 characters long");
    }

    #[test]
    fn test_registry_initialization() {
        // Just verify registries can be accessed
        let conn_registry = CONNECTION_REGISTRY.lock();
        assert!(
            conn_registry.is_ok(),
            "Connection registry should be accessible"
        );

        let txn_registry = TXN_REGISTRY.lock();
        assert!(
            txn_registry.is_ok(),
            "Transaction registry should be accessible"
        );

        let stmt_registry = STMT_REGISTRY.lock();
        assert!(
            stmt_registry.is_ok(),
            "Statement registry should be accessible"
        );

        let cursor_registry = CURSOR_REGISTRY.lock();
        assert!(
            cursor_registry.is_ok(),
            "Cursor registry should be accessible"
        );
    }
}
