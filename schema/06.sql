-- =====================================================================
-- 06. 초기 시드 데이터 (DML)
-- 카레 가게 관리 시스템 - Neon Postgres
-- =====================================================================
-- 실행 순서: 01_org.sql, 02_membership.sql, 03_menu.sql 다음
-- =====================================================================

BEGIN;

INSERT INTO membership_tiers (name, min_spend_amount, point_earn_rate) VALUES
                                                                           ('BASIC', 0,      0.010),
                                                                           ('SILVER', 100000, 0.020),
                                                                           ('GOLD',   300000, 0.030);

INSERT INTO categories (name, display_order) VALUES
                                                 ('카레', 1),
                                                 ('사이드', 2),
                                                 ('음료', 3);

INSERT INTO stores (name, address, phone, opened_at) VALUES
    ('카레하우스 본점', '서울시 강남구 테헤란로 1', '02-1234-5678', '2024-03-01');

COMMIT;