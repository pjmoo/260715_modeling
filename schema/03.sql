-- =====================================================================
-- 03. 메뉴 / 상품 도메인
-- 카레 가게 관리 시스템 - Neon Postgres
-- =====================================================================
-- 실행 순서: 00_common_types.sql 다음 (01, 02와 서로 독립적)
-- 포함 테이블: categories, menu_items, option_groups, menu_item_options
-- =====================================================================

BEGIN;

-- 3-1. 메뉴 카테고리 (예: 카레, 사이드, 음료)
CREATE TABLE categories (
                            category_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                            name            VARCHAR(50) NOT NULL,
                            display_order   INTEGER     NOT NULL DEFAULT 0,
                            created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
                            updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
                            CONSTRAINT uq_categories_name UNIQUE (name)
);
CREATE TRIGGER trg_categories_updated_at
    BEFORE UPDATE ON categories
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

-- 3-2. 메뉴 아이템
CREATE TABLE menu_items (
                            menu_item_id    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                            public_id       UUID        NOT NULL DEFAULT gen_random_uuid(),
                            category_id     BIGINT      NOT NULL,
                            name            VARCHAR(100) NOT NULL,
                            description     TEXT,
                            base_price      NUMERIC(10,2) NOT NULL,
                            is_available    BOOLEAN     NOT NULL DEFAULT TRUE,
                            created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
                            updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
                            CONSTRAINT uq_menu_items_public_id UNIQUE (public_id),
                            CONSTRAINT fk_menu_items_category FOREIGN KEY (category_id)
                                REFERENCES categories (category_id) ON DELETE RESTRICT,
                            CONSTRAINT ck_menu_items_price CHECK (base_price >= 0)
);
CREATE INDEX idx_menu_items_category_id ON menu_items (category_id);
CREATE INDEX idx_menu_items_available ON menu_items (is_available) WHERE is_available = TRUE;
CREATE TRIGGER trg_menu_items_updated_at
    BEFORE UPDATE ON menu_items
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

-- 3-3. 옵션 그룹 (예: 맵기 선택, 밥 추가)
CREATE TABLE option_groups (
                               option_group_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                               menu_item_id    BIGINT      NOT NULL,
                               name            VARCHAR(50) NOT NULL,
                               is_required     BOOLEAN     NOT NULL DEFAULT FALSE,
                               max_select      INTEGER     NOT NULL DEFAULT 1,
                               created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
                               updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
                               CONSTRAINT fk_option_groups_menu_item FOREIGN KEY (menu_item_id)
                                   REFERENCES menu_items (menu_item_id) ON DELETE CASCADE,
                               CONSTRAINT ck_option_groups_max_select CHECK (max_select >= 1)
);
CREATE INDEX idx_option_groups_menu_item_id ON option_groups (menu_item_id);
CREATE TRIGGER trg_option_groups_updated_at
    BEFORE UPDATE ON option_groups
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

-- 3-4. 메뉴 옵션 (옵션 그룹의 개별 선택지, 예: 매운맛, 곱빼기)
CREATE TABLE menu_item_options (
                                   menu_item_option_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
                                   option_group_id     BIGINT NOT NULL,
                                   name                VARCHAR(50) NOT NULL,
                                   extra_price         NUMERIC(10,2) NOT NULL DEFAULT 0,
                                   created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
                                   updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
                                   CONSTRAINT fk_menu_item_options_group FOREIGN KEY (option_group_id)
                                       REFERENCES option_groups (option_group_id) ON DELETE CASCADE,
                                   CONSTRAINT ck_menu_item_options_price CHECK (extra_price >= 0)
);
CREATE INDEX idx_menu_item_options_group_id ON menu_item_options (option_group_id);
CREATE TRIGGER trg_menu_item_options_updated_at
    BEFORE UPDATE ON menu_item_options
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

COMMIT;