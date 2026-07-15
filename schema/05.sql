-- =====================================================================
-- 05. 주문 / 결제 도메인 (월별 RANGE 파티셔닝)
-- 카레 가게 관리 시스템 - Neon Postgres
-- =====================================================================
-- 실행 순서: 01_org.sql, 02_membership.sql, 03_menu.sql 다음
--           (stores, employees, customers, menu_items, menu_item_options 참조)
-- 포함 테이블: orders(파티션), order_items, order_item_options, payments(파티션)
--
-- Postgres 파티셔닝 제약: PK/UNIQUE는 파티션 키를 포함해야 함.
--   -> orders.order_id는 전역 유일성이 필요하므로 BIGINT IDENTITY로 채번하되,
--      PK는 (order_id, ordered_at) 복합키로 구성.
--   -> 파티션 테이블을 FK 대상으로 잡을 수 없어(부모/자식 모두 파티션이면 FK 자체는
--      가능하나 운영 복잡도가 커짐), 실무적으로 points_ledger/customer_coupons/
--      stock_movements 등에서 order_id를 FK 없이 논리적 참조 컬럼으로만 사용.
--      정합성은 애플리케이션/트리거 레벨에서 보장 (ORM 전환 시 애플리케이션 레벨
--      cascade/validation 로직으로 대체 가능).
-- =====================================================================

BEGIN;

-- 5-1. 주문 (부모 테이블)
CREATE TABLE orders (
                        order_id        BIGINT GENERATED ALWAYS AS IDENTITY,
                        public_id       UUID        NOT NULL DEFAULT gen_random_uuid(),
                        store_id        BIGINT      NOT NULL,
                        customer_id     BIGINT,                -- 비회원 주문 허용 (NULL 가능)
                        employee_id     BIGINT      NOT NULL,  -- 주문을 처리한 직원
                        channel         order_channel NOT NULL DEFAULT 'DINE_IN',
                        status          order_status NOT NULL DEFAULT 'PENDING',
                        subtotal_amount NUMERIC(12,2) NOT NULL,
                        discount_amount NUMERIC(12,2) NOT NULL DEFAULT 0,
                        total_amount    NUMERIC(12,2) NOT NULL,
                        ordered_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
                        completed_at    TIMESTAMPTZ,
                        created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
                        updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
                        CONSTRAINT pk_orders PRIMARY KEY (order_id, ordered_at),
                        CONSTRAINT uq_orders_public_id UNIQUE (public_id, ordered_at),
                        CONSTRAINT fk_orders_store FOREIGN KEY (store_id)
                            REFERENCES stores (store_id) ON DELETE RESTRICT,
                        CONSTRAINT fk_orders_customer FOREIGN KEY (customer_id)
                            REFERENCES customers (customer_id) ON DELETE SET NULL,
                        CONSTRAINT fk_orders_employee FOREIGN KEY (employee_id)
                            REFERENCES employees (employee_id) ON DELETE RESTRICT,
                        CONSTRAINT ck_orders_amounts CHECK (
                            subtotal_amount >= 0 AND discount_amount >= 0 AND total_amount >= 0
                            )
) PARTITION BY RANGE (ordered_at);

-- 조회 패턴(매장별/고객별/상태별) 대비 인덱스 - 파티션마다 자동 상속되도록 부모에 정의
CREATE INDEX idx_orders_store_id ON orders (store_id, ordered_at DESC);
CREATE INDEX idx_orders_customer_id ON orders (customer_id, ordered_at DESC);
CREATE INDEX idx_orders_status ON orders (status);

CREATE TRIGGER trg_orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

-- 월별 파티션 생성 (예시: 2026년 1월 ~ 12월 + 기본 파티션)
CREATE TABLE orders_2026_01 PARTITION OF orders FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE orders_2026_02 PARTITION OF orders FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE orders_2026_03 PARTITION OF orders FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
CREATE TABLE orders_2026_04 PARTITION OF orders FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE orders_2026_05 PARTITION OF orders FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE orders_2026_06 PARTITION OF orders FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE orders_2026_07 PARTITION OF orders FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE orders_2026_08 PARTITION OF orders FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE orders_2026_09 PARTITION OF orders FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE orders_2026_10 PARTITION OF orders FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE orders_2026_11 PARTITION OF orders FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE orders_2026_12 PARTITION OF orders FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');
-- 범위를 벗어난 데이터 유입 방지/수용용 기본 파티션 (운영 중 신규 월 파티션 생성 배치 필요)
CREATE TABLE orders_default PARTITION OF orders DEFAULT;

