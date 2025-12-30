# Test Import Project Index

## Overview
Systematic plan to import 55-70 tests from sibling ecto_sql project to ensure ecto_libsql correctly implements the full libSQL/SQLite API with Ecto compatibility.

**Current State**: 8,765 lines of tests across 20 files  
**Target State**: 11,000+ lines with 55-70 new tests  
**Timeline**: 4 weeks across 4 phases

---

## Document Hierarchy

### 1. **START HERE** → TEST_IMPORT_SUMMARY.md
- **Length**: 3 pages
- **Content**: Quick overview, getting started guide, file map
- **Read Time**: 5 minutes
- **Purpose**: Understand the project scope and find what you need

### 2. **STRATEGY** → TEST_SUITE_CONSOLIDATION_PLAN.md
- **Length**: 5 pages
- **Content**: Strategic planning, categories, roadmap, success criteria
- **Read Time**: 15 minutes
- **Purpose**: Understand why we're doing this and what's involved

### 3. **IMPLEMENTATION** → TESTS_TO_PORT.md
- **Length**: 8 pages
- **Content**: Specific tests with code examples, SQLite adaptations
- **Read Time**: 30 minutes
- **Purpose**: See exactly which tests to port and how to adapt them

### 4. **HOW-TO** → TEST_EXTRACTION_GUIDE.md
- **Length**: 6 pages
- **Content**: Step-by-step instructions, patterns, troubleshooting
- **Read Time**: 20 minutes
- **Purpose**: Actually perform the test porting work

### 5. **TRACKING** → TEST_IMPORT_CHECKLIST.md
- **Length**: 5 pages
- **Content**: Detailed checklist by phase, templates, progress tracking
- **Read Time**: 10 minutes
- **Purpose**: Track progress and stay organized during implementation

### 6. **THIS FILE** → TEST_IMPORT_INDEX.md
- **Length**: 2 pages
- **Content**: Navigation and quick reference
- **Purpose**: Find what you need quickly

---

## Quick Reference by Task

### "I want to understand the project"
1. Read: TEST_IMPORT_SUMMARY.md (5 min)
2. Read: TEST_SUITE_CONSOLIDATION_PLAN.md (15 min)
3. Skim: TESTS_TO_PORT.md (5 min)

### "I want to start porting tests"
1. Read: TEST_EXTRACTION_GUIDE.md (20 min)
2. Open: TESTS_TO_PORT.md (reference while coding)
3. Use: TEST_IMPORT_CHECKLIST.md (track progress)
4. Reference: test/ecto_integration_test.exs (existing patterns)

### "I'm stuck on a specific test"
1. Check: TEST_EXTRACTION_GUIDE.md "Common Issues & Fixes"
2. Reference: TESTS_TO_PORT.md section for that test category
3. Example: test/ecto_integration_test.exs similar test

### "I want to know what's next"
1. Open: TEST_IMPORT_CHECKLIST.md
2. Find current phase
3. Check boxes for today's work
4. Commit with format from checklist

### "I want to track overall progress"
1. Check: TEST_IMPORT_CHECKLIST.md "Progress Tracking"
2. Count completed tests
3. Compare to phase metrics
4. Update checklist

---

## Phase Overview

### Phase 1: Foundation (Week 1)
**Files Created**: 2 new test files  
**Tests Added**: 20-25  
**Lines Added**: 1,000+  
**Focus**: Basic SQL compatibility, streaming

**New Files**:
- test/ecto_sql_compatibility_test.exs
- test/ecto_stream_compat_test.exs

**Source**:
- ecto_sql/integration_test/sql/sql.exs
- ecto_sql/integration_test/sql/stream.exs

### Phase 2: Core (Week 2-3)
**Files Created**: 2 more test files  
**Tests Added**: 15-25 (total 35-50)  
**Lines Added**: 1,500+ (total 2,500+)  
**Focus**: Transactions, savepoints, prepared statements

**New Files**:
- test/ecto_sql_transaction_compat_test.exs
- test/ecto_prepared_stmt_advanced_test.exs

