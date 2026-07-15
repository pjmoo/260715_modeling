-- =====================================================================
-- 01. 매장 / 조직 도메인
-- 카레 가게 관리 시스템 - Neon Postgres
-- =====================================================================
-- 실행 순서: 00_common_types.sql 다음
-- 포함 테이블: stores, employees, employee_attendances
-- =====================================================================

BEGIN;

-- 1-1. 매장 (멀티 지점)
CREATE TABLE stores (
                        store_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                        public_id       UUID        NOT NULL DEFAULT gen_random_uuid(),
                        name            VARCHAR(100) NOT NULL,
                        address         VARCHAR(255) NOT NULL,
                        phone           VARCHAR(30),
                        is_active       BOOLEAN     NOT NULL DEFAULT TRUE,
                        opened_at       DATE,
                        created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
                        updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
                        CONSTRAINT uq_stores_public_id UNIQUE (public_id)
);
CREATE TRIGGER trg_stores_updated_at
    BEFORE UPDATE ON stores
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

-- 1-2. 직원
CREATE TABLE employees (
                           employee_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                           public_id       UUID        NOT NULL DEFAULT gen_random_uuid(),
                           store_id        BIGINT      NOT NULL,
                           name            VARCHAR(50) NOT NULL,
                           role            employee_role NOT NULL DEFAULT 'STAFF',
                           phone           VARCHAR(30),
                           hired_at        DATE        NOT NULL DEFAULT CURRENT_DATE,
                           resigned_at     DATE,
                           is_active       BOOLEAN     NOT NULL DEFAULT TRUE,
                           created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
                           updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
                           CONSTRAINT uq_employees_public_id UNIQUE (public_id),
                           CONSTRAINT fk_employees_store FOREIGN KEY (store_id)
                               REFERENCES stores (store_id) ON DELETE RESTRICT
);
CREATE INDEX idx_employees_store_id ON employees (store_id);
CREATE TRIGGER trg_employees_updated_at
    BEFORE UPDATE ON employees
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

-- 1-3. 근태 기록
CREATE TABLE employee_attendances (
                                      attendance_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                                      employee_id     BIGINT      NOT NULL,
                                      work_date       DATE        NOT NULL,
                                      check_in_at     TIMESTAMPTZ,
                                      check_out_at    TIMESTAMPTZ,
                                      status          attendance_status NOT NULL DEFAULT 'CHECKED_IN',
                                      created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
                                      updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
                                      CONSTRAINT fk_attendances_employee FOREIGN KEY (employee_id)
                                          REFERENCES employees (employee_id) ON DELETE CASCADE,
                                      CONSTRAINT uq_attendances_employee_date UNIQUE (employee_id, work_date)
);
CREATE INDEX idx_attendances_work_date ON employee_attendances (work_date);
CREATE TRIGGER trg_attendances_updated_at
    BEFORE UPDATE ON employee_attendances
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

COMMIT;