-- 5-2. 주문 항목 (자식 상세)
-- 주문(파티션 부모)을 FK로 참조하려면 (order_id, ordered_at) 복합키가 필요.
-- 주문 항목도 조회 편의상 ordered_at을 함께 들고 감 (비정규화, ORM 매핑 시 주석 참고).
CREATE TABLE order_items (
                             order_item_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                             order_id            BIGINT      NOT NULL,
                             ordered_at          TIMESTAMPTZ NOT NULL, -- orders 파티션 FK 참조용 비정규화 컬럼
                             menu_item_id        BIGINT      NOT NULL,
                             menu_item_name_snap VARCHAR(100) NOT NULL, -- 주문 시점 메뉴명 스냅샷 (메뉴 변경 이력 대비)
                             unit_price_snap     NUMERIC(10,2) NOT NULL, -- 주문 시점 단가 스냅샷
                             quantity            INTEGER     NOT NULL,
                             line_amount         NUMERIC(12,2) NOT NULL,
                             created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
                             CONSTRAINT fk_order_items_order FOREIGN KEY (order_id, ordered_at)
                                 REFERENCES orders (order_id, ordered_at) ON DELETE CASCADE,
                             CONSTRAINT fk_order_items_menu_item FOREIGN KEY (menu_item_id)
                                 REFERENCES menu_items (menu_item_id) ON DELETE RESTRICT,
                             CONSTRAINT ck_order_items_quantity CHECK (quantity > 0),
                             CONSTRAINT ck_order_items_amount CHECK (line_amount >= 0)
);
CREATE INDEX idx_order_items_order ON order_items (order_id, ordered_at);
CREATE INDEX idx_order_items_menu_item_id ON order_items (menu_item_id);

-- 5-3. 주문 항목 - 선택 옵션
CREATE TABLE order_item_options (
                                    order_item_option_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                                    order_item_id         BIGINT NOT NULL,
                                    menu_item_option_id   BIGINT NOT NULL,
                                    option_name_snap       VARCHAR(50) NOT NULL,
                                    extra_price_snap        NUMERIC(10,2) NOT NULL,
                                    CONSTRAINT fk_order_item_options_item FOREIGN KEY (order_item_id)
                                        REFERENCES order_items (order_item_id) ON DELETE CASCADE,
                                    CONSTRAINT fk_order_item_options_option FOREIGN KEY (menu_item_option_id)
                                        REFERENCES menu_item_options (menu_item_option_id) ON DELETE RESTRICT
);
CREATE INDEX idx_order_item_options_item_id ON order_item_options (order_item_id);

-- 5-4. 결제 (부모 테이블, 월별 파티셔닝)
CREATE TABLE payments (
                          payment_id      BIGINT GENERATED ALWAYS AS IDENTITY,
                          public_id       UUID        NOT NULL DEFAULT gen_random_uuid(),
                          order_id        BIGINT      NOT NULL,
                          ordered_at      TIMESTAMPTZ NOT NULL, -- orders 파티션 FK 참조용 비정규화 컬럼
                          method          payment_method NOT NULL,
                          status          payment_status NOT NULL DEFAULT 'REQUESTED',
                          amount          NUMERIC(12,2) NOT NULL,
                          paid_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
                          pg_transaction_id VARCHAR(100), -- 외부 PG사 거래 ID (카드/모바일페이 연동 대비)
                          created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
                          updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
                          CONSTRAINT pk_payments PRIMARY KEY (payment_id, paid_at),
                          CONSTRAINT uq_payments_public_id UNIQUE (public_id, paid_at),
                          CONSTRAINT fk_payments_order FOREIGN KEY (order_id, ordered_at)
                              REFERENCES orders (order_id, ordered_at) ON DELETE RESTRICT,
                          CONSTRAINT ck_payments_amount CHECK (amount >= 0)
) PARTITION BY RANGE (paid_at);

CREATE INDEX idx_payments_order_id ON payments (order_id, ordered_at);
CREATE INDEX idx_payments_status ON payments (status);

CREATE TRIGGER trg_payments_updated_at
    BEFORE UPDATE ON payments
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TABLE payments_2026_01 PARTITION OF payments FOR VALUES FROM ('2026-01-01') TO ('2026-02-01');
CREATE TABLE payments_2026_02 PARTITION OF payments FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');
CREATE TABLE payments_2026_03 PARTITION OF payments FOR VALUES FROM ('2026-03-01') TO ('2026-04-01');
CREATE TABLE payments_2026_04 PARTITION OF payments FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE payments_2026_05 PARTITION OF payments FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE payments_2026_06 PARTITION OF payments FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE payments_2026_07 PARTITION OF payments FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE payments_2026_08 PARTITION OF payments FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE payments_2026_09 PARTITION OF payments FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
CREATE TABLE payments_2026_10 PARTITION OF payments FOR VALUES FROM ('2026-10-01') TO ('2026-11-01');
CREATE TABLE payments_2026_11 PARTITION OF payments FOR VALUES FROM ('2026-11-01') TO ('2026-12-01');
CREATE TABLE payments_2026_12 PARTITION OF payments FOR VALUES FROM ('2026-12-01') TO ('2027-01-01');
CREATE TABLE payments_default PARTITION OF payments DEFAULT;

COMMIT;

-- =====================================================================
-- [운영 참고] 파티션 관리
--   신규 월 파티션은 매월 배치(pg_cron 등)로 사전 생성 권장. 예:
--     CREATE TABLE orders_2027_01 PARTITION OF orders
--       FOR VALUES FROM ('2027-01-01') TO ('2027-02-01');
--   과거 파티션은 필요 시 detach 후 별도 아카이브 테이블/스토리지로 이관 가능.
-- =====================================================================