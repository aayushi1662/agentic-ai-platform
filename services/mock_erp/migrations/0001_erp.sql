-- Owner: Person B. The fake customer ERP the Checker agent queries (through the mock ERP service and MCP).
CREATE TABLE erp.vendors (
  vendor_id  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id  uuid NOT NULL,
  name       text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, vendor_id),
  UNIQUE (tenant_id, name)
);

CREATE TABLE erp.purchase_orders (
  tenant_id     uuid NOT NULL,
  po_number     text NOT NULL,
  vendor_id     uuid NOT NULL,
  currency      char(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
  ordered_total numeric(14,2) NOT NULL CHECK (ordered_total >= 0),
  status        text NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed','cancelled')),
  created_at    timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, po_number),
  FOREIGN KEY (tenant_id, vendor_id) REFERENCES erp.vendors (tenant_id, vendor_id)
);

CREATE TABLE erp.po_line_items (
  po_line_id  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL,
  po_number   text NOT NULL,
  line_no     int  NOT NULL,
  description text NOT NULL,
  quantity    numeric(12,3) NOT NULL,
  unit_price  numeric(14,2) NOT NULL,
  amount      numeric(14,2) NOT NULL,
  UNIQUE (tenant_id, po_number, line_no),
  FOREIGN KEY (tenant_id, po_number) REFERENCES erp.purchase_orders (tenant_id, po_number)
);

DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['vendors','purchase_orders','po_line_items'] LOOP
    EXECUTE format('ALTER TABLE erp.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE erp.%I FORCE ROW LEVEL SECURITY', t);
    EXECUTE format($p$CREATE POLICY tenant_isolation ON erp.%I
        USING (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)
        WITH CHECK (tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::uuid)$p$, t);
  END LOOP;
END $$;

GRANT SELECT, INSERT, UPDATE ON erp.vendors, erp.purchase_orders, erp.po_line_items TO erp_svc;
