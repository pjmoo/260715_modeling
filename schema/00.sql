-- =====================================================================
-- 00. 공통 함수 / ENUM 타입 정의
-- 카레 가게 관리 시스템 - Neon Postgres
-- =====================================================================
-- 실행 순서: 가장 먼저 실행 (다른 모든 파일이 여기 정의된 트리거 함수/ENUM에 의존)
--
-- 설계 원칙 요약
--   1. PK: BIGINT GENERATED ALWAYS AS IDENTITY 사용
--      -> ORM(JPA/TypeORM/Prisma 등) 전환 시 auto-increment 매핑이 표준적으로 지원됨.
--      -> 외부(API) 노출용 식별자가 필요한 테이블은 UUID(public_id) 컬럼을 별도로 둠.
--   2. 모든 테이블/컬럼명 snake_case (ORM camelCase 자동 매핑과 충돌 없음)
--   3. FK, UNIQUE, CHECK 제약조건에 모두 명시적 이름 부여 (마이그레이션 도구 추적 용이)
--   4. created_at / updated_at 표준 컬럼 (updated_at은 트리거로 자동 갱신)
--   5. 주문(orders) / 결제(payments)는 월별 RANGE 파티셔닝 적용 (05_orders_payments.sql)
--   6. 소프트 삭제는 미적용. 필요 시 deleted_at 컬럼 추가로 확장 가능.
-- =====================================================================

BEGIN;

-- updated_at 자동 갱신 트리거 함수
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 공통 ENUM 타입 정의
-- (ORM에서 enum 매핑 시 문자열 값 그대로 사용 가능하도록 의미있는 값 사용)
CREATE TYPE employee_role AS ENUM ('OWNER', 'MANAGER', 'STAFF', 'PART_TIMER');
CREATE TYPE attendance_status AS ENUM ('CHECKED_IN', 'CHECKED_OUT', 'ON_LEAVE');
CREATE TYPE order_channel AS ENUM ('DINE_IN', 'TAKEOUT', 'DELIVERY');
CREATE TYPE order_status AS ENUM ('PENDING', 'CONFIRMED', 'PREPARING', 'READY', 'COMPLETED', 'CANCELLED');
CREATE TYPE payment_method AS ENUM ('CASH', 'CARD', 'MOBILE_PAY', 'POINT');
CREATE TYPE payment_status AS ENUM ('REQUESTED', 'APPROVED', 'FAILED', 'CANCELLED', 'REFUNDED');
CREATE TYPE point_reason AS ENUM ('EARN_ORDER', 'REDEEM_ORDER', 'ADJUST', 'EXPIRE', 'SIGNUP_BONUS');
CREATE TYPE stock_movement_type AS ENUM ('PURCHASE_IN', 'SALE_OUT', 'WASTE', 'ADJUST', 'TRANSFER_IN', 'TRANSFER_OUT');

COMMIT;