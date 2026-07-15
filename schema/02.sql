-- =====================================================================
-- 02. 회원 / 멤버십 도메인
-- 카레 가게 관리 시스템 - Neon Postgres
-- =====================================================================
-- 실행 순서: 00_common_types.sql 다음 (01_org.sql과는 서로 독립적)
-- 포함 테이블: membership_tiers, customers, points_ledger, coupons, customer_coupons
-- =====================================================================

BEGIN;

-- 2-1. 멤버십 등급
CREATE TABLE membership_tiers (
                                  tier_id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                                  name                VARCHAR(30) NOT NULL,
                                  min_spend_amount    NUMERIC(12,2) NOT NULL DEFAULT 0,
                                  point_earn_rate     NUMERIC(4,3)  NOT NULL DEFAULT 0.010, -- 예: 0.010 = 1%
                                  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
                                  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
                                  CONSTRAINT uq_membership_tiers_name UNIQUE (name),
                                  CONSTRAINT ck_membership_tiers_rate CHECK (point_earn_rate >= 0)
);
CREATE TRIGGER trg_membership_tiers_updated_at
    BEFORE UPDATE ON membership_tiers
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

-- 2-2. 고객(회원)
CREATE TABLE customers (
                           customer_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                           public_id       UUID        NOT NULL DEFAULT gen_random_uuid(),
                           tier_id         BIGINT      NOT NULL DEFAULT 1,
                           name            VARCHAR(50) NOT NULL,
                           phone           VARCHAR(30) NOT NULL,
                           email           VARCHAR(255),
                           point_balance   INTEGER     NOT NULL DEFAULT 0,
                           signed_up_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
                           created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
                           updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
                           CONSTRAINT uq_customers_public_id UNIQUE (public_id),
                           CONSTRAINT uq_customers_phone UNIQUE (phone),
                           CONSTRAINT fk_customers_tier FOREIGN KEY (tier_id)
                               REFERENCES membership_tiers (tier_id) ON DELETE RESTRICT,
                           CONSTRAINT ck_customers_point_balance CHECK (point_balance >= 0)
);
CREATE INDEX idx_customers_tier_id ON customers (tier_id);
CREATE TRIGGER trg_customers_updated_at
    BEFORE UPDATE ON customers
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

-- 2-3. 포인트 원장 (적립/차감 이력 - append-only)
CREATE TABLE points_ledger (
                               ledger_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                               customer_id     BIGINT      NOT NULL,
                               order_id        BIGINT,          -- 주문 연계 시 사용 (파티션 테이블 참조는 FK 미설정, 05번 파일 하단 설명 참조)
                               reason          point_reason NOT NULL,
                               point_amount    INTEGER     NOT NULL, -- 양수: 적립, 음수: 차감
                               balance_after   INTEGER     NOT NULL,
                               created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
                               CONSTRAINT fk_points_ledger_customer FOREIGN KEY (customer_id)
                                   REFERENCES customers (customer_id) ON DELETE CASCADE
);
CREATE INDEX idx_points_ledger_customer_id ON points_ledger (customer_id, created_at DESC);

-- 2-4. 쿠폰 마스터
CREATE TABLE coupons (
                         coupon_id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                         code                VARCHAR(30) NOT NULL,
                         name                VARCHAR(100) NOT NULL,
                         discount_amount     NUMERIC(10,2),
                         discount_percent    NUMERIC(5,2),
                         valid_from          TIMESTAMPTZ NOT NULL,
                         valid_until         TIMESTAMPTZ NOT NULL,
                         is_active           BOOLEAN     NOT NULL DEFAULT TRUE,
                         created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
                         updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
                         CONSTRAINT uq_coupons_code UNIQUE (code),
                         CONSTRAINT ck_coupons_period CHECK (valid_until > valid_from),
                         CONSTRAINT ck_coupons_discount_exists CHECK (
                             discount_amount IS NOT NULL OR discount_percent IS NOT NULL
                             )
);
CREATE TRIGGER trg_coupons_updated_at
    BEFORE UPDATE ON coupons
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

-- 2-5. 고객 보유 쿠폰 (발급/사용 상태)
CREATE TABLE customer_coupons (
                                  customer_coupon_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                                  customer_id         BIGINT NOT NULL,
                                  coupon_id           BIGINT NOT NULL,
                                  issued_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
                                  used_at             TIMESTAMPTZ,
                                  order_id            BIGINT,   -- 사용된 주문 (파티션 테이블, FK 미설정)
                                  CONSTRAINT fk_customer_coupons_customer FOREIGN KEY (customer_id)
                                      REFERENCES customers (customer_id) ON DELETE CASCADE,
                                  CONSTRAINT fk_customer_coupons_coupon FOREIGN KEY (coupon_id)
                                      REFERENCES coupons (coupon_id) ON DELETE RESTRICT
);
CREATE INDEX idx_customer_coupons_customer_id ON customer_coupons (customer_id);
CREATE INDEX idx_customer_coupons_coupon_id ON customer_coupons (coupon_id);
-- 미사용 쿠폰만 빠르게 조회하기 위한 부분 인덱스
CREATE INDEX idx_customer_coupons_unused ON customer_coupons (customer_id)
    WHERE used_at IS NULL;

COMMIT;