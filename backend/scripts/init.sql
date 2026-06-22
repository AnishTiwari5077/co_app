-- PostgreSQL initialization script — runs once on first container start
-- Per docs/database/table-specifications.md schema setup

CREATE SCHEMA IF NOT EXISTS accounting;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS hr;

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Sequences for human-readable codes (thread-safe, no gaps under concurrent load)
CREATE SEQUENCE IF NOT EXISTS member_code_seq   START 1 INCREMENT 1;
CREATE SEQUENCE IF NOT EXISTS loan_number_seq   START 1 INCREMENT 1;
CREATE SEQUENCE IF NOT EXISTS account_number_seq START 1 INCREMENT 1;
CREATE SEQUENCE IF NOT EXISTS voucher_number_seq START 1 INCREMENT 1;
CREATE SEQUENCE IF NOT EXISTS receipt_number_seq START 1 INCREMENT 1;