**Source**:
- ecto_sql/integration_test/sql/transaction.exs
- ecto_sql/integration_test/pg/prepare_test.exs

### Phase 3: Complete (Week 3-4)
**Files Created**: 2 more test files  
**Tests Added**: 15-20 (total 50-65)  
**Lines Added**: 1,000+ (total 3,500+)  
**Focus**: Constraints, migrations, schema versioning

**New Files**:
- test/ecto_constraint_compat_test.exs
- test/ecto_migration_compat_test.exs

**Source**:
- ecto_sql/integration_test/pg/constraints_test.exs
- ecto_sql/integration_test/sql/migration.exs

### Phase 4: Polish (Week 4+)
**Files Updated**: 1 existing file  
**Tests Added**: 10-15 (total 65-75)  
**Lines Added**: 500+ (total 4,000+)  
**Focus**: Exception handling, cross-mode validation

**Updated Files**:
- test/error_handling_test.exs

**Source**:
- ecto_sql/integration_test/pg/exceptions_test.exs

---

## File Map

```
ecto_libsql/
├── TEST_IMPORT_INDEX.md ← YOU ARE HERE
├── TEST_IMPORT_SUMMARY.md (read first for overview)
├── TEST_SUITE_CONSOLIDATION_PLAN.md (read for strategy)
├── TESTS_TO_PORT.md (reference while coding)
├── TEST_EXTRACTION_GUIDE.md (how-to guide)
├── TEST_IMPORT_CHECKLIST.md (track progress)
│
└── test/
    ├── test_helper.exs (existing setup)
    ├── ecto_integration_test.exs (existing patterns to follow)
    ├── error_handling_test.exs (update in Phase 4)
    │
    ├── [Phase 1] ecto_sql_compatibility_test.exs (NEW)
    ├── [Phase 1] ecto_stream_compat_test.exs (NEW)
    ├── [Phase 2] ecto_sql_transaction_compat_test.exs (NEW)
    ├── [Phase 2] ecto_prepared_stmt_advanced_test.exs (NEW)
    ├── [Phase 3] ecto_constraint_compat_test.exs (NEW)
    ├── [Phase 3] ecto_migration_compat_test.exs (NEW)
    └── [Phase 4] (update error_handling_test.exs)
```

---

## Test Sources (In Sibling Directories)

### High Priority (Very Portable)
```
/Users/drew/code/ecto_sql/integration_test/sql/sql.exs          ⭐⭐⭐
/Users/drew/code/ecto_sql/integration_test/sql/transaction.exs  ⭐⭐⭐
/Users/drew/code/ecto_sql/integration_test/sql/stream.exs       ⭐⭐⭐
/Users/drew/code/ecto_sql/integration_test/sql/migration.exs    ⭐⭐⭐
```

### Medium Priority (Needs Adaptation)
```
/Users/drew/code/ecto_sql/integration_test/pg/prepare_test.exs       ⭐⭐
/Users/drew/code/ecto_sql/integration_test/pg/constraints_test.exs   ⭐⭐
/Users/drew/code/ecto_sql/integration_test/pg/exceptions_test.exs    ⭐⭐
```

### Lower Priority (DB-specific)
```
/Users/drew/code/ecto_sql/integration_test/pg/          (PostgreSQL-specific)
/Users/drew/code/ecto_sql/integration_test/myxql/       (MySQL-specific)
/Users/drew/code/libsql/                                 (C/Rust core)
```

---

## Key Concepts

### Tags for Test Organization
```elixir
@tag :sqlite_only          # SQLite-specific behavior
@tag :replica_mode         # Only run with replica database
@tag :sqlite_limitation    # Documents a SQLite limitation
@tag :requires_json        # Requires JSON1 extension
@tag :slow                 # Long-running test
@tag :benchmark            # Performance measurement
```

### SQLite-Specific Adaptations Needed

