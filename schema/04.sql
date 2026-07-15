-- =====================================================================
-- 04. 재고 도메인
-- 카레 가게 관리 시스템 - Neon Postgres
-- =====================================================================
-- 실행 순서: 01_org.sql, 03_menu.sql 다음 (stores, menu_items를 참조)
-- 포함 테이블: ingredients, menu_item_ingredients, store_ingredient_stocks, stock_movements
-- =====================================================================

BEGIN;

-- 4-1. 원재료 마스터 (예: 카레 루, 양파, 감자, 쌀)
CREATE TABLE ingredients (
                             ingredient_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                             name            VARCHAR(100) NOT NULL,
                             unit            VARCHAR(20)  NOT NULL, -- kg, g, L, ea 등
                             created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
                             updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
                             CONSTRAINT uq_ingredients_name UNIQUE (name)
);
CREATE TRIGGER trg_ingredients_updated_at
    BEFORE UPDATE ON ingredients
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

-- 4-2. 메뉴 - 원재료 소요량 (레시피, BOM) -- menu_items(03) 참조
CREATE TABLE menu_item_ingredients (
                                       menu_item_id    BIGINT NOT NULL,
                                       ingredient_id   BIGINT NOT NULL,
                                       quantity        NUMERIC(10,3) NOT NULL,
                                       PRIMARY KEY (menu_item_id, ingredient_id),
                                       CONSTRAINT fk_mii_menu_item FOREIGN KEY (menu_item_id)
                                           REFERENCES menu_items (menu_item_id) ON DELETE CASCADE,
                                       CONSTRAINT fk_mii_ingredient FOREIGN KEY (ingredient_id)
                                           REFERENCES ingredients (ingredient_id) ON DELETE RESTRICT,
                                       CONSTRAINT ck_mii_quantity CHECK (quantity > 0)
);

-- 4-3. 매장별 재고 현황 (스냅샷 - 현재 수량) -- stores(01) 참조
CREATE TABLE store_ingredient_stocks (
                                         store_id        BIGINT NOT NULL,
                                         ingredient_id   BIGINT NOT NULL,
                                         quantity_on_hand NUMERIC(12,3) NOT NULL DEFAULT 0,
                                         safety_stock    NUMERIC(12,3) NOT NULL DEFAULT 0,
                                         updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
                                         PRIMARY KEY (store_id, ingredient_id),
                                         CONSTRAINT fk_stocks_store FOREIGN KEY (store_id)
                                             REFERENCES stores (store_id) ON DELETE CASCADE,
                                         CONSTRAINT fk_stocks_ingredient FOREIGN KEY (ingredient_id)
                                             REFERENCES ingredients (ingredient_id) ON DELETE RESTRICT,
                                         CONSTRAINT ck_stocks_quantity CHECK (quantity_on_hand >= 0)
);
CREATE TRIGGER trg_stocks_updated_at
    BEFORE UPDATE ON store_ingredient_stocks
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

-- 4-4. 재고 변동 이력 (입고/출고/폐기/조정 - append-only)
CREATE TABLE stock_movements (
                                 movement_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                                 store_id        BIGINT NOT NULL,
                                 ingredient_id   BIGINT NOT NULL,
                                 movement_type   stock_movement_type NOT NULL,
                                 quantity        NUMERIC(12,3) NOT NULL, -- 양수: 증가, 음수: 감소
                                 quantity_after  NUMERIC(12,3) NOT NULL,
                                 order_id        BIGINT,   -- 판매 출고 시 연계 주문 (파티션 테이블, FK 미설정. 05번 파일 참조)
                                 memo            VARCHAR(255),
                                 created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
                                 CONSTRAINT fk_movements_store FOREIGN KEY (store_id)
                                     REFERENCES stores (store_id) ON DELETE CASCADE,
                                 CONSTRAINT fk_movements_ingredient FOREIGN KEY (ingredient_id)
                                     REFERENCES ingredients (ingredient_id) ON DELETE RESTRICT
);
CREATE INDEX idx_stock_movements_store_ingredient ON stock_movements (store_id, ingredient_id, created_at DESC);

COMMIT;