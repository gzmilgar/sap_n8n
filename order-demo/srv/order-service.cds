using {order.demo as db} from '../db/schema';

/**
 * OrderService - the single OData V4 endpoint used by both
 * the Fiori Elements preview and the n8n workflows.
 * Served at http://localhost:4004/odata/v4/order
 */
@path: '/odata/v4/order'
service OrderService {

  // Drafts are intentionally OFF: n8n writes straight to the active table.
  @odata.draft.enabled: false
  entity Orders    as projection on db.Orders {
    *,
    // Derived on read only - drives the colored status column in Fiori.
    case status
      when 'APPROVED' then 3
      when 'REJECTED' then 1
      else                 2
    end as statusCriticality : Integer
  };

  @readonly
  entity Customers as projection on db.Customers;

  @readonly
  entity Products  as projection on db.Products;

  /** Approve an order. Idempotent: re-approving returns the existing record. */
  action approve(ID : UUID, approvedBy : String) returns Orders;

  /** Reject an order. Idempotent: re-rejecting returns the existing record. */
  action reject(ID : UUID, reason : String)      returns Orders;
}