| Feature | PG | SQLite | Adaptation |
|---------|----|---------| ---------- |
| Arrays | native | NO | Use JSON |
| Transactions | Multiple modes | DEFERRED/IMMEDIATE/EXCLUSIVE | Test our modes |
| Savepoints | Via RELEASE | SAVEPOINT native | Test natively |
| Foreign Keys | Default | Requires PRAGMA | Add pragma setup |
| ALTER TABLE MODIFY | YES | NO (< 3.35) | Document limitation |
| ALTER TABLE DROP | YES | NO (< 3.35) | Document limitation |
| Prepared Statements | Generic | Auto-reset (v0.7.0) ⭐ | Test our feature |
| Schema Versioning | NO | PRAGMA user_version ⭐ | Test natively |

---

## Success Metrics by Phase

| Phase | Tests | Lines | Suite Total | Completion |
|-------|-------|-------|-------------|-----------|
| Current | 400 | 8,765 | 8,765 | 0% |
| After P1 | 425 | 9,765 | 9,765 | 25% |
| After P2 | 450 | 10,765 | 10,765 | 50% |
| After P3 | 465 | 11,265 | 11,265 | 75% |
| After P4 | 475 | 12,265 | 12,265 | 100% ✅ |

---

## Getting Started (5-Minute Version)

1. **Understand the goal**: Test Suite Consolidation Plan (5 min)
2. **See an example**: TESTS_TO_PORT.md section 1 (5 min)
3. **Pick Phase 1, Test 1**: Fragment handling test
4. **Follow steps**: TEST_EXTRACTION_GUIDE.md Steps 1-5
5. **Run test**: `mix test test/ecto_sql_compatibility_test.exs:1`
6. **Fix any issues**: Common fixes in guide
7. **Commit**: Use format from checklist
8. **Repeat** for next test

**Time to first passing test**: ~30 minutes

---

## Important Notes

### Before You Start
- [ ] Read TEST_IMPORT_SUMMARY.md (5 min)
- [ ] Skim TEST_SUITE_CONSOLIDATION_PLAN.md (10 min)
- [ ] Have TESTS_TO_PORT.md and TEST_EXTRACTION_GUIDE.md ready

### While You Work
- [ ] Check TEST_IMPORT_CHECKLIST.md daily
- [ ] Update progress as you go
- [ ] Reference test/ecto_integration_test.exs for patterns
- [ ] Use commit format from checklist

### Before Each Phase Ends
- [ ] All tests in phase pass
- [ ] No regressions in existing tests
- [ ] Code compiles cleanly
- [ ] Documentation updated

---

## Quick Links

**Need help?**
- Getting started: TEST_IMPORT_SUMMARY.md
- Confused about a test: TESTS_TO_PORT.md
- Stuck on implementation: TEST_EXTRACTION_GUIDE.md
- Tracking progress: TEST_IMPORT_CHECKLIST.md

**Want context?**
- Why we're doing this: TEST_SUITE_CONSOLIDATION_PLAN.md
- What will change: TEST_IMPORT_SUMMARY.md (Benefits section)

**Need code?**
- Test examples: TESTS_TO_PORT.md (all sections)
- Adaptation patterns: TEST_EXTRACTION_GUIDE.md (Patterns section)
- Existing patterns: test/ecto_integration_test.exs

---

## Feedback & Updates

As you work through the phases:
- Document issues found in tests
- Note patterns that appear frequently
- Suggest improvements to guides
- Report problems that aren't in "Common Issues & Fixes"

This will help us improve the process for future test imports.

---

**Last Updated**: December 18, 2025  
**Next Review**: After Phase 1 completion

---

## Document Structure Summary

| Document | Pages | Purpose | When to Read |
|----------|-------|---------|--------------|
| TEST_IMPORT_INDEX.md | 2 | Navigation | Always first |
| TEST_IMPORT_SUMMARY.md | 3 | Overview | Before starting |
| TEST_SUITE_CONSOLIDATION_PLAN.md | 5 | Strategy | For context |
| TESTS_TO_PORT.md | 8 | Code examples | During coding |
| TEST_EXTRACTION_GUIDE.md | 6 | How-to | When implementing |
| TEST_IMPORT_CHECKLIST.md | 5 | Progress | Daily use |

**Total documentation**: 29 pages  
**Total documentation time**: ~1.5 hours to fully understand  
**Time to first test**: ~30 minutes after reading first 2 docs
